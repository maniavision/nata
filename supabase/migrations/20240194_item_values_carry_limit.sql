-- What items are worth, and how much a traveler can carry.
--
-- Run AFTER 20240193_withdraw_retries_failed.sql. Safe to re-run.
--
-- To keep travelers from keeping valuable items, a request now carries what
-- its items are worth, and each traveler has a carrying limit that grows with
-- their record (items above it need a refundable deposit, coming next).
--
--   * nata.request_items.value / value_currency: each item's estimated value,
--     in the sender's currency, and receipt_path: an optional receipt or
--     listing photo (in the request's photo folder). The request's
--     declared_value / declared_currency is their total.
--   * public.create_delivery_request() and update_delivery_request(): take
--     "value" and "receipt_path" on each item (older app builds send neither;
--     the value stays empty). Editing keeps an item's receipt in its place
--     unless a new one is sent.
--   * nata.carry_limit(traveler) / public.my_carry_limit(): the limit in US
--     dollars: $100 to start, $300 after 3 delivered requests, $1,000 after 10
--     with an average rating of 4.5 or more; with what unlocks the next one.
--   * public.list_incoming_requests() and public.list_my_sent_requests():
--     each item also has value, value_currency and has_receipt. The receipt
--     itself is only shown to the sender and Nata's staff.

alter table nata.request_items
  add column if not exists value numeric(12, 2),
  add column if not exists value_currency character(3),
  add column if not exists receipt_path text;
alter table nata.request_items drop constraint if exists request_items_value_check;
alter table nata.request_items add constraint request_items_value_check
  check (value is null or (value >= 0 and value <= 1000000));

-- -----------------------------------------------------------------------------
-- 1. Creating a request: item values and receipts
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_delivery_request(p_id uuid, p_trip_id uuid, p_items jsonb, p_item_weight_kg numeric, p_item_size text, p_item_size_class text, p_recipient_name text, p_recipient_phone text, p_photo_paths text[], p_expected_total numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid         uuid := auth.uid();
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
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Already created by an earlier attempt of the same request: nothing to do.
  if exists (select 1 from nata.delivery_requests where id = p_id and sender_id = uid) then
    return p_id;
  end if;

  select t.id, t.traveler_id, t.status, t.departure_date, t.max_weight_kg,
         t.max_size, t.arrival_city_id,
         dc.latitude  as dep_lat, dc.longitude as dep_lon,
         ac.latitude  as arr_lat, ac.longitude as arr_lon
    into trip
    from nata.trips t
    join nata.cities dc on dc.id = t.departure_city_id
    join nata.cities ac on ac.id = t.arrival_city_id
   where t.id = p_trip_id;

  if not found or trip.status <> 'live' or trip.departure_date < current_date then
    raise exception 'nata:trip_unavailable';
  end if;
  if trip.traveler_id = uid then
    raise exception 'nata:own_trip';
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
    -- The item's estimated value (20240194): a number from 0 to 1,000,000,
    -- in the sender's currency. Older app builds don't send one.
    if it.item ? 'value' and (
         jsonb_typeof(it.item -> 'value') <> 'number'
         or (it.item ->> 'value')::numeric < 0
         or (it.item ->> 'value')::numeric > 1000000) then
      raise exception 'nata:item_value_invalid';
    end if;
    -- A receipt must be in the sender's own folder for this request.
    if coalesce(it.item ->> 'receipt_path', '') <> ''
       and (it.item ->> 'receipt_path') not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  if coalesce(btrim(p_recipient_name), '') = '' then
    raise exception 'nata:recipient_required';
  end if;
  if p_recipient_phone is null or p_recipient_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'nata:phone_invalid';
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

  if coalesce(array_length(p_photo_paths, 1), 0) = 0 then
    raise exception 'nata:photo_required';
  end if;

  -- The price: distance between the cities, the parcel's weight and how close
  -- the flight is. Calculated here and frozen on the request. The number of
  -- items does not change it. If it is not what the sender was shown (the day
  -- changed, so the flight is a day closer) they look again before sending.
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

  -- One open request per sender and trip (also enforced by a unique index).
  if exists (
    select 1 from nata.delivery_requests r
     where r.trip_id = p_trip_id
       and r.sender_id = uid
       and r.status in ('pending', 'accepted', 'paid', 'handed_off')
  ) then
    raise exception 'nata:duplicate';
  end if;

  -- At most 5 open requests per sender going to the same city, across all
  -- travelers. The lock makes two sends at the same moment wait for each
  -- other, so they cannot both see 4 and make it 6.
  perform pg_advisory_xact_lock(
    hashtextextended('nata:destination:' || uid::text || ':' || trip.arrival_city_id::text, 0));
  if (
    select count(*) from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.sender_id = uid
       and t.arrival_city_id = trip.arrival_city_id
       and r.status in ('pending', 'accepted', 'paid', 'handed_off')
  ) >= 5 then
    raise exception 'nata:destination_limit';
  end if;

  -- The summary kept on the request itself.
  select left(string_agg(btrim(e.item ->> 'name'), ', ' order by e.n), 120),
         min(e.item ->> 'category') filter (where e.n = 1),
         coalesce(string_agg(nullif(btrim(e.item ->> 'description'), ''), E'\n' order by e.n), '')
    into summary_name, summary_cat, summary_notes
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  -- Values are in the sender's currency (as the request's display_currency,
  -- set by its trigger); the declared value is their total.
  select upper(btrim(s.currency_code)) into cur
    from nata.user_settings s where s.user_id = uid;
  if cur is null or cur !~ '^[A-Z]{3}$' then
    cur := 'USD';
  end if;
  select sum(round((e.item ->> 'value')::numeric, 2))
    into declared
    from jsonb_array_elements(p_items) as e(item)
   where e.item ? 'value';

  begin
    insert into nata.delivery_requests (
      id, trip_id, sender_id,
      item_name, item_category, item_description,
      item_weight_kg, item_size, item_size_class,
      traveler_price, platform_fee, total_amount, currency,
      display_currency, declared_value, declared_currency,
      expires_at, status
    ) values (
      p_id, p_trip_id, uid,
      summary_name, summary_cat, left(summary_notes, 300),
      p_item_weight_kg, nullif(btrim(coalesce(p_item_size, '')), ''), p_item_size_class,
      cost, fee, total, 'USD',
      cur, declared, case when declared is not null then cur end,
      now() + nata.request_response_window(), 'pending'
    );
  exception when unique_violation then
    raise exception 'nata:duplicate';
  end;

  insert into nata.request_items (request_id, position, name, category, description,
                                  value, value_currency, receipt_path)
  select p_id, e.n::smallint,
         btrim(e.item ->> 'name'),
         e.item ->> 'category',
         coalesce(btrim(e.item ->> 'description'), ''),
         case when e.item ? 'value' then round((e.item ->> 'value')::numeric, 2) end,
         case when e.item ? 'value' then cur end,
         nullif(btrim(coalesce(e.item ->> 'receipt_path', '')), '')
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  -- The recipient lives in its own table: the traveler only sees it after
  -- accepting.
  insert into nata.request_recipients (request_id, name, phone)
  values (p_id, btrim(p_recipient_name), p_recipient_phone);

  foreach path in array p_photo_paths loop
    -- A photo must be in the sender's own folder for this request.
    if path not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
    insert into nata.request_photos (request_id, uploaded_by, photo_path, type)
    values (p_id, uid, path, 'item');
  end loop;

  return p_id;
end;
$function$;


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
  select r.id, r.sender_id, r.status, r.trip_id
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

  if coalesce(btrim(p_recipient_name), '') = '' then
    raise exception 'nata:recipient_required';
  end if;
  if p_recipient_phone is null or p_recipient_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'nata:phone_invalid';
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
  update nata.request_recipients
     set name = btrim(p_recipient_name), phone = p_recipient_phone
   where request_id = p_id;
  if not found then
    insert into nata.request_recipients (request_id, name, phone)
    values (p_id, btrim(p_recipient_name), p_recipient_phone);
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
-- 2. Carrying limits
-- -----------------------------------------------------------------------------
create or replace function nata.carry_limit(p_user uuid)
returns table (
  level              integer,
  limit_usd          numeric,
  delivered          integer,
  rating             numeric,
  next_limit_usd     numeric,
  deliveries_needed  integer,
  rating_needed      numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with s as (
    select
      (select count(*)::integer
         from nata.delivery_requests r
         join nata.trips t on t.id = r.trip_id
        where t.traveler_id = p_user and r.status = 'delivered') as delivered,
      (select p.avg_rating from nata.profiles p where p.id = p_user) as rating
  )
  select
    case when s.delivered >= 10 and coalesce(s.rating, 0) >= 4.5 then 3
         when s.delivered >= 3 then 2
         else 1 end,
    case when s.delivered >= 10 and coalesce(s.rating, 0) >= 4.5 then 1000
         when s.delivered >= 3 then 300
         else 100 end::numeric,
    s.delivered,
    s.rating,
    case when s.delivered >= 10 and coalesce(s.rating, 0) >= 4.5 then null
         when s.delivered >= 3 then 1000
         else 300 end::numeric,
    case when s.delivered >= 10 and coalesce(s.rating, 0) >= 4.5 then 0
         when s.delivered >= 3 then greatest(0, 10 - s.delivered)
         else 3 - s.delivered end,
    case when s.delivered >= 3 and not (s.delivered >= 10 and coalesce(s.rating, 0) >= 4.5)
         then 4.5 end::numeric
  from s;
$$;
revoke all on function nata.carry_limit(uuid) from public, anon, authenticated;

create or replace function public.my_carry_limit()
returns table (
  level              integer,
  limit_usd          numeric,
  delivered          integer,
  rating             numeric,
  next_limit_usd     numeric,
  deliveries_needed  integer,
  rating_needed      numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from nata.carry_limit(auth.uid()) where auth.uid() is not null;
$$;
revoke all on function public.my_carry_limit() from public, anon;
grant execute on function public.my_carry_limit() to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Item values in the request lists (the live functions with only that
--    added)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_incoming_requests()
 RETURNS TABLE(request_id uuid, status text, created_at timestamp with time zone, expires_at timestamp with time zone, responded_at timestamp with time zone, payout_usd numeric, items jsonb, item_weight_kg numeric, item_size text, item_size_class text, photo_paths text[], sender_id uuid, sender_first_name text, sender_last_name text, sender_avatar_path text, sender_verified boolean, sender_deliveries integer, recipient_name text, recipient_phone text, trip_id uuid, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, picked_up_at timestamp with time zone, delivered_at timestamp with time zone, code_attempts_left integer, sender_rating numeric, sender_reviewed boolean)
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
             where v.request_id = r.id and v.reviewer_id = auth.uid())
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

CREATE OR REPLACE FUNCTION public.list_my_sent_requests()
 RETURNS TABLE(request_id uuid, status text, created_at timestamp with time zone, total_amount numeric, cancellation_fee numeric, cancelled_at timestamp with time zone, display_currency text, exchange_rate numeric, display_cost numeric, display_fee numeric, display_total numeric, display_cancellation_fee numeric, price_fixed_at timestamp with time zone, expires_at timestamp with time zone, ticket_checked_at timestamp with time zone, id_checked_at timestamp with time zone, traveler_verified boolean, receipt_confirmed_at timestamp with time zone, reviewed boolean, ticket_on_file boolean, ticket_shared_path text, has_booking_reference boolean, currency text, item_weight_kg numeric, item_size text, item_size_class text, items jsonb, recipient_name text, recipient_phone text, photo_paths text[], trip_id uuid, traveler_id uuid, first_name text, last_name text, avatar_path text, avg_rating numeric, items_delivered_count integer, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, price numeric, trip_currency text, max_weight_kg numeric, max_size text)
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
    t.max_size
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
