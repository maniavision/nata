-- A delivery request can carry several items.
--
-- Run AFTER 20240115_delivery_requests_v2.sql (it works whether or not
-- 20240117_delivery_pricing.sql was run first: this file replaces the
-- function in full). Safe to re-run.
--
-- What changes
--   * nata.request_items: one row per item (name, category, notes), in the
--     order the sender added them. Only the sender and the trip's traveler can
--     read them.
--   * public.create_delivery_request takes p_items (a JSON array of
--     {name, category, description}, 1 to 5 items) instead of the single
--     p_item_name / p_item_category / p_item_description. Weight, size and
--     photos still belong to the whole parcel.
--   * delivery_requests.item_name / item_category / item_description stay as a
--     summary of the items (names joined with ", ", the first item's category,
--     the notes joined, cut to 300 characters; request_items has them in full),
--     so the Messages list and older code keep working.
--   * Existing requests get one item row made from their current columns.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. The items table
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists nata.request_items (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null references nata.delivery_requests (id) on delete cascade,
  position     smallint not null check (position between 1 and 5),
  name         text not null check (btrim(name) <> '' and char_length(name) <= 80),
  category     text not null check (category in ('electronics', 'apparel', 'documents')),
  description  text not null default '' check (char_length(description) <= 300),
  created_at   timestamptz not null default now(),
  unique (request_id, position)
);

alter table nata.request_items enable row level security;

drop policy if exists "Participants can read request items" on nata.request_items;
create policy "Participants can read request items"
  on nata.request_items for select
  to authenticated
  using (nata.is_request_member(request_id::text));

-- Items are written only by create_delivery_request.
revoke all on nata.request_items from anon, authenticated;
grant select on nata.request_items to authenticated;

-- Requests made before this change: one item each.
insert into nata.request_items (request_id, position, name, category, description)
select r.id, 1,
       left(coalesce(nullif(btrim(r.item_name), ''), nullif(btrim(r.item_description), '')), 80),
       r.item_category,
       left(coalesce(btrim(r.item_description), ''), 300)
  from nata.delivery_requests r
 where r.item_category in ('electronics', 'apparel', 'documents')
   and coalesce(nullif(btrim(r.item_name), ''), nullif(btrim(r.item_description), '')) is not null
   and not exists (select 1 from nata.request_items i where i.request_id = r.id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Create a request with one or more items
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.create_delivery_request(uuid, uuid, text, text, text, numeric, text, text, text, text, text[], numeric);

create or replace function public.create_delivery_request(
  p_id                uuid,
  p_trip_id           uuid,
  p_items             jsonb,                 -- [{"name","category","description"}, ...]
  p_item_weight_kg    numeric,
  p_item_size         text,
  p_item_size_class   text,
  p_recipient_name    text,
  p_recipient_phone   text,
  p_photo_paths       text[],
  p_expected_total    numeric default null   -- the total in USD the sender was shown
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Already created by an earlier attempt of the same request: nothing to do.
  if exists (select 1 from nata.delivery_requests where id = p_id and sender_id = uid) then
    return p_id;
  end if;

  select t.id, t.traveler_id, t.status, t.departure_date, t.max_weight_kg,
         t.max_size,
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

  -- The summary kept on the request itself.
  select left(string_agg(btrim(e.item ->> 'name'), ', ' order by e.n), 120),
         min(e.item ->> 'category') filter (where e.n = 1),
         coalesce(string_agg(nullif(btrim(e.item ->> 'description'), ''), E'\n' order by e.n), '')
    into summary_name, summary_cat, summary_notes
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  begin
    insert into nata.delivery_requests (
      id, trip_id, sender_id,
      item_name, item_category, item_description,
      item_weight_kg, item_size, item_size_class,
      traveler_price, platform_fee, total_amount, currency,
      expires_at, status
    ) values (
      p_id, p_trip_id, uid,
      summary_name, summary_cat, left(summary_notes, 300),
      p_item_weight_kg, nullif(btrim(coalesce(p_item_size, '')), ''), p_item_size_class,
      cost, fee, total, 'USD',
      now() + nata.request_response_window(), 'pending'
    );
  exception when unique_violation then
    raise exception 'nata:duplicate';
  end;

  insert into nata.request_items (request_id, position, name, category, description)
  select p_id, e.n::smallint,
         btrim(e.item ->> 'name'),
         e.item ->> 'category',
         coalesce(btrim(e.item ->> 'description'), '')
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
$$;

revoke all on function public.create_delivery_request(uuid, uuid, jsonb, numeric, text, text, text, text, text[], numeric) from public;
grant execute on function public.create_delivery_request(uuid, uuid, jsonb, numeric, text, text, text, text, text[], numeric) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Check (run after): every request has at least one item. Expect 0.
--   select count(*) from nata.delivery_requests r
--    where not exists (select 1 from nata.request_items i where i.request_id = r.id);
-- ─────────────────────────────────────────────────────────────────────────────
