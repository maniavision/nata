-- Flat Nata fees, one request to several travelers, no recipient.
--
-- Run AFTER 20240199_request_contact_details.sql. Safe to re-run.
--
-- Nata no longer prices the delivery or holds the money for it. A sender
-- pays Nata a flat fee for each traveler who accepts; that unlocks the chat,
-- where they agree on the price and pay each other directly.
--
--   * The fee follows the sender's country of residence and whether the trip
--     stays in one country (local) or not (international):
--         USA / Canada    $2.99 local    $4.99 international
--         Europe          €1.99          €3.99
--         UK              £1.99          £3.99
--         anywhere else   $2.99          $4.99
--     nata.flat_fee(sender, trip); public.quote_request_fees(trips) for the
--     app. "Europe" is the continent EU in nata.countries, without the UK
--     (GB, GG, JE, IM count as the UK).
--   * nata.delivery_requests.pricing: 'flat' for these requests, 'distance'
--     for the earlier ones (which keep their escrow flow to the end). A flat
--     request has traveler_price 0 and the fee as platform_fee and
--     total_amount, in the fee's currency (currency).
--   * public.send_delivery_request(): one form sent to 1 to 5 travelers going
--     to the same city. One request per traveler, sharing group_id (the first
--     one's id, which is also the photo folder). No recipient. A group counts
--     once towards the 5 open requests per destination.
--   * public.accept_delivery_request(): a flat fee is converted into the
--     sender's currency when the traveler accepts: exactly when it is the
--     same currency, else rounded up (to the cent, or to a whole amount for
--     currencies worth less than a tenth of a dollar). It is the whole price:
--     display_cost 0, display_fee = display_total = the fee. Payment, its
--     providers and the checkout are unchanged; the payment's service fee is
--     the whole amount, so nothing is ever paid out to the traveler.
--   * public.confirm_delivered(): the sender confirms the traveler delivered.
--     No code, no payout; a traveler's deposit is refunded as before. The
--     traveler's code (confirm_delivery) is refused on flat requests.
--   * Cancelling a flat request: free before payment. Once the fee is paid
--     the chat is open, so a sender who cancels keeps no refund; a traveler
--     who cancels refunds the fee in full.
--   * No texts or links for a recipient on flat requests (there is none).
--   * public.update_delivery_request(): a flat request is edited without a
--     recipient, and its fee doesn't change.
--   * public.list_my_sent_requests() and list_incoming_requests(): also
--     return pricing and group_id.

-- -----------------------------------------------------------------------------
-- 1. The request's pricing and group
-- -----------------------------------------------------------------------------
alter table nata.delivery_requests
  add column if not exists pricing  text not null default 'distance',
  add column if not exists group_id uuid;
alter table nata.delivery_requests drop constraint if exists delivery_requests_pricing_check;
alter table nata.delivery_requests
  add constraint delivery_requests_pricing_check check (pricing in ('distance', 'flat'));
create index if not exists delivery_requests_group_idx
  on nata.delivery_requests (group_id) where group_id is not null;

-- -----------------------------------------------------------------------------
-- 2. The fee
-- -----------------------------------------------------------------------------
create or replace function nata.flat_fee(p_sender uuid, p_trip uuid)
returns table (amount numeric, currency text, is_local boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with place as (
    select upper(btrim(coalesce(p.country_of_residence::text, ''))) as res,
           (select c.continent::text from nata.countries c
             where c.iso_code = upper(btrim(p.country_of_residence::text))) as continent
      from nata.profiles p where p.id = p_sender
  ), route as (
    select dc.country_code = ac.country_code as is_local
      from nata.trips t
      join nata.cities dc on dc.id = t.departure_city_id
      join nata.cities ac on ac.id = t.arrival_city_id
     where t.id = p_trip
  ), region as (
    select case
             when pl.res in ('US', 'CA')             then 'na'
             when pl.res in ('GB', 'GG', 'JE', 'IM') then 'uk'
             when pl.continent = 'EU'                then 'eu'
             else 'other'
           end as r
      from (select 1) one left join place pl on true
  )
  select case when rg.r in ('eu', 'uk') then
                case when ro.is_local then 1.99 else 3.99 end
              else
                case when ro.is_local then 2.99 else 4.99 end
         end::numeric,
         case rg.r when 'eu' then 'EUR' when 'uk' then 'GBP' else 'USD' end,
         ro.is_local
    from route ro, region rg;
$$;

revoke all on function nata.flat_fee(uuid, uuid) from public;

-- The fee for each trip, for the signed-in sender.
create or replace function public.quote_request_fees(p_trip_ids uuid[])
returns table (trip_id uuid, amount numeric, currency text, is_local boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, f.amount, f.currency, f.is_local
    from unnest(coalesce(p_trip_ids, '{}'::uuid[])) as t(id)
    cross join lateral nata.flat_fee(auth.uid(), t.id) f
   where auth.uid() is not null;
$$;

revoke all on function public.quote_request_fees(uuid[]) from public;
grant execute on function public.quote_request_fees(uuid[]) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Sending one request to several travelers
-- -----------------------------------------------------------------------------
create or replace function public.send_delivery_request(
  p_id              uuid,
  p_trip_ids        uuid[],
  p_items           jsonb,
  p_item_weight_kg  numeric,
  p_item_size       text,
  p_item_size_class text,
  p_photo_paths     text[]
)
returns table (request_id uuid, trip_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  uid         uuid := auth.uid();
  trip        record;
  it          record;
  path        text;
  rid         uuid;
  n_trips     integer;
  dest        integer;
  fee         record;
  trip_class  text;
  item_count  integer;
  summary_name  text;
  summary_cat   text;
  summary_notes text;
  cur           text;
  declared      numeric;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Already sent by an earlier attempt of the same request: nothing to do.
  if exists (select 1 from nata.delivery_requests r
              where r.group_id = p_id and r.sender_id = uid) then
    return query
      select r.id, r.trip_id from nata.delivery_requests r
       where r.group_id = p_id and r.sender_id = uid
       order by r.created_at, r.id;
    return;
  end if;

  -- 1 to 5 different travelers' trips.
  n_trips := coalesce(cardinality(p_trip_ids), 0);
  if n_trips = 0 then
    raise exception 'nata:trip_unavailable';
  end if;
  if n_trips > 5 then
    raise exception 'nata:too_many_travelers';
  end if;
  if (select count(distinct x) from unnest(p_trip_ids) x) <> n_trips then
    raise exception 'nata:duplicate';
  end if;

  -- Items: 1 to 5, each with a name and a known category.
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'nata:item_required';
  end if;
  item_count := jsonb_array_length(p_items);
  if item_count > 5 then
    raise exception 'nata:too_many_items';
  end if;
  for it in
    select e.item, e.n from jsonb_array_elements(p_items) with ordinality as e(item, n)
  loop
    if jsonb_typeof(it.item) <> 'object'
       or coalesce(btrim(it.item ->> 'name'), '') = ''
       or char_length(btrim(it.item ->> 'name')) > 80
       or char_length(coalesce(it.item ->> 'description', '')) > 300 then
      raise exception 'nata:item_required';
    end if;
    if coalesce(it.item ->> 'category', '') not in ('electronics', 'apparel', 'documents') then
      raise exception 'nata:item_category_invalid';
    end if;
    if it.item ? 'value' and (
         jsonb_typeof(it.item -> 'value') <> 'number'
         or (it.item ->> 'value')::numeric < 0
         or (it.item ->> 'value')::numeric > 1000000) then
      raise exception 'nata:item_value_invalid';
    end if;
    if coalesce(it.item ->> 'receipt_path', '') <> ''
       and (it.item ->> 'receipt_path') not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  if p_item_weight_kg is null or p_item_weight_kg <= 0 then
    raise exception 'nata:weight_invalid';
  end if;
  if p_item_size_class is null or p_item_size_class not in ('envelope', 'shoebox', 'backpack') then
    raise exception 'nata:size_required';
  end if;
  if coalesce(array_length(p_photo_paths, 1), 0) = 0 then
    raise exception 'nata:photo_required';
  end if;
  foreach path in array p_photo_paths loop
    -- A photo must be in the sender's own folder for this request.
    if path not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  -- Every trip: live, someone else's, going to the same city, and able to
  -- take the parcel.
  for trip in
    select t.id, t.traveler_id, t.status, t.departure_date, t.max_weight_kg,
           t.max_size, t.arrival_city_id
      from unnest(p_trip_ids) as x(id)
      left join nata.trips t on t.id = x.id
  loop
    if trip.id is null or trip.status <> 'live' or trip.departure_date < current_date then
      raise exception 'nata:trip_unavailable';
    end if;
    if trip.traveler_id = uid then
      raise exception 'nata:own_trip';
    end if;
    if dest is null then
      dest := trip.arrival_city_id;
    elsif dest <> trip.arrival_city_id then
      raise exception 'nata:different_destinations';
    end if;
    if trip.max_weight_kg is not null and p_item_weight_kg > trip.max_weight_kg then
      raise exception 'nata:weight_too_heavy';
    end if;
    trip_class := nata.trip_size_class(trip.max_size);
    if trip_class is not null
       and nata.size_class_rank(p_item_size_class) > nata.size_class_rank(trip_class) then
      raise exception 'nata:size_too_big';
    end if;
    if exists (
      select 1 from nata.delivery_requests r
       where r.trip_id = trip.id
         and r.sender_id = uid
         and r.status in ('pending', 'accepted', 'paid', 'handed_off')
    ) then
      raise exception 'nata:duplicate';
    end if;
  end loop;

  -- At most 5 open requests per sender going to the same city; a request
  -- sent to several travelers counts once. The lock makes two sends at the
  -- same moment wait for each other.
  perform pg_advisory_xact_lock(
    hashtextextended('nata:destination:' || uid::text || ':' || dest::text, 0));
  if (
    select count(distinct coalesce(r.group_id, r.id)) from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.sender_id = uid
       and t.arrival_city_id = dest
       and r.status in ('pending', 'accepted', 'paid', 'handed_off')
  ) >= 5 then
    raise exception 'nata:destination_limit';
  end if;

  -- The summary kept on each request.
  select left(string_agg(btrim(e.item ->> 'name'), ', ' order by e.n), 120),
         min(e.item ->> 'category') filter (where e.n = 1),
         coalesce(string_agg(nullif(btrim(e.item ->> 'description'), ''), E'\n' order by e.n), '')
    into summary_name, summary_cat, summary_notes
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  select upper(btrim(s.currency_code)) into cur
    from nata.user_settings s where s.user_id = uid;
  if cur is null or cur !~ '^[A-Z]{3}$' then
    cur := 'USD';
  end if;
  select sum(round((e.item ->> 'value')::numeric, 2))
    into declared
    from jsonb_array_elements(p_items) as e(item)
   where e.item ? 'value';

  for trip in
    select x.id, x.n from unnest(p_trip_ids) with ordinality as x(id, n) order by x.n
  loop
    rid := case when trip.n = 1 then p_id else gen_random_uuid() end;
    select f.amount, f.currency into fee from nata.flat_fee(uid, trip.id) f;

    begin
      insert into nata.delivery_requests (
        id, trip_id, sender_id, group_id, pricing,
        item_name, item_category, item_description,
        item_weight_kg, item_size, item_size_class,
        traveler_price, platform_fee, total_amount, currency,
        display_currency, declared_value, declared_currency,
        expires_at, status
      ) values (
        rid, trip.id, uid, p_id, 'flat',
        summary_name, summary_cat, left(summary_notes, 300),
        p_item_weight_kg, nullif(btrim(coalesce(p_item_size, '')), ''), p_item_size_class,
        0, fee.amount, fee.amount, fee.currency,
        cur, declared, case when declared is not null then cur end,
        now() + nata.request_response_window(), 'pending'
      );
    exception when unique_violation then
      raise exception 'nata:duplicate';
    end;

    insert into nata.request_items (request_id, position, name, category, description,
                                    value, value_currency, receipt_path)
    select rid, e.n::smallint,
           btrim(e.item ->> 'name'),
           e.item ->> 'category',
           coalesce(btrim(e.item ->> 'description'), ''),
           case when e.item ? 'value' then round((e.item ->> 'value')::numeric, 2) end,
           case when e.item ? 'value' then cur end,
           nullif(btrim(coalesce(e.item ->> 'receipt_path', '')), '')
      from jsonb_array_elements(p_items) with ordinality as e(item, n);

    -- The same photos for every traveler, in the group's folder.
    insert into nata.request_photos (request_id, uploaded_by, photo_path, type)
    select rid, uid, ph, 'item' from unnest(p_photo_paths) as ph;

    request_id := rid;
    trip_id := trip.id;
    return next;
  end loop;
end;
$$;

revoke all on function public.send_delivery_request(uuid, uuid[], jsonb, numeric, text, text, text[]) from public;
grant execute on function public.send_delivery_request(uuid, uuid[], jsonb, numeric, text, text, text[]) to authenticated;

-- A group's photos are in its first request's folder: every traveler in the
-- group may read them.
create or replace function nata.is_request_member(p_request text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rid uuid;
begin
  begin
    rid := p_request::uuid;
  exception when others then
    return false;
  end;

  return exists (
    select 1
      from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where (r.id = rid or r.group_id = rid)
       and auth.uid() is not null
       and (r.sender_id = auth.uid() or t.traveler_id = auth.uid())
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Accepting fixes the fee in the sender's currency
-- -----------------------------------------------------------------------------
create or replace function public.accept_delivery_request(p_id uuid)
returns table (
  display_currency text,
  exchange_rate    numeric,
  display_cost     numeric,
  display_fee      numeric,
  display_total    numeric
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  uid   uuid := auth.uid();
  req   record;
  cur   text;
  rate  numeric;
  base  numeric;
  cost  numeric;
  fee   numeric;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.expires_at, r.traveler_price, r.platform_fee,
         r.pricing, r.currency::text as fee_cur,
         coalesce(r.display_currency, 'USD') as cur, t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id
   for update of r;

  if not found or req.traveler_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'pending'
     or (req.expires_at is not null and req.expires_at < now()) then
    raise exception 'nata:request_not_pending';
  end if;

  cur := req.cur;
  if cur = 'USD' then
    rate := 1;
  else
    select x.per_usd into rate
      from nata.exchange_rates x
     where x.currency = cur
       and x.updated_at > now() - interval '48 hours';
    if rate is null then
      raise exception 'nata:rate_unavailable';
    end if;
  end if;

  if req.pricing = 'flat' then
    -- The fee is in its own currency (USD, EUR or GBP): exact in that
    -- currency, else converted and rounded up.
    cost := 0;
    if cur = req.fee_cur then
      rate := 1;
      fee := req.platform_fee;
    else
      if req.fee_cur = 'USD' then
        base := 1;
      else
        select x.per_usd into base
          from nata.exchange_rates x
         where x.currency = req.fee_cur
           and x.updated_at > now() - interval '48 hours';
        if base is null then
          raise exception 'nata:rate_unavailable';
        end if;
      end if;
      fee := case when rate >= 10 then ceil(req.platform_fee * rate / base)
                  else ceil(req.platform_fee * rate / base * 100) / 100 end;
      rate := rate / base;
    end if;
  else
    -- Each line converted and rounded up, as the app shows it; the total is
    -- their sum.
    cost := ceil(req.traveler_price * rate);
    fee  := ceil(req.platform_fee * rate);
  end if;

  update nata.delivery_requests r
     set status           = 'accepted',
         responded_at     = now(),
         display_currency = cur,
         exchange_rate    = rate,
         display_cost     = cost,
         display_fee      = fee,
         display_total    = cost + fee,
         price_fixed_at   = now()
   where r.id = p_id;

  return query select cur, rate, cost, fee, cost + fee;
end;
$$;

revoke all on function public.accept_delivery_request(uuid) from public;
grant execute on function public.accept_delivery_request(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. The sender confirms delivery
-- -----------------------------------------------------------------------------
create or replace function public.confirm_delivered(p_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
  pay  record;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.pricing, r.delivered_at, t.traveler_id into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id and r.sender_id = uid
   for update of r;

  if not found or req.pricing <> 'flat' then
    raise exception 'nata:request_not_found';
  end if;
  if req.status = 'delivered' then
    return req.delivered_at;
  end if;
  if req.status not in ('paid', 'handed_off') then
    raise exception 'nata:request_not_paid';
  end if;

  update nata.delivery_requests
     set status = 'delivered',
         delivered_at = now(),
         picked_up_at = coalesce(picked_up_at, now()),
         receipt_confirmed_at = now()
   where id = p_id;

  update nata.profiles
     set items_delivered_count = coalesce(items_delivered_count, 0) + 1
   where id = req.traveler_id;

  -- The traveler's deposit goes back in full (20240195).
  for pay in
    select p.id from nata.payments p
     where p.request_id = p_id and p.purpose = 'deposit' and p.status = 'held'
  loop
    perform nata.queue_refund(pay.id, false);
  end loop;

  return now();
end;
$$;

revoke all on function public.confirm_delivered(uuid) from public;
grant execute on function public.confirm_delivered(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Cancelling a flat request
-- -----------------------------------------------------------------------------
create or replace function public.cancel_delivery_request(
  p_id            uuid,
  p_expected_fee  numeric default null  -- the fee the sender was shown, in USD
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
  fee  numeric(10, 2);
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Locked, so the traveler accepting at the same moment waits for us (or we
  -- for them) and the fee matches the status it is based on.
  select r.id, r.status, r.total_amount, r.cancellation_fee, r.cancelled_at,
         r.display_total, r.pricing
    into req
    from nata.delivery_requests r
   where r.id = p_id and r.sender_id = uid
   for update;

  if not found then
    raise exception 'nata:request_not_found';
  end if;

  -- Already cancelled by the sender (a retry): nothing more to do.
  if req.status = 'cancelled' and req.cancelled_at is not null then
    return req.cancellation_fee;
  end if;

  if req.pricing = 'flat' then
    -- Free until the fee is paid; once it is, the fee is kept.
    fee := case
             when req.status in ('pending', 'accepted') then 0
             when req.status = 'paid' then req.total_amount
           end;
  else
    fee := nata.cancellation_fee_for(req.status, req.total_amount);
  end if;
  if fee is null then
    raise exception 'nata:request_not_cancellable';
  end if;
  if p_expected_fee is not null and abs(p_expected_fee - fee) > 0.005 then
    raise exception 'nata:fee_changed';
  end if;

  update nata.delivery_requests
     set status                   = 'cancelled',
         cancellation_fee         = fee,
         display_cancellation_fee = case
           when req.pricing = 'flat' and req.status = 'paid' then req.display_total
           -- Once the price is fixed, the fee is 10% of the fixed price in the
           -- sender's currency, rounded up.
           when fee > 0 and req.display_total is not null
             then ceil(req.display_total * 0.10)
           when req.display_total is not null then 0
         end,
         cancelled_at             = now(),
         cancelled_by             = uid
   where id = p_id;

  return fee;
end;
$$;

revoke all on function public.cancel_delivery_request(uuid, numeric) from public;
grant execute on function public.cancel_delivery_request(uuid, numeric) to authenticated;

-- A flat fee: kept when the sender cancels after paying it, refunded in full
-- otherwise. Distance-priced requests as before (20240195).
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
      if new.pricing = 'flat' then
        if new.cancelled_by is distinct from new.sender_id then
          perform nata.queue_refund(pay, false);
        end if;
      else
        perform nata.queue_refund(pay, old.status in ('accepted', 'paid'));
      end if;
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
-- 7. The traveler's code is for distance-priced requests only
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

  select r.id, r.status, r.pricing, r.delivery_code_attempts, t.traveler_id into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id
   for update of r;

  if not found or req.traveler_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  -- The sender confirms a flat request (public.confirm_delivered).
  if req.pricing = 'flat' then
    raise exception 'nata:sender_confirms';
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

-- -----------------------------------------------------------------------------
-- 8. No recipient on flat requests; their own notifications
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION nata.recipient_on_request_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  -- Flat requests have no recipient (20240200).
  if new.pricing = 'flat' then
    return new;
  end if;
  if new.status in ('paid', 'handed_off') then
    perform nata.recipient_token(new.id);
  end if;
  if new.status = 'handed_off' then
    perform nata.request_recipient_sms(new.id, 'picked_up');
  elsif new.status = 'delivered' then
    perform nata.request_recipient_sms(new.id, 'delivered');
  end if;
  return new;
exception when others then
  raise warning 'recipient_on_request_change failed: %', sqlerrm;
  return new;
end;
$function$;
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
-- 9. Editing a flat request: no recipient, the same fee
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_delivery_request(p_id uuid, p_items jsonb, p_item_weight_kg numeric, p_item_size text, p_item_size_class text, p_recipient_name text, p_recipient_phone text, p_photo_paths text[] DEFAULT NULL::text[], p_expected_total numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid         uuid := auth.uid();
  req         record;
  trip        record;
  it          record;
  path        text;
  cost        numeric(10, 2);
  fee         numeric(10, 2);
  total       numeric(10, 2);
  trip_class  text;
  item_count  integer;
  summary_name  text;
  summary_cat   text;
  summary_notes text;
  cur           text;
  declared      numeric;
  old_receipts  text[];
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Lock the request so two edits (or an edit and the traveler's answer)
  -- cannot interleave.
  select r.id, r.sender_id, r.status, r.trip_id, r.pricing, r.traveler_price,
         r.platform_fee, r.total_amount
    into req
    from nata.delivery_requests r
   where r.id = p_id
     for update;

  if not found or req.sender_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'pending' then
    raise exception 'nata:request_not_editable';
  end if;

  select t.id, t.status, t.departure_date, t.max_weight_kg, t.max_size,
         dc.latitude  as dep_lat, dc.longitude as dep_lon,
         ac.latitude  as arr_lat, ac.longitude as arr_lon
    into trip
    from nata.trips t
    join nata.cities dc on dc.id = t.departure_city_id
    join nata.cities ac on ac.id = t.arrival_city_id
   where t.id = req.trip_id;

  if not found or trip.status <> 'live' or trip.departure_date < current_date then
    raise exception 'nata:trip_unavailable';
  end if;

  -- The same checks as create_delivery_request.
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'nata:item_required';
  end if;
  item_count := jsonb_array_length(p_items);
  if item_count > 5 then
    raise exception 'nata:too_many_items';
  end if;
  for it in
    select e.item, e.n from jsonb_array_elements(p_items) with ordinality as e(item, n)
  loop
    if jsonb_typeof(it.item) <> 'object'
       or coalesce(btrim(it.item ->> 'name'), '') = ''
       or char_length(btrim(it.item ->> 'name')) > 80
       or char_length(coalesce(it.item ->> 'description', '')) > 300 then
      raise exception 'nata:item_required';
    end if;
    if coalesce(it.item ->> 'category', '') not in ('electronics', 'apparel', 'documents') then
      raise exception 'nata:item_category_invalid';
    end if;
    -- The item's estimated value and receipt (20240194), as at creation.
    if it.item ? 'value' and (
         jsonb_typeof(it.item -> 'value') <> 'number'
         or (it.item ->> 'value')::numeric < 0
         or (it.item ->> 'value')::numeric > 1000000) then
      raise exception 'nata:item_value_invalid';
    end if;
    if coalesce(it.item ->> 'receipt_path', '') <> ''
       and (it.item ->> 'receipt_path') not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  -- Flat requests have no recipient (20240200).
  if req.pricing <> 'flat' then
    if coalesce(btrim(p_recipient_name), '') = '' then
      raise exception 'nata:recipient_required';
    end if;
    if p_recipient_phone is null or p_recipient_phone !~ '^\+[1-9][0-9]{7,14}$' then
      raise exception 'nata:phone_invalid';
    end if;
  end if;
  if p_item_weight_kg is null or p_item_weight_kg <= 0 then
    raise exception 'nata:weight_invalid';
  end if;
  if trip.max_weight_kg is not null and p_item_weight_kg > trip.max_weight_kg then
    raise exception 'nata:weight_too_heavy';
  end if;

  if p_item_size_class is null or p_item_size_class not in ('envelope', 'shoebox', 'backpack') then
    raise exception 'nata:size_required';
  end if;
  trip_class := nata.trip_size_class(trip.max_size);
  if trip_class is not null
     and nata.size_class_rank(p_item_size_class) > nata.size_class_rank(trip_class) then
    raise exception 'nata:size_too_big';
  end if;

  if p_photo_paths is not null then
    if coalesce(array_length(p_photo_paths, 1), 0) = 0 then
      raise exception 'nata:photo_required';
    end if;
    foreach path in array p_photo_paths loop
      if path not like uid::text || '/' || p_id::text || '/%' then
        raise exception 'nata:photo_invalid';
      end if;
    end loop;
  end if;

  -- Priced again, as at creation: the weight or the days to departure may
  -- have changed since.
  if req.pricing = 'flat' then
    -- The fee doesn't change.
    cost  := req.traveler_price;
    fee   := req.platform_fee;
    total := req.total_amount;
  else
  cost  := nata.delivery_cost_usd(
             nata.haversine_km(trip.dep_lat::double precision, trip.dep_lon::double precision,
                               trip.arr_lat::double precision, trip.arr_lon::double precision),
             nata.hours_until_departure(trip.departure_date),
             p_item_weight_kg);
  fee   := nata.platform_fee_for(cost);
  total := cost + fee;
  if p_expected_total is not null and abs(p_expected_total - total) > 0.05 then
    raise exception 'nata:price_changed';
  end if;
  end if;

  select left(string_agg(btrim(e.item ->> 'name'), ', ' order by e.n), 120),
         min(e.item ->> 'category') filter (where e.n = 1),
         coalesce(string_agg(nullif(btrim(e.item ->> 'description'), ''), E'\n' order by e.n), '')
    into summary_name, summary_cat, summary_notes
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  -- Values stay in the request's currency; the declared value is their total.
  select coalesce(r.display_currency::text, 'USD') into cur
    from nata.delivery_requests r where r.id = p_id;
  select sum(round((e.item ->> 'value')::numeric, 2))
    into declared
    from jsonb_array_elements(p_items) as e(item)
   where e.item ? 'value';

  update nata.delivery_requests
     set item_name        = summary_name,
         item_category    = summary_cat,
         item_description = left(summary_notes, 300),
         item_weight_kg   = p_item_weight_kg,
         item_size        = nullif(btrim(coalesce(p_item_size, '')), ''),
         item_size_class  = p_item_size_class,
         traveler_price   = cost,
         platform_fee     = fee,
         total_amount     = total,
         declared_value   = declared,
         declared_currency = case when declared is not null then cur end,
         updated_at       = now()
   where id = p_id;

  -- A receipt stays with the item in its place unless a new one is sent.
  select array_agg(i.receipt_path order by i.position)
    into old_receipts
    from nata.request_items i where i.request_id = p_id;
  delete from nata.request_items where request_id = p_id;
  insert into nata.request_items (request_id, position, name, category, description,
                                  value, value_currency, receipt_path)
  select p_id, e.n::smallint,
         btrim(e.item ->> 'name'),
         e.item ->> 'category',
         coalesce(btrim(e.item ->> 'description'), ''),
         case when e.item ? 'value' then round((e.item ->> 'value')::numeric, 2) end,
         case when e.item ? 'value' then cur end,
         coalesce(nullif(btrim(coalesce(e.item ->> 'receipt_path', '')), ''),
                  old_receipts[e.n::integer])
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  -- (request_recipients comes from the additions script; no unique key on
  -- request_id is assumed.)
  if req.pricing <> 'flat' then
    update nata.request_recipients
       set name = btrim(p_recipient_name), phone = p_recipient_phone
     where request_id = p_id;
    if not found then
      insert into nata.request_recipients (request_id, name, phone)
      values (p_id, btrim(p_recipient_name), p_recipient_phone);
    end if;
  end if;

  if p_photo_paths is not null then
    delete from nata.request_photos where request_id = p_id and type = 'item';
    foreach path in array p_photo_paths loop
      insert into nata.request_photos (request_id, uploaded_by, photo_path, type)
      values (p_id, uid, path, 'item');
    end loop;
  end if;

  return p_id;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 10. The lists: pricing and group
-- -----------------------------------------------------------------------------
drop function if exists public.list_my_sent_requests();
drop function if exists public.list_incoming_requests();

CREATE OR REPLACE FUNCTION public.list_my_sent_requests()
 RETURNS TABLE(request_id uuid, status text, created_at timestamp with time zone, total_amount numeric, cancellation_fee numeric, cancelled_at timestamp with time zone, display_currency text, exchange_rate numeric, display_cost numeric, display_fee numeric, display_total numeric, display_cancellation_fee numeric, price_fixed_at timestamp with time zone, expires_at timestamp with time zone, ticket_checked_at timestamp with time zone, id_checked_at timestamp with time zone, traveler_verified boolean, receipt_confirmed_at timestamp with time zone, reviewed boolean, ticket_on_file boolean, ticket_shared_path text, has_booking_reference boolean, currency text, item_weight_kg numeric, item_size text, item_size_class text, items jsonb, recipient_name text, recipient_phone text, photo_paths text[], trip_id uuid, traveler_id uuid, first_name text, last_name text, avatar_path text, avg_rating numeric, items_delivered_count integer, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, price numeric, trip_currency text, max_weight_kg numeric, max_size text, pricing text, group_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    r.id,
    r.status,
    r.created_at,
    r.total_amount,
    r.cancellation_fee,
    r.cancelled_at,
    r.display_currency::text,
    r.exchange_rate,
    r.display_cost,
    r.display_fee,
    r.display_total,
    r.display_cancellation_fee,
    r.price_fixed_at,
    r.expires_at,
    r.ticket_checked_at,
    r.id_checked_at,
    coalesce(p.verification_status = 'verified', false),
    r.receipt_confirmed_at,
    exists (select 1 from nata.reviews v
             where v.request_id = r.id and v.reviewer_id = r.sender_id),
    coalesce(t.ticket_receipt_path, '') <> '',
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then nullif(t.ticket_shared_path, '') end,
    coalesce(t.booking_reference, '') <> '',
    r.currency::text,
    r.item_weight_kg,
    r.item_size,
    r.item_size_class,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'name', i.name, 'category', i.category,
                'description', i.description,
                'value', i.value, 'value_currency', i.value_currency,
                'has_receipt', i.receipt_path is not null) order by i.position)
         from nata.request_items i where i.request_id = r.id),
      '[]'::jsonb),
    rr.name,
    rr.phone,
    coalesce(
      (select array_agg(ph.photo_path order by ph.photo_path)
         from nata.request_photos ph
        where ph.request_id = r.id and ph.type = 'item'),
      '{}'::text[]),
    t.id,
    t.traveler_id,
    -- The traveler's real name once they accepted; until then the
    -- pseudonym they browse under (20240183).
    case when (r.status in ('accepted', 'paid', 'handed_off', 'delivered') or (r.status = 'cancelled' and r.price_fixed_at is not null)) then p.first_name
         else nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym) end,
    case when (r.status in ('accepted', 'paid', 'handed_off', 'delivered') or (r.status = 'cancelled' and r.price_fixed_at is not null)) then p.last_name
         else nata.public_last(p.last_name, p.use_pseudonym) end,
    p.avatar_path,
    p.avg_rating,
    p.items_delivered_count,
    dc.name,
    dc.country_code::text,
    ac.name,
    ac.country_code::text,
    t.departure_date,
    t.arrival_date,
    t.price,
    t.currency::text,
    t.max_weight_kg,
    t.max_size,
    r.pricing,
    r.group_id
  from nata.delivery_requests r
  join nata.trips t      on t.id  = r.trip_id
  join nata.profiles p   on p.id  = t.traveler_id
  join nata.cities dc    on dc.id = t.departure_city_id
  join nata.cities ac    on ac.id = t.arrival_city_id
  left join nata.request_recipients rr on rr.request_id = r.id
  where auth.uid() is not null
    and r.sender_id = auth.uid()
  order by r.created_at desc;
$function$;

revoke all on function public.list_my_sent_requests() from public;
grant execute on function public.list_my_sent_requests() to authenticated;

CREATE OR REPLACE FUNCTION public.list_incoming_requests()
 RETURNS TABLE(request_id uuid, status text, created_at timestamp with time zone, expires_at timestamp with time zone, responded_at timestamp with time zone, payout_usd numeric, items jsonb, item_weight_kg numeric, item_size text, item_size_class text, photo_paths text[], sender_id uuid, sender_first_name text, sender_last_name text, sender_avatar_path text, sender_verified boolean, sender_deliveries integer, recipient_name text, recipient_phone text, trip_id uuid, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, picked_up_at timestamp with time zone, delivered_at timestamp with time zone, code_attempts_left integer, sender_rating numeric, sender_reviewed boolean, pricing text)
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
    r.pricing
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
