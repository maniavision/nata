-- Delivery pricing: the cost is calculated from the DISTANCE between the
-- departure and arrival cities, the package WEIGHT, and how close the flight
-- is. It replaces "traveler's price + 10%" in create_delivery_request.
--
-- Run AFTER 20240115_delivery_requests_v2.sql. Safe to re-run.
--
-- This is the same formula as the app's lib/services/delivery_pricing.dart (and
-- the Java CostCalculator it was ported from):
--
--   cost = 5.00 + distance_km * 0.0123456789 + weight_kg * 3.00 + 750 / hours
--
--   * distance_km  Haversine distance between the cities (nata.cities lat/lon)
--   * hours        whole days until the departure date * 24, never less than 24
--   * rounded half up to cents; the urgency term is rounded to 4 decimals first
--
-- The price is stored in US DOLLARS on the request (currency = 'USD'). The app
-- converts it to the user's currency for display with live exchange rates; the
-- database never converts. The platform fee stays 10% of the cost.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Building blocks
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function nata.haversine_km(
  lat1 double precision, lon1 double precision,
  lat2 double precision, lon2 double precision
)
returns double precision
language sql
immutable
as $$
  select 2 * 6371 * asin(sqrt(
           power(sin(radians(lat2 - lat1) / 2), 2)
         + cos(radians(lat1)) * cos(radians(lat2))
           * power(sin(radians(lon2 - lon1) / 2), 2)
         ));
$$;

-- Whole days until departure (UTC), times 24, but never under 24 hours.
create or replace function nata.hours_until_departure(departure_date date)
returns integer
language sql
stable
as $$
  select greatest(24, (departure_date - (now() at time zone 'utc')::date) * 24);
$$;

create or replace function nata.delivery_cost_usd(
  distance_km double precision,
  hours       integer,
  weight_kg   numeric
)
returns numeric
language plpgsql
immutable
as $$
begin
  if distance_km < 0 then raise exception 'nata:distance_invalid'; end if;
  if weight_kg   < 0 then raise exception 'nata:weight_invalid';   end if;
  if hours       < 24 then raise exception 'nata:hours_invalid';   end if;

  return round(
           5.00
           + distance_km::numeric * 0.0123456789
           + weight_kg * 3.00
           + round(750.00 / hours, 4),
           2);
end;
$$;

-- Reference values (same as the app's unit tests). Run this to check the
-- functions: every row should say ok = true.
--
--   select expected, nata.delivery_cost_usd(d, h, w) as got,
--          nata.delivery_cost_usd(d, h, w) = expected as ok
--   from (values
--     (0::double precision,      24, 0::numeric,    36.25::numeric),
--     (100,                      24, 1,             40.48),
--     (5000,                     24, 0.9,          100.68),
--     (5000,                     48, 0.9,           85.05),
--     (5000,                    720, 0.9,           70.47),
--     (5000,                 100000, 3,             75.74),
--     (4994.6,                  168, 2.5,           78.63),
--     (1234.5678,                33, 0.45,          44.32),
--     (20000,                    24, 10,           313.16)
--   ) as t(d, h, w, expected);
--
--   -- Lagos to London is about 5012 km:
--   select nata.haversine_km(6.5244, 3.3792, 51.5074, -0.1278);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Create a request: the price comes from the formula above
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.create_delivery_request(
  p_id                uuid,
  p_trip_id           uuid,
  p_item_name         text,
  p_item_category     text,
  p_item_description  text,
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
  path        text;
  cost        numeric(10, 2);
  fee         numeric(10, 2);
  total       numeric(10, 2);
  trip_class  text;
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

  if coalesce(btrim(p_item_name), '') = '' then
    raise exception 'nata:item_required';
  end if;
  if p_item_category is null or p_item_category not in ('electronics', 'apparel', 'documents') then
    raise exception 'nata:item_category_invalid';
  end if;
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

  -- The price, calculated here and frozen on the request. If it is not what
  -- the sender was shown (the day changed, so the flight is a day closer), they
  -- look again before sending. A few cents of difference are ignored: the app
  -- and the database round the same formula in different number types.
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

  begin
    insert into nata.delivery_requests (
      id, trip_id, sender_id,
      item_name, item_category, item_description,
      item_weight_kg, item_size, item_size_class,
      traveler_price, platform_fee, total_amount, currency,
      expires_at, status
    ) values (
      p_id, p_trip_id, uid,
      btrim(p_item_name), p_item_category, coalesce(btrim(p_item_description), ''),
      p_item_weight_kg, nullif(btrim(coalesce(p_item_size, '')), ''), p_item_size_class,
      cost, fee, total, 'USD',
      now() + nata.request_response_window(), 'pending'
    );
  exception when unique_violation then
    raise exception 'nata:duplicate';
  end;

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

revoke all on function public.create_delivery_request(uuid, uuid, text, text, text, numeric, text, text, text, text, text[], numeric) from public;
grant execute on function public.create_delivery_request(uuid, uuid, text, text, text, numeric, text, text, text, text, text[], numeric) to authenticated;
