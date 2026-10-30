-- Refundable deposits for items above the traveler's carrying limit.
--
-- Run AFTER 20240194_item_values_carry_limit.sql. Safe to re-run.
--
-- A traveler whose request's declared value is above their carrying limit
-- (nata.carry_limit, 20240194) pays a deposit of the full declared value
-- before pickup. It is a payment like the sender's, in nata.payments with
-- purpose 'deposit' and the traveler as its payer (sender_id), so Stripe,
-- pawaPay, verify-payment, the webhooks and refunds handle it unchanged:
--
--   * create-payment takes { purpose: 'deposit' } from the traveler; the
--     amount is the declared value (card) or the same in the wallet's
--     currency (nata.deposit_charge, mobile money).
--   * nata.complete_payment holds it without touching the request (a deposit
--     paid after the request closed is refunded straight away).
--   * public.mark_picked_up refuses pickup while one is due and not held.
--   * It is refunded in full when the recipient's code confirms delivery
--     (public.confirm_delivery) or when the request is cancelled or expires.
--   * Support can pay it to the sender instead (an item kept):
--     public.support_pay_deposit_to_sender puts it in the sender's Nata
--     balance (a payout of kind 'deposit').
--
-- Everything that reads "the request's payment" (payouts at delivery,
-- refunds to the sender, the support and staff figures) now looks at
-- purpose 'delivery' only.

-- -----------------------------------------------------------------------------
-- 1. Payments and payouts
-- -----------------------------------------------------------------------------
alter table nata.payments
  add column if not exists purpose text not null default 'delivery';
alter table nata.payments drop constraint if exists payments_purpose_check;
alter table nata.payments
  add constraint payments_purpose_check check (purpose in ('delivery', 'deposit'));

drop index if exists nata.payments_one_held_per_request;
create unique index payments_one_held_per_request on nata.payments (request_id)
  where status in ('held', 'released') and not needs_refund and purpose = 'delivery';
create unique index if not exists payments_one_deposit_per_request on nata.payments (request_id)
  where status in ('held', 'released') and not needs_refund and purpose = 'deposit';

alter table nata.payouts drop constraint if exists payouts_kind_check;
alter table nata.payouts
  add constraint payouts_kind_check check (kind in ('earning', 'refund', 'deposit'));

-- -----------------------------------------------------------------------------
-- 2. What a request's deposit is
-- -----------------------------------------------------------------------------
-- Due when the declared value, in dollars today, is above the traveler's
-- limit. A value whose rate is unknown counts as above it.
create or replace function nata.deposit_due(p_request_id uuid)
returns table (required boolean, amount numeric, currency text,
               declared_usd numeric, limit_usd numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  req  record;
  usd  numeric;
  lim  numeric;
begin
  select r.declared_value, upper(btrim(r.declared_currency::text)) as cur,
         t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id;
  if not found or req.declared_value is null or req.declared_value <= 0 then
    return query select false, null::numeric, null::text, null::numeric, null::numeric;
    return;
  end if;
  usd := case when coalesce(req.cur, 'USD') = 'USD' then req.declared_value
              else nata.to_usd(req.declared_value, req.cur, now()) end;
  select c.limit_usd into lim from nata.carry_limit(req.traveler_id) c;
  return query select usd is null or usd > coalesce(lim, 100),
                      req.declared_value, coalesce(req.cur, 'USD'), usd, lim;
end;
$$;

revoke all on function nata.deposit_due(uuid) from public, anon, authenticated;
grant execute on function nata.deposit_due(uuid) to service_role;

-- The deposit in [p_country]'s mobile money currency (whole units), or in
-- the declared currency for a card when [p_country] is null.
create or replace function nata.deposit_charge(p_request_id uuid, p_country text)
returns table (currency text, amount numeric, base_amount numeric, base_currency text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  due       record;
  local_cur text;
  from_rate numeric;
  to_rate   numeric;
begin
  select * into due from nata.deposit_due(p_request_id);
  if due.amount is null then
    raise exception 'nata:deposit_not_due';
  end if;
  if p_country is null or btrim(p_country) = '' then
    return query select due.currency, due.amount, due.amount, due.currency;
    return;
  end if;

  if not exists (select 1 from nata.mobile_money_networks n
                  where n.country_code = upper(btrim(p_country))) then
    raise exception 'nata:mobile_money_unavailable';
  end if;
  select upper(btrim(c.currency_code::text)) into local_cur
    from nata.countries c where c.iso_code = upper(btrim(p_country));
  if local_cur is null or local_cur = '' then
    raise exception 'nata:mobile_money_unavailable';
  end if;
  if local_cur = due.currency then
    return query select local_cur, ceil(due.amount), due.amount, due.currency;
    return;
  end if;

  from_rate := nata.recent_rate(due.currency);
  to_rate := nata.recent_rate(local_cur);
  if from_rate is null or to_rate is null then
    raise exception 'nata:rate_unavailable';
  end if;
  return query select local_cur, ceil(due.amount / from_rate * to_rate),
                      due.amount, due.currency;
end;
$$;

revoke all on function nata.deposit_charge(uuid, text) from public, anon, authenticated;
grant execute on function nata.deposit_charge(uuid, text) to service_role;

-- Where a request's deposit stands, for its traveler and its sender:
-- required, the amount, and status none / pending / held / refunding /
-- refunded / paid_to_sender, with what was paid.
create or replace function public.request_deposit(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
  due  record;
  pay  nata.payments%rowtype;
  st   text := 'none';
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  select r.id, r.sender_id, t.traveler_id into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id;
  if not found or uid not in (req.sender_id, req.traveler_id) then
    raise exception 'nata:request_not_found';
  end if;

  select * into due from nata.deposit_due(p_request_id);
  select p.* into pay from nata.payments p
   where p.request_id = p_request_id and p.purpose = 'deposit'
     and p.status <> 'failed'
   order by p.created_at desc limit 1;
  if found then
    st := case
      when pay.status = 'released' then 'paid_to_sender'
      when pay.status = 'refunded' then 'refunded'
      when pay.refund_status is not null or pay.needs_refund then 'refunding'
      when pay.status = 'held' then 'held'
      else 'pending' end;
  end if;

  return jsonb_build_object(
    'required', coalesce(due.required, false),
    'amount', due.amount,
    'currency', due.currency,
    'limit_usd', due.limit_usd,
    'status', st,
    'paid_amount', pay.amount,
    'paid_currency', pay.currency,
    'method', pay.method,
    -- How it is paid: the request's rule (20240173), mobile money or card.
    'kind', nata.checkout_kind(p_request_id),
    'tx_ref', case when uid = req.traveler_id then pay.tx_ref end);
end;
$$;

revoke all on function public.request_deposit(uuid) from public, anon;
grant execute on function public.request_deposit(uuid) to authenticated;

-- The countries whose mobile money can pay a request's deposit, as
-- public.mobile_money_options does for the sender's payment.
create or replace function public.deposit_mobile_money_options(p_request_id uuid)
returns table (country_code text, country_name text, currency text, amount numeric,
               suggested boolean, dial_code text, networks jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid   uuid := auth.uid();
  home  text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (select 1 from nata.delivery_requests r
                   join nata.trips t on t.id = r.trip_id
                  where r.id = p_request_id and t.traveler_id = uid
                    and r.status in ('accepted', 'paid')) then
    raise exception 'nata:request_not_payable';
  end if;
  select upper(btrim(p.country_of_residence::text)) into home
    from nata.profiles p where p.id = uid;

  return query
    with eligible as materialized (
      select c.iso_code::text as iso, c.name, c.phone_code
        from nata.countries c
       where exists (select 1 from nata.mobile_money_networks n
                      where n.country_code = c.iso_code::text)
         and nata.recent_rate(btrim(c.currency_code::text)) is not null
    )
    select e.iso,
           e.name,
           m.currency,
           m.amount,
           e.iso = coalesce(home, ''),
           '+' || regexp_replace(coalesce(e.phone_code, ''), '[^0-9]', '', 'g'),
           (select jsonb_agg(jsonb_build_object('code', n.provider, 'name', n.name)
                             order by n.position)
              from nata.mobile_money_networks n
             where n.country_code = e.iso)
      from eligible e
      cross join lateral nata.deposit_charge(p_request_id, e.iso) m
     order by e.name;
end;
$$;

revoke all on function public.deposit_mobile_money_options(uuid) from public, anon;
grant execute on function public.deposit_mobile_money_options(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Paying it
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION nata.complete_payment(p_tx_ref text, p_transaction_id text, p_amount numeric, p_currency text, p_payment_type text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  -- A traveler's deposit (20240195): held, the request itself unchanged.
  -- One paid after the request closed, or a second one, goes back.
  if pay.purpose = 'deposit' then
    select r.id, r.status, r.sender_id into req
      from nata.delivery_requests r
     where r.id = pay.request_id
     for update;
    if req.status in ('accepted', 'paid')
       and not exists (select 1 from nata.payments o
                        where o.request_id = pay.request_id and o.id <> pay.id
                          and o.purpose = 'deposit' and not o.needs_refund
                          and o.status in ('held', 'released')) then
      update nata.payments
         set status = 'held',
             provider_payment_id = p_transaction_id,
             provider_payment_type = p_payment_type,
             completed_at = now(),
             updated_at = now()
       where id = pay.id;
      perform nata.notify(pay.sender_id, 'payment', 'deposit_held',
        'Deposit received',
        'Your deposit is held by Nata. You can pick up the items now; it is refunded once delivery is confirmed.',
        pay.request_id,
        jsonb_build_object('amount', pay.amount, 'currency', pay.currency,
                           'request_id', pay.request_id));
      perform nata.notify(req.sender_id, 'payment', 'deposit_paid',
        'Your traveler paid a deposit',
        'The traveler paid a refundable deposit for your items before pickup.',
        pay.request_id,
        jsonb_build_object('request_id', pay.request_id));
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
    perform nata.queue_refund(pay.id, false);
    return 'needs_refund';
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
$function$;

-- -----------------------------------------------------------------------------
-- 4. Pickup waits for it
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_picked_up(p_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  -- Items above the traveler's carrying limit: the deposit first (20240195).
  if (select d.required from nata.deposit_due(p_id) d)
     and not exists (select 1 from nata.payments p
                      where p.request_id = p_id and p.purpose = 'deposit'
                        and p.status = 'held' and not p.needs_refund
                        and p.refund_status is null) then
    raise exception 'nata:deposit_required';
  end if;

  update nata.delivery_requests
     set status = 'handed_off', picked_up_at = now()
   where id = p_id;
  return now();
end;
$function$;

-- -----------------------------------------------------------------------------
-- 5. Refunded at delivery, cancellation or expiry
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_delivery(p_id uuid, p_code text, p_payout_account_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(result text, attempts_left integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
     and p.purpose = 'delivery'
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

  -- The traveler's deposit goes back in full (20240195).
  for pay in
    select p.id from nata.payments p
     where p.request_id = p_id and p.purpose = 'deposit' and p.status = 'held'
  loop
    perform nata.queue_refund(pay.id, false);
  end loop;

  return query select 'delivered'::text, 0;
end;
$function$;

create or replace function nata.refund_on_cancel()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay uuid;
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    for pay in
      select p.id from nata.payments p
       where p.request_id = new.id and p.status = 'held' and p.purpose = 'delivery'
    loop
      perform nata.queue_refund(pay, old.status in ('accepted', 'paid'));
    end loop;
  end if;
  -- A traveler's deposit goes back in full whenever the request closes
  -- without a delivery.
  if new.status in ('cancelled', 'expired', 'declined')
     and old.status is distinct from new.status then
    for pay in
      select p.id from nata.payments p
       where p.request_id = new.id and p.status = 'held' and p.purpose = 'deposit'
    loop
      perform nata.queue_refund(pay, false);
    end loop;
  end if;
  return new;
end;
$$;


-- -----------------------------------------------------------------------------
-- 6. Support
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.support_refund_sender(p_dispute uuid, p_note text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  d    record;
  pay  record;
begin
  perform nata.require_admin();
  select dd.request_id, dd.status into d
    from nata.disputes dd where dd.id = p_dispute for update;
  if not found or d.status not in ('open', 'under_review') then
    raise exception 'nata:not_open';
  end if;

  select p.id, p.sender_id into pay
    from nata.payments p
   where p.request_id = d.request_id and p.status = 'held'
     and p.refund_status is null and p.purpose = 'delivery'
   order by p.created_at desc limit 1
   for update;
  if not found then
    raise exception 'nata:not_refundable';
  end if;
  if exists (select 1 from nata.payouts po
              where po.payment_id = pay.id and po.status in ('processing', 'paid')) then
    raise exception 'nata:already_paid_out';
  end if;

  -- The traveler isn't paid for this delivery.
  delete from nata.payouts po where po.payment_id = pay.id and po.status in ('pending', 'failed');
  perform nata.queue_refund(pay.id, false);

  update nata.disputes
     set status = 'resolved',
         resolution = nullif(btrim(coalesce(p_note, '')), ''),
         refund_amount = (select p.refund_amount from nata.payments p where p.id = pay.id),
         resolved_at = now(),
         updated_at = now()
   where id = p_dispute;
  perform nata.log_support('refunded', 'Sender refunded · ' ||
    coalesce(nata.short_name(pay.sender_id), ''), d.request_id);
end;
$function$;
drop function if exists public.support_problems(boolean);
create function public.support_problems(p_open boolean DEFAULT true)
 RETURNS TABLE(dispute_id uuid, request_id uuid, reason text, details text, status text, resolution text, reported_by text, reporter_id uuid, reporter_name text, reporter_avatar text, sender_id uuid, sender_name text, sender_phone text, traveler_id uuid, traveler_name text, traveler_phone text, route text, item_name text, amount numeric, currency text, payment_status text, payout_status text, paid_at timestamp with time zone, picked_up_at timestamp with time zone, delivered_at timestamp with time zone, created_at timestamp with time zone, resolved_at timestamp with time zone, deposit_amount numeric, deposit_currency text, deposit_status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform nata.require_admin();
  return query
    select d.id, r.id, d.reason, d.details, d.status, d.resolution,
           case when d.opened_by = r.sender_id then 'sender' else 'traveler' end,
           d.opened_by, nata.short_name(d.opened_by), rp.avatar_path,
           r.sender_id, nata.short_name(r.sender_id), su.phone::text,
           t.traveler_id, nata.short_name(t.traveler_id), tu.phone::text,
           dc.name || ' → ' || ac.name,
           r.item_name,
           pay.amount, pay.currency::text, pay.status, po.status,
           r.paid_at, r.picked_up_at, r.delivered_at,
           d.created_at, d.resolved_at,
           dep.amount, dep.currency::text,
           case when dep.id is null then null
                when dep.status = 'released' then 'paid_to_sender'
                when dep.status = 'refunded' then 'refunded'
                when dep.refund_status is not null or dep.needs_refund then 'refunding'
                else 'held' end
      from nata.disputes d
      join nata.delivery_requests r on r.id = d.request_id
      join nata.trips t on t.id = r.trip_id
      join nata.cities dc on dc.id = t.departure_city_id
      join nata.cities ac on ac.id = t.arrival_city_id
      left join nata.profiles rp on rp.id = d.opened_by
      left join auth.users su on su.id = r.sender_id
      left join auth.users tu on tu.id = t.traveler_id
      left join lateral (
        select p.* from nata.payments p
         where p.request_id = r.id and p.status in ('held', 'released', 'refunded')
           and p.purpose = 'delivery'
         order by p.created_at desc limit 1) pay on true
      left join lateral (
        select p.* from nata.payments p
         where p.request_id = r.id and p.status in ('held', 'released', 'refunded')
           and p.purpose = 'deposit'
         order by p.created_at desc limit 1) dep on true
      left join nata.payouts po on po.payment_id = pay.id
     where (p_open and d.status in ('open', 'under_review'))
        or (not p_open and d.status in ('resolved', 'rejected'))
     order by d.created_at desc;
end;
$function$;
revoke all on function public.support_problems(boolean) from public, anon;
grant execute on function public.support_problems(boolean) to authenticated;


-- An item kept: the deposit goes to the sender's Nata balance instead of
-- back to the traveler.
create or replace function public.support_pay_deposit_to_sender(p_dispute uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d    record;
  pay  record;
begin
  perform nata.require_admin();
  select dd.request_id, dd.status, r.sender_id into d
    from nata.disputes dd
    join nata.delivery_requests r on r.id = dd.request_id
   where dd.id = p_dispute
   for update of dd;
  if not found or d.status not in ('open', 'under_review') then
    raise exception 'nata:not_open';
  end if;

  select p.id, p.sender_id as payer, p.amount, p.currency into pay
    from nata.payments p
   where p.request_id = d.request_id and p.purpose = 'deposit'
     and p.status = 'held' and p.refund_status is null and not p.needs_refund
   for update;
  if not found then
    raise exception 'nata:no_deposit';
  end if;

  insert into nata.payouts (payment_id, traveler_id, amount, currency, status, kind)
  values (pay.id, d.sender_id, pay.amount, pay.currency, 'pending', 'deposit');
  update nata.payments
     set status = 'released', updated_at = now()
   where id = pay.id;

  perform nata.notify(d.sender_id, 'payment', 'deposit_to_sender',
    'Deposit added to your Nata balance',
    'The traveler''s deposit for your items is in your Nata balance.',
    d.request_id,
    jsonb_build_object('amount', pay.amount, 'currency', pay.currency,
                       'request_id', d.request_id));
  perform nata.notify(pay.payer, 'payment', 'deposit_kept',
    'Your deposit was paid to the sender',
    'The items were not delivered, so your deposit was paid to the sender.',
    d.request_id,
    jsonb_build_object('amount', pay.amount, 'currency', pay.currency,
                       'request_id', d.request_id));
  perform nata.log_support('deposit_paid', 'Deposit paid to sender · ' ||
    coalesce(nata.short_name(d.sender_id), '') ||
    coalesce(' · ' || nullif(btrim(coalesce(p_note, '')), ''), ''), d.request_id);
end;
$$;

revoke all on function public.support_pay_deposit_to_sender(uuid, text) from public, anon;
grant execute on function public.support_pay_deposit_to_sender(uuid, text) to authenticated;


-- -----------------------------------------------------------------------------
-- 7. Figures and history
-- -----------------------------------------------------------------------------
-- Deposits are not sales.
CREATE OR REPLACE FUNCTION public.dashboard_stats(p_year integer DEFAULT NULL::integer, p_month integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_from         timestamptz;
  v_to           timestamptz;
  v_unit         text;
  v_series_from  timestamptz;
  v_series_to    timestamptz;
  v_step         interval;
  result         jsonb;
begin
  perform nata.require_admin();

  if p_month is not null and (p_year is null or p_month not between 1 and 12) then
    raise exception 'nata:bad_period';
  end if;
  if p_year is not null and p_year not between 2000 and 2100 then
    raise exception 'nata:bad_period';
  end if;

  if p_year is not null then
    v_from := make_timestamptz(p_year, coalesce(p_month, 1), 1, 0, 0, 0, 'UTC');
    v_to   := v_from + case when p_month is null then interval '1 year' else interval '1 month' end;
  end if;

  if p_month is not null then
    v_unit := 'day';   v_series_from := v_from; v_series_to := v_to - interval '1 day';
  elsif p_year is not null then
    v_unit := 'month'; v_series_from := v_from; v_series_to := v_to - interval '1 month';
  else
    v_unit := 'month';
    v_series_from := date_trunc('month', now(), 'UTC') - interval '23 months';
    v_series_to   := date_trunc('month', now(), 'UTC');
  end if;
  v_step := case v_unit when 'day' then interval '1 day' else interval '1 month' end;

  with all_members as (
    select p.verification_status, p.country_of_residence, p.created_at
      from nata.profiles p
     where p.deleted_at is null
  ),
  members as (
    select * from all_members m
     where (v_from is null or m.created_at >= v_from) and (v_to is null or m.created_at < v_to)
  ),
  -- GMV: payments that went through, at the day they completed.
  all_tx as (
    select coalesce(pay.completed_at, pay.created_at) as at,
           case when pay.base_amount is not null
                then nata.to_usd(pay.base_amount, pay.base_currency, coalesce(pay.completed_at, pay.created_at))
                else nata.to_usd(pay.amount, pay.currency, coalesce(pay.completed_at, pay.created_at)) end as amount_usd
      from nata.payments pay
     where pay.status in ('held', 'released', 'refunded') and not pay.needs_refund
       and pay.purpose = 'delivery'
  ),
  tx as (
    select * from all_tx t where (v_from is null or t.at >= v_from) and (v_to is null or t.at < v_to)
  ),
  -- Revenue: platform fee when delivered, cancellation fee kept when cancelled.
  all_rev as (
    select coalesce(r.delivered_at, r.updated_at) as at,
           nata.to_usd(r.platform_fee, r.currency, coalesce(r.delivered_at, r.updated_at)) as usd,
           sp.country_of_residence as sender_country
      from nata.delivery_requests r
      left join nata.profiles sp on sp.id = r.sender_id
     where r.status = 'delivered' and coalesce(r.platform_fee, 0) > 0
    union all
    select coalesce(r.cancelled_at, r.updated_at),
           nata.to_usd(r.cancellation_fee, r.currency, coalesce(r.cancelled_at, r.updated_at)),
           sp.country_of_residence
      from nata.delivery_requests r
      left join nata.profiles sp on sp.id = r.sender_id
     where r.status = 'cancelled' and coalesce(r.cancellation_fee, 0) > 0
  ),
  rev as (
    select * from all_rev v where (v_from is null or v.at >= v_from) and (v_to is null or v.at < v_to)
  ),
  period_trips as (
    select t.status from nata.trips t
     where (v_from is null or t.created_at >= v_from) and (v_to is null or t.created_at < v_to)
  )
  select jsonb_build_object(
    'generated_at', now(),
    'period', jsonb_build_object('year', p_year, 'month', p_month),
    'years_available', (
      select coalesce(jsonb_agg(y order by y desc), '[]'::jsonb)
        from generate_series(
               least(coalesce((select extract(year from min(created_at))::int from all_members), extract(year from now())::int),
                     coalesce((select extract(year from min(at))::int from all_tx), extract(year from now())::int)),
               extract(year from now())::int) as y
    ),
    'users_all_time', (select count(*) from all_members),
    'users', (
      select jsonb_build_object(
        'total',          count(*),
        'verified',       count(*) filter (where verification_status = 'verified'),
        'pending',        count(*) filter (where verification_status = 'pending'),
        'not_verified',   count(*) filter (where verification_status is distinct from 'verified'
                                             and verification_status is distinct from 'pending'),
        'new_this_month', (select count(*) from all_members a where a.created_at >= date_trunc('month', now(), 'UTC'))
      )
      from members
    ),
    'users_by_country', coalesce((
      select jsonb_agg(c order by c.total desc, c.country)
        from (select coalesce(m.country_of_residence, '??') as country, count(*) as total,
                     count(*) filter (where m.verification_status = 'verified') as verified
                from members m group by 1) c
    ), '[]'::jsonb),
    'trips', (
      select jsonb_build_object(
        'total', count(*),
        'live', count(*) filter (where status = 'live'),
        'completed', count(*) filter (where status = 'completed'),
        'cancelled', count(*) filter (where status = 'cancelled'))
      from period_trips
    ),
    'transactions', jsonb_build_object(
      'total',       (select count(*) from tx),
      'volume_usd',  (select round(coalesce(sum(amount_usd), 0), 2) from tx),
      'revenue_usd', (select round(coalesce(sum(usd), 0), 2) from rev)
    ),
    'revenue_by_country', coalesce((
      select jsonb_agg(c order by c.revenue_usd desc, c.country)
        from (select coalesce(sender_country, '??') as country, count(*) as count,
                     round(coalesce(sum(usd), 0), 2) as revenue_usd
                from rev group by 1) c
    ), '[]'::jsonb),
    'transactions_by_year', coalesce((
      select jsonb_agg(y order by y.year)
        from (select yr as year,
                     coalesce((select count(*) from all_tx t where extract(year from t.at)::int = yr), 0) as count,
                     coalesce((select round(sum(amount_usd), 2) from all_tx t where extract(year from t.at)::int = yr), 0) as volume_usd,
                     coalesce((select round(sum(usd), 2) from all_rev v where extract(year from v.at)::int = yr), 0) as revenue_usd
                from (select distinct extract(year from at)::int as yr from all_tx
                      union select distinct extract(year from at)::int from all_rev) ys) y
    ), '[]'::jsonb),
    'transactions_series', jsonb_build_object(
      'unit', v_unit,
      'points', (
        select jsonb_agg(
                 jsonb_build_object(
                   'date',        to_char(s.bucket, case v_unit when 'day' then 'YYYY-MM-DD' else 'YYYY-MM' end),
                   'count',       coalesce((select count(*) from all_tx t
                                             where t.at >= s.bucket and t.at < s.bucket + v_step), 0),
                   'volume_usd',  coalesce((select round(sum(amount_usd), 2) from all_tx t
                                             where t.at >= s.bucket and t.at < s.bucket + v_step), 0),
                   'revenue_usd', coalesce((select round(sum(usd), 2) from all_rev v
                                             where v.at >= s.bucket and v.at < s.bucket + v_step), 0)
                 ) order by s.bucket)
          from generate_series(v_series_from, v_series_to, v_step) as s(bucket)
      )
    )
  )
  into result;

  return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.staff_metrics(p_year integer DEFAULT NULL::integer, p_month integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_from timestamptz;
  v_to   timestamptz;
  v_week timestamptz := date_trunc('week', now(), 'UTC');
  result jsonb;
begin
  perform nata.require_admin();

  if p_month is not null and (p_year is null or p_month not between 1 and 12) then
    raise exception 'nata:bad_period';
  end if;
  if p_year is not null then
    if p_year not between 2000 and 2100 then raise exception 'nata:bad_period'; end if;
    v_from := make_timestamptz(p_year, coalesce(p_month, 1), 1, 0, 0, 0, 'UTC');
    v_to   := v_from + case when p_month is null then interval '1 year' else interval '1 month' end;
  end if;

  with
  ev as (
    select e.request_id, e.status, min(e.created_at) as at
      from nata.request_events e group by 1, 2
  ),
  -- One row per request with the time it reached each step.
  req as (
    select r.id, r.status, r.sender_id, r.trip_id, r.created_at,
           coalesce(r.price_fixed_at, a.at,
                    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered') then r.responded_at end) as accepted_at,
           coalesce(r.paid_at, p.at) as paid_at,
           coalesce(r.picked_up_at, h.at) as picked_up_at,
           coalesce(r.delivered_at, d.at) as delivered_at,
           coalesce(r.cancelled_at, c.at) as cancelled_at,
           coalesce(x.at, r.expires_at) as expired_at,
           r.platform_fee, r.cancellation_fee, r.currency, r.delivery_code_attempts
      from nata.delivery_requests r
      left join ev a on a.request_id = r.id and a.status = 'accepted'
      left join ev p on p.request_id = r.id and p.status = 'paid'
      left join ev h on h.request_id = r.id and h.status = 'handed_off'
      left join ev d on d.request_id = r.id and d.status = 'delivered'
      left join ev c on c.request_id = r.id and c.status = 'cancelled'
      left join ev x on x.request_id = r.id and x.status = 'expired'
  ),
  req_p as (
    select * from req q where (v_from is null or q.created_at >= v_from) and (v_to is null or q.created_at < v_to)
  ),
  route as (
    select q.id as request_id, t.departure_city_id as from_id, t.arrival_city_id as to_id
      from req_p q join nata.trips t on t.id = q.trip_id
  ),
  live_trips as (
    select t.departure_city_id as from_id, t.arrival_city_id as to_id, count(*) as n
      from nata.trips t
     where t.status = 'live' and t.departure_date >= current_date
     group by 1, 2
  ),
  pay as (
    select pay.*, coalesce(pay.completed_at, pay.created_at) as at,
           pay.status in ('held', 'released', 'refunded') as ok
      from nata.payments pay
     where pay.purpose = 'delivery'
  ),
  pay_p as (
    select * from pay where (v_from is null or pay.created_at >= v_from) and (v_to is null or pay.created_at < v_to)
  ),
  owed as (
    select po.*, coalesce(po.payout_currency, po.currency) as cur,
           coalesce(po.payout_amount, po.amount) as cur_amount
      from nata.payouts po
     where po.status not in ('paid', 'cancelled')
  ),
  escrow as (
    select pay.* from pay
      join nata.delivery_requests r on r.id = pay.request_id
     where pay.status = 'held' and not pay.needs_refund and r.status in ('paid', 'handed_off')
  ),
  members as (
    select pr.id, pr.created_at, pr.verification_status from nata.profiles pr where pr.deleted_at is null
  ),
  delivered_by_sender as (
    select q.sender_id as who, q.delivered_at as at from req q where q.delivered_at is not null
  ),
  delivered_by_traveler as (
    select t.traveler_id as who, q.delivered_at as at
      from req q join nata.trips t on t.id = q.trip_id where q.delivered_at is not null
  )
  select jsonb_build_object(
    'generated_at', now(),
    'period', jsonb_build_object('year', p_year, 'month', p_month),

    -- 1. Business health ------------------------------------------------------
    'health', jsonb_build_object(
      'deliveries_by_week', (
        select jsonb_agg(jsonb_build_object(
                 'date', to_char(w, 'YYYY-MM-DD'),
                 'count', (select count(*) from req q where q.delivered_at >= w and q.delivered_at < w + interval '1 week'))
               order by w)
          from generate_series(v_week - interval '11 weeks', v_week, interval '1 week') as w
      ),
      'escrow_usd', (select round(coalesce(sum(
                       case when e.base_amount is not null then nata.to_usd(e.base_amount, e.base_currency, e.at)
                            else nata.to_usd(e.amount, e.currency, e.at) end), 0), 2) from escrow e),
      'escrow_count', (select count(*) from escrow),
      'owed_usd', (select round(coalesce(sum(nata.to_usd(o.amount, o.currency, o.created_at)), 0), 2) from owed o),
      'owed_count', (select count(*) from owed)
    ),

    -- 2. Funnel ----------------------------------------------------------------
    'funnel', (
      select jsonb_build_object(
        'requested',  count(*),
        'accepted',   count(*) filter (where accepted_at is not null),
        'paid',       count(*) filter (where paid_at is not null),
        'picked_up',  count(*) filter (where picked_up_at is not null),
        'delivered',  count(*) filter (where delivered_at is not null),
        'declined',   count(*) filter (where status = 'declined'),
        'expired_unanswered', count(*) filter (where status = 'expired' and accepted_at is null),
        'expired_unpaid',     count(*) filter (where status = 'expired' and accepted_at is not null and paid_at is null),
        'cancelled_before_payment', count(*) filter (where status = 'cancelled' and paid_at is null),
        'cancelled_after_payment',  count(*) filter (where status = 'cancelled' and paid_at is not null),
        'open', count(*) filter (where status in ('pending', 'accepted', 'paid', 'handed_off')),
        'median_hours', jsonb_build_object(
          'to_accept', round((percentile_cont(0.5) within group (order by extract(epoch from accepted_at - created_at) / 3600)
                              filter (where accepted_at is not null))::numeric, 1),
          'to_pay',    round((percentile_cont(0.5) within group (order by extract(epoch from paid_at - accepted_at) / 3600)
                              filter (where paid_at is not null and accepted_at is not null))::numeric, 1),
          'to_pickup', round((percentile_cont(0.5) within group (order by extract(epoch from picked_up_at - paid_at) / 3600)
                              filter (where picked_up_at is not null and paid_at is not null))::numeric, 1),
          'to_deliver', round((percentile_cont(0.5) within group (order by extract(epoch from delivered_at - picked_up_at) / 3600)
                              filter (where delivered_at is not null and picked_up_at is not null))::numeric, 1)
        )
      )
      from req_p
    ),

    -- 3. Supply and demand by route -------------------------------------------
    'routes', jsonb_build_object(
      'by_requests', coalesce((
        select jsonb_agg(x order by x.requests desc, x.from_city) from (
          select fc.name as from_city, fc.country_code as from_country, tc.name as to_city, tc.country_code as to_country,
                 count(*) as requests,
                 count(*) filter (where q.delivered_at is not null) as delivered,
                 coalesce(max(lt.n), 0) as live_trips
            from route rt
            join req_p q on q.id = rt.request_id
            join nata.cities fc on fc.id = rt.from_id
            join nata.cities tc on tc.id = rt.to_id
            left join live_trips lt on lt.from_id = rt.from_id and lt.to_id = rt.to_id
           group by rt.from_id, rt.to_id, fc.name, fc.country_code, tc.name, tc.country_code
           order by count(*) desc limit 10) x
      ), '[]'::jsonb),
      'by_trips', coalesce((
        select jsonb_agg(x order by x.trips desc, x.from_city) from (
          select fc.name as from_city, fc.country_code as from_country, tc.name as to_city, tc.country_code as to_country,
                 count(*) as trips,
                 (select count(*) from nata.delivery_requests r2 join nata.trips t2 on t2.id = r2.trip_id
                   where t2.departure_city_id = t.departure_city_id and t2.arrival_city_id = t.arrival_city_id
                     and (v_from is null or r2.created_at >= v_from) and (v_to is null or r2.created_at < v_to)) as requests
            from nata.trips t
            join nata.cities fc on fc.id = t.departure_city_id
            join nata.cities tc on tc.id = t.arrival_city_id
           where (v_from is null or t.created_at >= v_from) and (v_to is null or t.created_at < v_to)
           group by t.departure_city_id, t.arrival_city_id, fc.name, fc.country_code, tc.name, tc.country_code
           order by count(*) desc limit 10) x
      ), '[]'::jsonb),
      'alerts_total', (select count(*) from nata.route_alerts),
      'alerts_unmatched', (select count(*) from nata.route_alerts a
                            where not exists (select 1 from live_trips lt
                                               where lt.from_id = a.from_city_id and lt.to_id = a.to_city_id)),
      'active_travelers_30d', (select count(distinct t.traveler_id) from nata.trips t where t.created_at >= now() - interval '30 days'),
      'active_senders_30d', (select count(distinct r.sender_id) from nata.delivery_requests r where r.created_at >= now() - interval '30 days')
    ),

    -- 4. Payments and payouts ---------------------------------------------------
    'payments', jsonb_build_object(
      'by_method', coalesce((
        select jsonb_agg(x order by x.attempts desc) from (
          select method, provider, count(*) as attempts,
                 count(*) filter (where ok) as succeeded,
                 count(*) filter (where status = 'failed') as failed,
                 count(*) filter (where status = 'pending') as pending
            from pay_p group by method, provider) x
      ), '[]'::jsonb),
      'mobile_money', coalesce((
        select jsonb_agg(x order by x.attempts desc) from (
          select coalesce(country_code, '??') as country, coalesce(provider_payment_type, '?') as network, provider,
                 count(*) as attempts,
                 count(*) filter (where ok) as succeeded,
                 count(*) filter (where status = 'failed') as failed
            from pay_p where method = 'mobile_money' group by 1, 2, 3) x
      ), '[]'::jsonb),
      'payouts_open', coalesce((
        select jsonb_agg(x order by x.count desc) from (
          select o.status, count(*) as count,
                 round(coalesce(sum(nata.to_usd(o.amount, o.currency, o.created_at)), 0), 2) as amount_usd,
                 round(extract(epoch from now() - min(o.created_at)) / 3600)::int as oldest_hours,
                 count(*) filter (where o.created_at < now() - interval '24 hours') as older_than_day
            from owed o group by o.status) x
      ), '[]'::jsonb),
      'payout_failures', coalesce((
        select jsonb_agg(x order by x.count desc) from (
          select coalesce(o.failure_reason, '?') as reason, count(*) as count
            from owed o where o.failure_reason is not null group by 1) x
      ), '[]'::jsonb),
      'refunds', (
        select jsonb_build_object(
          'count',  count(*) filter (where refund_status = 'refunded' or status = 'refunded'),
          'amount_usd', round(coalesce(sum(nata.to_usd(coalesce(refund_amount, amount), currency, coalesce(refunded_at, updated_at)))
                                          filter (where refund_status = 'refunded' or status = 'refunded'), 0), 2),
          'failed', count(*) filter (where refund_status = 'failed'),
          'waiting', count(*) filter (where (needs_refund or refund_status in ('pending', 'sending')) and coalesce(refund_status, '') <> 'refunded'))
          from pay p2
         where (v_from is null or coalesce(p2.refunded_at, p2.updated_at) >= v_from)
           and (v_to is null or coalesce(p2.refunded_at, p2.updated_at) < v_to)
      ),
      'owed_by_currency', coalesce((
        select jsonb_agg(x order by x.currency) from (
          select cur as currency, round(sum(cur_amount), 2) as payouts_owed, count(*) as payouts
            from owed group by cur) x
      ), '[]'::jsonb),
      'escrow_by_currency', coalesce((
        select jsonb_agg(x order by x.currency) from (
          select e.currency, round(sum(e.amount), 2) as held, count(*) as payments
            from escrow e group by e.currency) x
      ), '[]'::jsonb)
    ),

    -- 5. Trust and safety --------------------------------------------------------
    'trust', jsonb_build_object(
      'deliveries', (select count(*) from req q where q.delivered_at is not null
                       and (v_from is null or q.delivered_at >= v_from) and (v_to is null or q.delivered_at < v_to)),
      'reports', (select count(*) from nata.disputes d
                   where (v_from is null or d.created_at >= v_from) and (v_to is null or d.created_at < v_to)),
      'reports_open', (select count(*) from nata.disputes d where d.resolved_at is null),
      'reports_oldest_open_hours', (select round(extract(epoch from now() - min(d.created_at)) / 3600)::int
                                      from nata.disputes d where d.resolved_at is null),
      'traveler_rating', (select round(avg(rv.rating)::numeric, 2) from nata.reviews rv
                           where rv.reviewee_role = 'traveler'
                             and (v_from is null or rv.created_at >= v_from) and (v_to is null or rv.created_at < v_to)),
      'traveler_reviews', (select count(*) from nata.reviews rv where rv.reviewee_role = 'traveler'
                             and (v_from is null or rv.created_at >= v_from) and (v_to is null or rv.created_at < v_to)),
      'delivered_reviewed', (select count(*) from req q
                              where q.delivered_at is not null
                                and (v_from is null or q.delivered_at >= v_from) and (v_to is null or q.delivered_at < v_to)
                                and exists (select 1 from nata.reviews rv where rv.request_id = q.id and rv.reviewee_role = 'traveler')),
      'identity', (
        select jsonb_build_object(
          'passed',   count(*) filter (where iv.status = 'verified'),
          'rejected', count(*) filter (where iv.status = 'rejected'),
          'waiting',  count(*) filter (where iv.status = 'pending'),
          'oldest_waiting_hours', round(extract(epoch from now() - min(iv.created_at) filter (where iv.status = 'pending')) / 3600)::int,
          'median_hours_to_decide', round((percentile_cont(0.5) within group (
              order by extract(epoch from coalesce(iv.verified_at, iv.reviewed_at) - iv.created_at) / 3600)
              filter (where coalesce(iv.verified_at, iv.reviewed_at) is not null))::numeric, 1))
          from nata.identity_verifications iv
      ),
      'locked_deliveries', (select count(*) from req q where coalesce(q.delivery_code_attempts, 0) >= 5 and q.delivered_at is null)
    ),

    -- 6. Growth and retention ----------------------------------------------------
    'growth', jsonb_build_object(
      'signups_by_week', (
        select jsonb_agg(jsonb_build_object(
                 'date', to_char(w, 'YYYY-MM-DD'),
                 'count', (select count(*) from members m where m.created_at >= w and m.created_at < w + interval '1 week'),
                 'verified', (select count(*) from members m where m.created_at >= w and m.created_at < w + interval '1 week'
                                and m.verification_status = 'verified'),
                 'posted_trip', (select count(*) from members m where m.created_at >= w and m.created_at < w + interval '1 week'
                                and exists (select 1 from nata.trips t where t.traveler_id = m.id)),
                 'sent_request', (select count(*) from members m where m.created_at >= w and m.created_at < w + interval '1 week'
                                and exists (select 1 from nata.delivery_requests r where r.sender_id = m.id)))
               order by w)
          from generate_series(v_week - interval '11 weeks', v_week, interval '1 week') as w
      ),
      'signups', (select count(*) from members m where (v_from is null or m.created_at >= v_from) and (v_to is null or m.created_at < v_to)),
      'signups_verified', (select count(*) from members m where m.verification_status = 'verified'
                             and (v_from is null or m.created_at >= v_from) and (v_to is null or m.created_at < v_to)),
      'signups_posted_trip', (select count(*) from members m
                                where (v_from is null or m.created_at >= v_from) and (v_to is null or m.created_at < v_to)
                                  and exists (select 1 from nata.trips t where t.traveler_id = m.id)),
      'signups_sent_request', (select count(*) from members m
                                 where (v_from is null or m.created_at >= v_from) and (v_to is null or m.created_at < v_to)
                                   and exists (select 1 from nata.delivery_requests r where r.sender_id = m.id)),
      'repeat_senders', (
        select jsonb_build_object(
          'with_delivery', count(*),
          'repeat_60d', count(*) filter (where second_at is not null and second_at <= first_at + interval '60 days'),
          'eligible', count(*) filter (where first_at <= now() - interval '60 days'))
          from (select who, min(at) as first_at,
                       (array_agg(at order by at))[2] as second_at
                  from delivered_by_sender group by who) s
      ),
      'repeat_travelers', (
        select jsonb_build_object(
          'with_delivery', count(*),
          'repeat_60d', count(*) filter (where second_at is not null and second_at <= first_at + interval '60 days'),
          'eligible', count(*) filter (where first_at <= now() - interval '60 days'))
          from (select who, min(at) as first_at,
                       (array_agg(at order by at))[2] as second_at
                  from delivered_by_traveler group by who) s
      )
    )
  )
  into result;

  return result;
end;
$function$;

-- A deposit paid, and one received by a sender, read as such.
CREATE OR REPLACE FUNCTION public.wallet_history(p_limit integer DEFAULT 100)
 RETURNS TABLE(kind text, id uuid, amount numeric, currency text, status text, created_at timestamp with time zone, item text, from_city text, to_city text, other_name text, method text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select * from (
    select
      -- A refund kept in the balance (20240187) reads as such.
      case po.kind when 'refund' then 'refund'
                   when 'deposit' then 'deposit_received'
                   else 'payout' end,
      po.id,
      po.amount,
      coalesce(po.currency, pa.currency)::text,
      po.status,
      po.created_at,
      r.item_description,
      dc.name,
      ac.name,
      sp.first_name,
      null::text
    from nata.payouts po
    left join nata.payments pa         on pa.id = po.payment_id
    left join nata.delivery_requests r on r.id = pa.request_id
    left join nata.trips t             on t.id = r.trip_id
    left join nata.cities dc           on dc.id = t.departure_city_id
    left join nata.cities ac           on ac.id = t.arrival_city_id
    left join nata.profiles sp         on sp.id = r.sender_id
    where po.traveler_id = auth.uid()

    union all

    select
      -- A traveler's deposit (20240195) reads as such.
      case when pa.purpose = 'deposit' then 'deposit' else 'payment' end,
      pa.id,
      pa.amount,
      pa.currency::text,
      pa.status,
      coalesce(pa.completed_at, pa.created_at),
      r.item_description,
      dc.name,
      ac.name,
      tp.first_name,
      pa.method
    from nata.payments pa
    join nata.delivery_requests r on r.id = pa.request_id
    join nata.trips t             on t.id = r.trip_id
    left join nata.cities dc      on dc.id = t.departure_city_id
    left join nata.cities ac      on ac.id = t.arrival_city_id
    left join nata.profiles tp    on tp.id = t.traveler_id
    where pa.sender_id = auth.uid()
      and pa.status in ('held', 'released', 'refunded')
  ) h
  order by h.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$function$;
