-- The delivery code and the handover: picked up, then delivered with the
-- recipient's code, which queues the traveler's payout.
--
-- Run AFTER 20240138_mobile_money_local_currency.sql. Safe to re-run.
--
--   1. When a payment is confirmed (nata.complete_payment), a 4-digit code is
--      made for the request (nata.delivery_codes). Only the sender can read it
--      (public.my_delivery_code); they share it with the recipient, by SMS
--      from the app (send-delivery-code edge function) or themselves.
--   2. The traveler marks the item picked up: public.mark_picked_up
--      (paid -> handed_off).
--   3. At handover the recipient tells the traveler the code, and the traveler
--      enters it: public.confirm_delivery. 5 wrong codes lock it (support can
--      unlock). The right code marks the request delivered and queues the
--      payout (nata.payouts, pending) from the money held in escrow.

-- -----------------------------------------------------------------------------
-- 1. Codes
-- -----------------------------------------------------------------------------
create table if not exists nata.delivery_codes (
  request_id   uuid primary key references nata.delivery_requests (id) on delete cascade,
  code         text not null check (code ~ '^[0-9]{4}$'),
  created_at   timestamptz not null default now(),
  -- When it was last sent to the recipient by SMS.
  sms_sent_at  timestamptz
);

alter table nata.delivery_codes enable row level security;
-- No policies: read through public.my_delivery_code, written by functions.
revoke all on nata.delivery_codes from anon, authenticated;

alter table nata.delivery_requests
  add column if not exists picked_up_at timestamptz;

alter table nata.payouts
  -- Where the traveler asked to be paid (their saved payout account).
  add column if not exists payout_account_id uuid references nata.payout_accounts (id);

-- Makes the request's code if it has none.
create or replace function nata.issue_delivery_code(p_request_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into nata.delivery_codes (request_id, code)
  values (p_request_id, lpad((floor(random() * 10000))::int::text, 4, '0'))
  on conflict (request_id) do nothing;
$$;

revoke all on function nata.issue_delivery_code(uuid) from public;
revoke all on function nata.issue_delivery_code(uuid) from anon, authenticated;

-- Requests already paid before this file was run get their code too.
select nata.issue_delivery_code(r.id)
  from nata.delivery_requests r
 where r.status in ('paid', 'handed_off');

-- -----------------------------------------------------------------------------
-- 2. A confirmed payment makes the code
--    Same as in 20240137_flutterwave_payments.sql, plus the code.
-- -----------------------------------------------------------------------------
create or replace function nata.complete_payment(
  p_tx_ref          text,
  p_transaction_id  text,
  p_amount          numeric,
  p_currency        text,
  p_payment_type    text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay  record;
  req  record;
begin
  select * into pay from nata.payments where tx_ref = p_tx_ref for update;
  if not found then
    return 'not_found';
  end if;
  if pay.status <> 'pending' and pay.status <> 'failed' then
    return 'already_paid';
  end if;

  if upper(coalesce(p_currency, '')) <> pay.currency
     or coalesce(p_amount, 0) < pay.amount then
    update nata.payments
       set status = 'failed',
           provider_payment_id = p_transaction_id,
           provider_payment_type = p_payment_type,
           completed_at = now(),
           updated_at = now()
     where id = pay.id;
    return 'mismatch';
  end if;

  select id, status, expires_at into req
    from nata.delivery_requests
   where id = pay.request_id
   for update;

  if req.status = 'accepted'
     or (req.status = 'expired' and req.expires_at is not null
         and pay.created_at <= req.expires_at) then
    update nata.payments
       set status = 'held',
           provider_payment_id = p_transaction_id,
           provider_payment_type = p_payment_type,
           completed_at = now(),
           updated_at = now()
     where id = pay.id;
    perform set_config('nata.completing_payment', 'on', true);
    update nata.delivery_requests
       set status = 'paid', paid_at = now()
     where id = req.id;
    perform set_config('nata.completing_payment', 'off', true);
    perform nata.issue_delivery_code(req.id);
    return 'paid';
  end if;

  update nata.payments
     set status = 'held',
         needs_refund = true,
         provider_payment_id = p_transaction_id,
         provider_payment_type = p_payment_type,
         completed_at = now(),
         updated_at = now()
   where id = pay.id;
  return 'needs_refund';
end;
$$;

revoke all on function nata.complete_payment(text, text, numeric, text, text) from public;
revoke all on function nata.complete_payment(text, text, numeric, text, text) from anon, authenticated;
grant execute on function nata.complete_payment(text, text, numeric, text, text) to service_role;

-- -----------------------------------------------------------------------------
-- 3. The sender reads the code
-- -----------------------------------------------------------------------------
drop function if exists public.my_delivery_code(uuid);

create or replace function public.my_delivery_code(p_request_id uuid)
returns table (code text, sms_sent_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select c.code, c.sms_sent_at
    from nata.delivery_codes c
    join nata.delivery_requests r on r.id = c.request_id
   where c.request_id = p_request_id
     and r.sender_id = auth.uid()
     and r.status in ('paid', 'handed_off');
$$;

revoke all on function public.my_delivery_code(uuid) from public;
grant execute on function public.my_delivery_code(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Picked up
-- -----------------------------------------------------------------------------
drop function if exists public.mark_picked_up(uuid);

create or replace function public.mark_picked_up(p_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.picked_up_at, t.traveler_id into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id
   for update of r;

  if not found or req.traveler_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status = 'handed_off' then
    return req.picked_up_at;
  end if;
  if req.status <> 'paid' then
    raise exception 'nata:request_not_paid';
  end if;

  update nata.delivery_requests
     set status = 'handed_off', picked_up_at = now()
   where id = p_id;
  return now();
end;
$$;

revoke all on function public.mark_picked_up(uuid) from public;
grant execute on function public.mark_picked_up(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Delivered, with the recipient's code
-- -----------------------------------------------------------------------------
-- Returns the result rather than raising on a wrong code, so the attempt is
-- counted: 'delivered', 'wrong_code' (with attempts_left), 'locked', or
-- 'no_code' (paid before codes existed; one has just been made).
drop function if exists public.confirm_delivery(uuid, text, uuid);

create or replace function public.confirm_delivery(
  p_id                 uuid,
  p_code               text,
  p_payout_account_id  uuid default null
)
returns table (result text, attempts_left integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid       uuid := auth.uid();
  max_tries constant integer := 5;
  req       record;
  expected  text;
  pay       record;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.delivery_code_attempts, t.traveler_id into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id
   for update of r;

  if not found or req.traveler_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status = 'delivered' then
    return query select 'delivered'::text, 0;
    return;
  end if;
  if req.status not in ('paid', 'handed_off') then
    raise exception 'nata:request_not_paid';
  end if;
  if req.delivery_code_attempts >= max_tries then
    return query select 'locked'::text, 0;
    return;
  end if;

  select c.code into expected from nata.delivery_codes c where c.request_id = p_id;
  if expected is null then
    -- Paid before codes existed: make one now for the sender to share, and
    -- ask the traveler to get it from the recipient.
    perform nata.issue_delivery_code(p_id);
    return query select 'no_code'::text, max_tries - req.delivery_code_attempts;
    return;
  end if;

  if btrim(coalesce(p_code, '')) <> expected then
    update nata.delivery_requests
       set delivery_code_attempts = delivery_code_attempts + 1
     where id = p_id;
    return query select
      case when req.delivery_code_attempts + 1 >= max_tries
           then 'locked' else 'wrong_code' end,
      greatest(0, max_tries - req.delivery_code_attempts - 1);
    return;
  end if;

  update nata.delivery_requests
     set status = 'delivered',
         delivered_at = now(),
         picked_up_at = coalesce(picked_up_at, now())
   where id = p_id;

  update nata.profiles
     set items_delivered_count = coalesce(items_delivered_count, 0) + 1
   where id = uid;

  -- The traveler's share of the money held in escrow (the price without
  -- Nata's fee), in the currency it was paid in.
  select p.id, p.amount, p.service_fee, p.currency into pay
    from nata.payments p
   where p.request_id = p_id and p.status = 'held' and not p.needs_refund
   limit 1;
  if found then
    insert into nata.payouts (payment_id, traveler_id, payout_account_id, amount, currency, status)
    values (pay.id, uid,
            (select a.id from nata.payout_accounts a
              where a.id = p_payout_account_id and a.user_id = uid),
            greatest(0, pay.amount - coalesce(pay.service_fee, 0)),
            pay.currency, 'pending')
    on conflict (payment_id) do nothing;
  end if;

  return query select 'delivered'::text, 0;
end;
$$;

revoke all on function public.confirm_delivery(uuid, text, uuid) from public;
grant execute on function public.confirm_delivery(uuid, text, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. The traveler's requests, with when the item was picked up
--    Same as in 20240134_incoming_requests.sql plus picked_up_at.
-- -----------------------------------------------------------------------------
drop function if exists public.list_incoming_requests();

create or replace function public.list_incoming_requests()
returns table (
  request_id          uuid,
  status              text,
  created_at          timestamptz,
  expires_at          timestamptz,
  responded_at        timestamptz,
  payout_usd          numeric,
  items               jsonb,
  item_weight_kg      numeric,
  item_size           text,
  item_size_class     text,
  photo_paths         text[],
  sender_id           uuid,
  sender_first_name   text,
  sender_last_name    text,
  sender_avatar_path  text,
  sender_verified     boolean,
  sender_deliveries   integer,
  recipient_name      text,
  recipient_phone     text,
  trip_id             uuid,
  departure_city      text,
  departure_country   text,
  arrival_city        text,
  arrival_country     text,
  departure_date      date,
  arrival_date        date,
  picked_up_at        timestamptz,
  delivered_at        timestamptz,
  code_attempts_left  integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.status,
    r.created_at,
    r.expires_at,
    r.responded_at,
    r.traveler_price,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'name', i.name, 'category', i.category,
                'description', i.description) order by i.position)
         from nata.request_items i where i.request_id = r.id),
      '[]'::jsonb),
    r.item_weight_kg,
    r.item_size,
    r.item_size_class,
    coalesce(
      (select array_agg(ph.photo_path order by ph.photo_path)
         from nata.request_photos ph
        where ph.request_id = r.id and ph.type = 'item'),
      '{}'::text[]),
    r.sender_id,
    sp.first_name,
    sp.last_name,
    sp.avatar_path,
    coalesce(sp.verification_status = 'verified', false),
    (select count(*)::integer from nata.delivery_requests d
      where d.sender_id = r.sender_id and d.status = 'delivered'),
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then rr.name end,
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then rr.phone end,
    t.id,
    dc.name,
    dc.country_code::text,
    ac.name,
    ac.country_code::text,
    t.departure_date,
    t.arrival_date,
    r.picked_up_at,
    r.delivered_at,
    greatest(0, 5 - coalesce(r.delivery_code_attempts, 0))
  from nata.delivery_requests r
  join nata.trips t     on t.id  = r.trip_id
  join nata.profiles sp on sp.id = r.sender_id
  join nata.cities dc   on dc.id = t.departure_city_id
  join nata.cities ac   on ac.id = t.arrival_city_id
  left join nata.request_recipients rr on rr.request_id = r.id
  where auth.uid() is not null
    and t.traveler_id = auth.uid()
    and (
      r.status in ('pending', 'accepted', 'paid', 'handed_off')
      or (r.status = 'delivered'
          and coalesce(r.delivered_at, r.updated_at) > now() - interval '30 days')
    )
  order by r.created_at desc;
$$;

revoke all on function public.list_incoming_requests() from public;
grant execute on function public.list_incoming_requests() to authenticated;

-- -----------------------------------------------------------------------------
-- 7. Recording that the code was texted (send-delivery-code edge function)
-- -----------------------------------------------------------------------------
drop function if exists nata.mark_code_sent(uuid);

create or replace function nata.mark_code_sent(p_request_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.delivery_codes set sms_sent_at = now() where request_id = p_request_id;
$$;

revoke all on function nata.mark_code_sent(uuid) from public;
revoke all on function nata.mark_code_sent(uuid) from anon, authenticated;
grant execute on function nata.mark_code_sent(uuid) to service_role;
