-- Senders can see their own requests and edit them while they are pending.
--
-- Run AFTER 20240118_request_items.sql (needs request_items and the pricing
-- functions from 20240117). Safe to re-run.
--
--   * public.list_my_sent_requests(): the signed-in user's requests, newest
--     first, with the trip, the traveler's public details, the items, the
--     recipient and the photo paths: everything the app needs to show and
--     edit them.
--   * public.update_delivery_request(...): changes a request. Only its
--     sender, only while it is 'pending' and the trip has not left. It checks
--     exactly what create_delivery_request checks, prices the request again
--     (weight and departure may have changed), replaces the items and the
--     recipient, and replaces the photos when new ones are given.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. The sender's requests
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.list_my_sent_requests();

create or replace function public.list_my_sent_requests()
returns table (
  request_id             uuid,
  status                 text,
  created_at             timestamptz,
  total_amount           numeric,
  currency               text,
  item_weight_kg         numeric,
  item_size              text,
  item_size_class        text,
  items                  jsonb,
  recipient_name         text,
  recipient_phone        text,
  photo_paths            text[],
  -- The trip and its traveler, as public.search_travelers returns them.
  trip_id                uuid,
  traveler_id            uuid,
  first_name             text,
  last_name              text,
  avatar_path            text,
  avg_rating             numeric,
  items_delivered_count  integer,
  departure_city         text,
  departure_country      text,
  arrival_city           text,
  arrival_country        text,
  departure_date         date,
  arrival_date           date,
  price                  numeric,
  trip_currency          text,
  max_weight_kg          numeric,
  max_size               text
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
    r.total_amount,
    r.currency::text,
    r.item_weight_kg,
    r.item_size,
    r.item_size_class,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'name', i.name, 'category', i.category,
                'description', i.description) order by i.position)
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
    p.first_name,
    p.last_name,
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
$$;

revoke all on function public.list_my_sent_requests() from public;
grant execute on function public.list_my_sent_requests() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Edit a pending request
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.update_delivery_request(uuid, jsonb, numeric, text, text, text, text, text[], numeric);

create or replace function public.update_delivery_request(
  p_id                uuid,
  p_items             jsonb,                 -- [{"name","category","description"}, ...]
  p_item_weight_kg    numeric,
  p_item_size         text,
  p_item_size_class   text,
  p_recipient_name    text,
  p_recipient_phone   text,
  p_photo_paths       text[] default null,   -- null: keep the current photos
  p_expected_total    numeric default null   -- the total in USD the sender was shown
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
         updated_at       = now()
   where id = p_id;

  delete from nata.request_items where request_id = p_id;
  insert into nata.request_items (request_id, position, name, category, description)
  select p_id, e.n::smallint,
         btrim(e.item ->> 'name'),
         e.item ->> 'category',
         coalesce(btrim(e.item ->> 'description'), '')
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
$$;

revoke all on function public.update_delivery_request(uuid, jsonb, numeric, text, text, text, text, text[], numeric) from public;
grant execute on function public.update_delivery_request(uuid, jsonb, numeric, text, text, text, text, text[], numeric) to authenticated;
