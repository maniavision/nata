-- Delivery check-ins: both sides are asked whether the item was delivered.
--
-- Run AFTER 20240200_flat_fees_multi_send.sql. Safe to re-run.
--
-- On a flat fee request (20240200) the sender pays the traveler directly,
-- so Nata asks both of them how it went instead of waiting for a code:
--
--   * nata.run_delivery_checkins(), every day at 17:00 UTC, from the trip's
--     arrival day to two days after: a paid or picked-up flat request (or one
--     already delivered) asks
--       - its sender "Was your item delivered?" (delivery_check_sender)
--         until they confirm it (receipt_confirmed_at);
--       - its traveler "Did you deliver the item?" (delivery_check_traveler)
--         until they confirm it (traveler_delivered_at).
--     Once a day each at most (nata.delivery_checkins). Saying yes opens the
--     review and then the suggestions for Nata.
--   * public.traveler_confirm_delivered(): the traveler says they delivered.
--     The request closes as delivered, as when the sender confirms (their
--     delivered count, a deposit refunded), and the sender is told
--     (delivered_by_traveler) and still asked to confirm.
--   * public.confirm_delivered(): the sender's yes on a request the traveler
--     already closed now records it (receipt_confirmed_at).
--   * public.list_incoming_requests(): also returns traveler_delivered_at.
--   * No more wallet in the app: the sender pays the traveler directly, so
--     there is nothing to keep in a Nata balance. Refunds go back to how
--     they were paid, and payouts (of the earlier requests) go out as they
--     come, for everyone.

-- -----------------------------------------------------------------------------
-- 1. Who said it was delivered, and the questions sent
-- -----------------------------------------------------------------------------
alter table nata.delivery_requests
  add column if not exists traveler_delivered_at timestamptz;

create table if not exists nata.delivery_checkins (
  request_id uuid not null references nata.delivery_requests (id) on delete cascade,
  user_id    uuid not null,
  day        date not null,
  sent_at    timestamptz not null default now(),
  primary key (request_id, user_id, day)
);
alter table nata.delivery_checkins enable row level security;
revoke all on nata.delivery_checkins from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Closing a flat request as delivered
-- -----------------------------------------------------------------------------
create or replace function nata.close_flat_delivered(
  p_id         uuid,
  p_traveler   uuid,
  p_by_sender  boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay record;
begin
  update nata.delivery_requests
     set status = 'delivered',
         delivered_at = now(),
         picked_up_at = coalesce(picked_up_at, now()),
         receipt_confirmed_at = case when p_by_sender then now() end,
         traveler_delivered_at = case when p_by_sender then null else now() end
   where id = p_id;

  update nata.profiles
     set items_delivered_count = coalesce(items_delivered_count, 0) + 1
   where id = p_traveler;

  -- The traveler's deposit goes back in full (20240195).
  for pay in
    select p.id from nata.payments p
     where p.request_id = p_id and p.purpose = 'deposit' and p.status = 'held'
  loop
    perform nata.queue_refund(pay.id, false);
  end loop;
end;
$$;
revoke all on function nata.close_flat_delivered(uuid, uuid, boolean)
  from public, anon, authenticated;

create or replace function public.confirm_delivered(p_id uuid)
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

  select r.id, r.status, r.pricing, r.delivered_at, r.receipt_confirmed_at,
         t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id and r.sender_id = uid
   for update of r;

  if not found or req.pricing <> 'flat' then
    raise exception 'nata:request_not_found';
  end if;
  if req.status = 'delivered' then
    -- The traveler closed it first: the sender's yes is recorded.
    if req.receipt_confirmed_at is null then
      update nata.delivery_requests set receipt_confirmed_at = now()
       where id = p_id;
    end if;
    return req.delivered_at;
  end if;
  if req.status not in ('paid', 'handed_off') then
    raise exception 'nata:request_not_paid';
  end if;

  perform nata.close_flat_delivered(p_id, req.traveler_id, true);
  return now();
end;
$$;
revoke all on function public.confirm_delivered(uuid) from public;
grant execute on function public.confirm_delivered(uuid) to authenticated;

create or replace function public.traveler_confirm_delivered(p_id uuid)
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

  select r.id, r.status, r.pricing, r.delivered_at, r.traveler_delivered_at
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id and t.traveler_id = uid
   for update of r;

  if not found or req.pricing <> 'flat' then
    raise exception 'nata:request_not_found';
  end if;
  if req.status = 'delivered' then
    -- The sender confirmed first: the traveler's yes is recorded.
    if req.traveler_delivered_at is null then
      update nata.delivery_requests set traveler_delivered_at = now()
       where id = p_id;
    end if;
    return req.delivered_at;
  end if;
  if req.status not in ('paid', 'handed_off') then
    raise exception 'nata:request_not_paid';
  end if;

  perform nata.close_flat_delivered(p_id, uid, false);
  return now();
end;
$$;
revoke all on function public.traveler_confirm_delivered(uuid) from public;
grant execute on function public.traveler_confirm_delivered(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. The daily questions
-- -----------------------------------------------------------------------------
create or replace function nata.run_delivery_checkins()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r     record;
  info  jsonb;
  n     integer := 0;
begin
  for r in
    select dr.id, dr.sender_id, t.traveler_id,
           dr.receipt_confirmed_at, dr.traveler_delivered_at,
           sp.first_name as sender, tp.first_name as traveler,
           coalesce(dc.name, '') || ' → ' || coalesce(ac.name, '') as route
      from nata.delivery_requests dr
      join nata.trips t on t.id = dr.trip_id
      left join nata.profiles sp on sp.id = dr.sender_id
      left join nata.profiles tp on tp.id = t.traveler_id
      left join nata.cities dc on dc.id = t.departure_city_id
      left join nata.cities ac on ac.id = t.arrival_city_id
     where dr.pricing = 'flat'
       and dr.status in ('paid', 'handed_off', 'delivered')
       and current_date between t.arrival_date and t.arrival_date + 2
       and (dr.receipt_confirmed_at is null or dr.traveler_delivered_at is null)
  loop
    info := jsonb_build_object(
      'sender', coalesce(r.sender, ''),
      'traveler', coalesce(r.traveler, ''),
      'route', r.route,
      'request_id', r.id);

    if r.receipt_confirmed_at is null then
      insert into nata.delivery_checkins (request_id, user_id, day)
      values (r.id, r.sender_id, current_date)
      on conflict do nothing;
      if found then
        perform nata.notify(r.sender_id, 'request', 'delivery_check_sender',
          'Was your item delivered?',
          'Let us know if ' || coalesce(r.traveler, 'the traveler')
            || ' delivered your item, then leave a review.',
          r.id, info);
        n := n + 1;
      end if;
    end if;

    -- A traveler who already rated the sender has said how it went.
    if r.traveler_delivered_at is null
       and not exists (select 1 from nata.reviews v
                        where v.request_id = r.id and v.reviewer_id = r.traveler_id) then
      insert into nata.delivery_checkins (request_id, user_id, day)
      values (r.id, r.traveler_id, current_date)
      on conflict do nothing;
      if found then
        perform nata.notify(r.traveler_id, 'request', 'delivery_check_traveler',
          'Did you deliver the item?',
          'Let us know if you delivered ' || coalesce(r.sender, 'the sender')
            || '''s item, then leave a review.',
          r.id, info);
        n := n + 1;
      end if;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function nata.run_delivery_checkins()
  from public, anon, authenticated;

select cron.unschedule('delivery-checkins')
 where exists (select 1 from cron.job where jobname = 'delivery-checkins');
select cron.schedule(
  'delivery-checkins', '0 17 * * *',
  $job$ select nata.run_delivery_checkins(); $job$
);

-- -----------------------------------------------------------------------------
-- 4. The sender is told when the traveler closes it
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION nata.notify_request_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  traveler   uuid;
  sender     text;
  trav_name  text;
  trav_shown text;
  route      text;
  info       jsonb;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  select t.traveler_id,
         coalesce(dc.name, '') || ' → ' || coalesce(ac.name, ''),
         tp.first_name,
         nata.public_first(tp.first_name, tp.pseudonym, tp.use_pseudonym)
    into traveler, route, trav_name, trav_shown
    from nata.trips t
    left join nata.cities dc on dc.id = t.departure_city_id
    left join nata.cities ac on ac.id = t.arrival_city_id
    left join nata.profiles tp on tp.id = t.traveler_id
   where t.id = new.trip_id;

  select p.first_name into sender from nata.profiles p where p.id = new.sender_id;

  info := jsonb_build_object(
    'sender', coalesce(sender, ''),
    'traveler', coalesce(trav_name, ''),
    'route', coalesce(route, ''),
    'request_id', new.id);

  if tg_op = 'INSERT' then
    perform nata.notify(traveler, 'request', 'request_new',
      'New delivery request',
      coalesce(sender, 'A sender') || ' wants you to carry an item on ' || route || '.',
      new.id, info);
    return new;
  end if;

  case new.status
    when 'accepted' then
      if new.pricing = 'flat' then
        perform nata.notify(new.sender_id, 'request', 'request_accepted_fee',
          'Request accepted',
          coalesce(trav_name, 'The traveler') || ' accepted your request. Pay the Nata fee within 24 hours to start chatting.',
          new.id, info);
        return new;
      end if;
      perform nata.notify(new.sender_id, 'request', 'request_accepted',
        'Request accepted',
        coalesce(trav_name, 'The traveler') || ' accepted your request. Pay within 24 hours to confirm it.',
        new.id, info);
    when 'declined' then
      -- Not accepted: the sender only knows the traveler's public name.
      perform nata.notify(new.sender_id, 'request', 'request_declined',
        'Request declined',
        coalesce(trav_shown, 'The traveler') || ' can''t take your item. Find another traveler on ' || route || '.',
        new.id, info || jsonb_build_object('traveler', coalesce(trav_shown, '')));
    when 'expired' then
      if old.status = 'pending' then
        perform nata.notify(new.sender_id, 'request', 'request_expired_unanswered',
          'Request expired',
          coalesce(trav_shown, 'The traveler') || ' didn''t answer in time. Find another traveler.',
          new.id, info || jsonb_build_object('traveler', coalesce(trav_shown, '')));
      else
        perform nata.notify(new.sender_id, 'request', 'request_expired_unpaid',
          'Request expired',
          'The 24 hours to pay have passed, so the request was closed.',
          new.id, info);
        perform nata.notify(traveler, 'request', 'request_expired_unpaid_traveler',
          'Request expired',
          coalesce(sender, 'The sender') || ' didn''t pay in time, so the request was closed.',
          new.id, info);
      end if;
    when 'cancelled' then
      if auth.uid() is not null and auth.uid() = traveler then
        perform nata.notify(new.sender_id, 'request', 'request_cancelled_by_traveler',
          'Request cancelled',
          coalesce(trav_name, 'The traveler') || ' cancelled your request.',
          new.id, info);
      else
        perform nata.notify(traveler, 'request', 'request_cancelled_by_sender',
          'Request cancelled',
          coalesce(sender, 'The sender') || ' cancelled their request on ' || route || '.',
          new.id, info);
      end if;
    when 'paid' then
      if new.pricing = 'flat' then
        perform nata.notify(traveler, 'payment', 'contact_fee_paid',
          'Chat is open',
          coalesce(sender, 'The sender') || ' paid the Nata fee. Agree on the price and the handover in the chat.',
          new.id, info);
        perform nata.notify(new.sender_id, 'payment', 'contact_fee_received',
          'Chat is open',
          'You can now chat with ' || coalesce(trav_name, 'the traveler')
            || ' to agree on the price and the handover.',
          new.id, info);
        return new;
      end if;
      perform nata.notify(traveler, 'payment', 'request_paid',
        'Payment secured',
        coalesce(sender, 'The sender') || ' paid. The money is held safely until delivery, and chat is open.',
        new.id, info);
      perform nata.notify(new.sender_id, 'payment', 'payment_received',
        'Payment received',
        'Your payment is held safely until delivery. You can now chat with '
          || coalesce(trav_name, 'the traveler') || '.',
        new.id, info);
    when 'handed_off' then
      perform nata.notify(new.sender_id, 'trip', 'item_picked_up',
        'Item picked up',
        coalesce(trav_name, 'The traveler') || ' has your item and is on the way.',
        new.id, info);
    when 'delivered' then
      if new.pricing = 'flat' and new.receipt_confirmed_at is null then
        perform nata.notify(new.sender_id, 'request', 'delivered_by_traveler',
          'Item delivered',
          coalesce(trav_name, 'The traveler') || ' says they delivered your item. Confirm it and leave a review.',
          new.id, info);
        return new;
      end if;
      if new.pricing = 'flat' then
        perform nata.notify(traveler, 'request', 'delivery_confirmed_by_sender',
          'Delivery confirmed',
          coalesce(sender, 'The sender') || ' confirmed you delivered their item.',
          new.id, info);
        return new;
      end if;
      perform nata.notify(new.sender_id, 'request', 'item_delivered',
        'Item delivered',
        coalesce(trav_name, 'The traveler') || ' delivered your item. Confirm you received it.',
        new.id, info);
      perform nata.notify(traveler, 'payment', 'delivery_confirmed',
        'Delivery confirmed',
        'You delivered ' || coalesce(sender, 'the sender') || '''s item. Your payout is on its way.',
        new.id, info);
    else
      null;
  end case;
  return new;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 5. The traveler's list: whether they said it was delivered
-- -----------------------------------------------------------------------------
drop function if exists public.list_incoming_requests();

CREATE OR REPLACE FUNCTION public.list_incoming_requests()
 RETURNS TABLE(request_id uuid, status text, created_at timestamp with time zone, expires_at timestamp with time zone, responded_at timestamp with time zone, payout_usd numeric, items jsonb, item_weight_kg numeric, item_size text, item_size_class text, photo_paths text[], sender_id uuid, sender_first_name text, sender_last_name text, sender_avatar_path text, sender_verified boolean, sender_deliveries integer, recipient_name text, recipient_phone text, trip_id uuid, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, picked_up_at timestamp with time zone, delivered_at timestamp with time zone, code_attempts_left integer, sender_rating numeric, sender_reviewed boolean, pricing text, traveler_delivered_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
                'description', i.description,
                'value', i.value, 'value_currency', i.value_currency,
                'has_receipt', i.receipt_path is not null) order by i.position)
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
    -- Never the recipient's phone: the traveler writes to them from the
    -- app, and they answer from their link (20240181).
    null::text,
    t.id,
    dc.name,
    dc.country_code::text,
    ac.name,
    ac.country_code::text,
    t.departure_date,
    t.arrival_date,
    r.picked_up_at,
    r.delivered_at,
    greatest(0, 5 - coalesce(r.delivery_code_attempts, 0)),
    sp.sender_avg_rating,
    exists (select 1 from nata.reviews v
             where v.request_id = r.id and v.reviewer_id = auth.uid()),
    r.pricing,
    r.traveler_delivered_at
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
$function$;

revoke all on function public.list_incoming_requests() from public;
grant execute on function public.list_incoming_requests() to authenticated;

-- -----------------------------------------------------------------------------
-- 6. No more wallet: no refunds or earnings kept in a Nata balance
-- -----------------------------------------------------------------------------
update nata.payment_preferences
   set refund_to_balance = false,
       payout_schedule = 'automatic'
 where refund_to_balance or payout_schedule <> 'automatic';
