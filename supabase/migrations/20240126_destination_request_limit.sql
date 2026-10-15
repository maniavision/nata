-- A sender can have at most 5 open requests going to the same city.
--
-- Run AFTER 20240125_edit_delivery_requests.sql. Safe to re-run.
--
--   * public.create_delivery_request: same as in 20240118_request_items.sql,
--     plus the new check. "Open" means pending, accepted, paid or handed_off,
--     the same statuses as the one-request-per-trip rule, which still applies.
--     Over the limit it raises 'nata:destination_limit'.
--   * Editing a request never changes its trip, so update_delivery_request
--     needs no change.

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
