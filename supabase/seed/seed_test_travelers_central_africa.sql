-- ============================================================================
-- Test data, part 2: 20 more fake travelers on Central Africa <-> Europe routes
-- (Pointe-Noire -> Brazzaville, Brazzaville -> Paris, Kinshasa, Douala, ...).
--
-- DEV / STAGING ONLY. Never run this against production.
--
-- Run in the Supabase SQL Editor (it runs as postgres, so RLS is bypassed):
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql
--
-- Properties (same as seed_test_travelers.sql, which does NOT need to be run
-- first, but its travelers 1-20 are untouched if it was)
--   * Safe to re-run: fixed ids + upserts. Re-running also moves the trip
--     dates forward so they are always in the future.
--   * The fake users CANNOT log in (no password, no phone, banned until 2999).
--   * Easy to remove: emails are seed+21 ... seed+40 @nata.test, so
--     remove_test_travelers.sql removes these too.
--   * Needs nata.countries to contain CG, CD, CM, GA, BE, AO, CA and FR. Any
--     route whose country is missing is skipped (the check at the bottom
--     tells you which).
--   * Every city gets coordinates, which the delivery price needs (distance).
-- ============================================================================

begin;

-- 1. Cities ---------------------------------------------------------------------
--    If a city already exists without coordinates (the price is worked out from
--    the distance), the coordinates are filled in; existing ones are kept.
insert into nata.cities (country_code, name, latitude, longitude, is_capital)
select v.cc, v.name, v.lat, v.lon, v.cap
from (values
  ('CG', 'Pointe-Noire',  -4.769200,  11.866400, false),
  ('CG', 'Brazzaville',   -4.263400,  15.242900, true),
  ('CD', 'Kinshasa',      -4.441900,  15.266300, true),
  ('CM', 'Douala',         4.051100,   9.767900, false),
  ('CM', 'Yaoundé',        3.848000,  11.502100, true),
  ('GA', 'Libreville',     0.416200,   9.467300, true),
  ('AO', 'Luanda',        -8.839000,  13.289400, true),
  ('BE', 'Brussels',      50.850300,   4.351700, true),
  ('CA', 'Montréal',      45.501700, -73.567300, false),
  ('FR', 'Paris',         48.856600,   2.352200, true)
) as v(cc, name, lat, lon, cap)
where exists (select 1 from nata.countries c where c.iso_code = v.cc)
on conflict (country_code, name) do update set
  latitude  = coalesce(nata.cities.latitude,  excluded.latitude),
  longitude = coalesce(nata.cities.longitude, excluded.longitude);

-- 2. Fake auth users ------------------------------------------------------------
with t(n, first_name, last_name) as (values
  (21, 'Nadège',    'Mpassi'),     (22, 'Junior',    'Makosso'),
  (23, 'Prisca',    'Ngoma'),      (24, 'Exaucé',    'Nkounkou'),
  (25, 'Chancelle', 'Moukoko'),    (26, 'Giscard',   'Mouanda'),
  (27, 'Grâce',     'Loemba'),     (28, 'Rodrigue',  'Tsiba'),
  (29, 'Ornella',   'Bakala'),     (30, 'Fabrice',   'Ndinga'),
  (31, 'Merveille', 'Kimbembe'),   (32, 'Hervé',     'Massamba'),
  (33, 'Sandrine',  'Batchi'),     (34, 'Patrick',   'Itoua'),
  (35, 'Blessing',  'Mbemba'),     (36, 'Christ',    'Mabiala'),
  (37, 'Estelle',   'Ekani'),      (38, 'Arnaud',    'Pembe'),
  (39, 'Larissa',   'Kabongo'),    (40, 'Joël',      'Mukendi')
)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, banned_until,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  ('5eed0000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'authenticated',
  'authenticated',
  'seed+' || n || '@nata.test',
  '',
  now(),
  '{"provider":"seed","providers":["seed"],"seed":true}'::jsonb,
  jsonb_build_object('first_name', first_name, 'last_name', last_name, 'seed', true),
  now(),
  now(),
  '2999-12-31 00:00:00+00'::timestamptz,
  '', '', '', ''
from t
on conflict (id) do nothing;

-- 3. Profiles -------------------------------------------------------------------
with t(n, first_name, last_name, gender, rating, delivered) as (values
  (21, 'Nadège',    'Mpassi',   'women', 4.9,  44), (22, 'Junior',    'Makosso',  'men',   4.8,  36),
  (23, 'Prisca',    'Ngoma',    'women', 4.7,  21), (24, 'Exaucé',    'Nkounkou', 'men',   4.9,  58),
  (25, 'Chancelle', 'Moukoko',  'women', 4.6,  14), (26, 'Giscard',   'Mouanda',  'men',   4.8,  67),
  (27, 'Grâce',     'Loemba',   'women', 5.0,  82), (28, 'Rodrigue',  'Tsiba',    'men',   4.5,   9),
  (29, 'Ornella',   'Bakala',   'women', 4.8,  33), (30, 'Fabrice',   'Ndinga',   'men',   4.7,  27),
  (31, 'Merveille', 'Kimbembe', 'women', 4.9,  51), (32, 'Hervé',     'Massamba', 'men',   4.6,  18),
  (33, 'Sandrine',  'Batchi',   'women', 4.4,   6), (34, 'Patrick',   'Itoua',    'men',   4.8,  45),
  (35, 'Blessing',  'Mbemba',   'women', 4.7,  23), (36, 'Christ',    'Mabiala',  'men',   4.9,  72),
  (37, 'Estelle',   'Ekani',    'women', 4.8,  30), (38, 'Arnaud',    'Pembe',    'men',   4.3,  11),
  (39, 'Larissa',   'Kabongo',  'women', 4.6,  16), (40, 'Joël',      'Mukendi',  'men',   5.0,  94)
)
insert into nata.profiles (
  id, first_name, last_name, avatar_path,
  verification_status, items_delivered_count, avg_rating
)
select
  ('5eed0000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  first_name,
  last_name,
  'https://randomuser.me/api/portraits/' || gender || '/' || ((n * 3 + 7) % 90) || '.jpg',
  'verified',
  delivered,
  rating
from t
on conflict (id) do update set
  first_name            = excluded.first_name,
  last_name             = excluded.last_name,
  avatar_path           = excluded.avatar_path,
  verification_status   = excluded.verification_status,
  items_delivered_count = excluded.items_delivered_count,
  avg_rating            = excluded.avg_rating;

-- 4. Trips: 1-3 live trips per traveler -----------------------------------------
--    flight_days = 0 for short hops that land the same day.
with r(idx, dep_cc, dep_city, arr_cc, arr_city, base_price, flight_days) as (values
  ( 1, 'CG', 'Pointe-Noire', 'CG', 'Brazzaville',  20, 0),
  ( 2, 'CG', 'Brazzaville',  'CG', 'Pointe-Noire', 20, 0),
  ( 3, 'CG', 'Brazzaville',  'FR', 'Paris',        45, 1),
  ( 4, 'FR', 'Paris',        'CG', 'Brazzaville',  40, 1),
  ( 5, 'CG', 'Pointe-Noire', 'FR', 'Paris',        48, 1),
  ( 6, 'FR', 'Paris',        'CG', 'Pointe-Noire', 42, 1),
  ( 7, 'CD', 'Kinshasa',     'CG', 'Brazzaville',  12, 0),
  ( 8, 'CG', 'Brazzaville',  'CD', 'Kinshasa',     12, 0),
  ( 9, 'CM', 'Douala',       'FR', 'Paris',        40, 1),
  (10, 'GA', 'Libreville',   'FR', 'Paris',        38, 1),
  (11, 'BE', 'Brussels',     'CD', 'Kinshasa',     45, 1),
  (12, 'CG', 'Brazzaville',  'BE', 'Brussels',     44, 1),
  (13, 'CM', 'Yaoundé',      'CM', 'Douala',       12, 0),
  (14, 'CG', 'Brazzaville',  'CA', 'Montréal',     52, 1),
  (15, 'AO', 'Luanda',       'CD', 'Kinshasa',     28, 0),
  (16, 'FR', 'Paris',        'CD', 'Kinshasa',     44, 1)
),
tr as (
  select n, k
  from generate_series(21, 40) as n,
       lateral generate_series(1, 1 + (n % 3)) as k
),
planned as (
  select
    tr.n,
    tr.k,
    r.*,
    current_date + (2 + ((tr.n * 7 + tr.k * 11) % 40)) as dep_date
  from tr
  join r on r.idx = ((tr.n - 21) + 5 * (tr.k - 1)) % 16 + 1
)
insert into nata.trips (
  id, traveler_id, departure_city_id, departure_date,
  arrival_city_id, arrival_date, price, currency,
  max_weight_kg, max_size, ticket_receipt_path, status
)
select
  md5('seed-trip-' || p.n || '-' || p.k)::uuid,
  ('5eed0000-0000-4000-8000-' || lpad(p.n::text, 12, '0'))::uuid,
  dc.id,
  p.dep_date,
  ac.id,
  p.dep_date + p.flight_days,
  p.base_price + ((p.n * 3 + p.k) % 10),
  'USD',
  (array[1, 3, 5, 10])[1 + (p.n + p.k) % 4],
  (array['Envelope / Document', 'Shoebox (30×20×15 cm)', 'Backpack size'])[1 + (p.n * p.k) % 3],
  'seed/ticket_placeholder.pdf',
  'live'
from planned p
join nata.cities dc on dc.country_code = p.dep_cc and dc.name = p.dep_city
join nata.cities ac on ac.country_code = p.arr_cc and ac.name = p.arr_city
on conflict (id) do update set
  departure_date = excluded.departure_date,
  arrival_date   = excluded.arrival_date,
  price          = excluded.price,
  max_weight_kg  = excluded.max_weight_kg,
  max_size       = excluded.max_size,
  status         = 'live';

commit;

-- Check 1: what was created (expect 20 users, 20 profiles, about 40 trips) ------
select
  (select count(*) from auth.users    where email ~ '^seed\+(2[1-9]|3[0-9]|40)@nata\.test$') as fake_users,
  (select count(*) from nata.profiles where id::text ~ '^5eed0000-0000-4000-8000-0000000000(2[1-9]|3[0-9]|40)$') as profiles,
  (select count(*) from nata.trips    where traveler_id::text ~ '^5eed0000-0000-4000-8000-0000000000(2[1-9]|3[0-9]|40)$') as trips;

-- Check 2: the routes now available, with how many trips each has --------------
select dc.name as departure, ac.name as arrival, count(*) as trips,
       min(t.departure_date) as first_departure
from nata.trips t
join nata.cities dc on dc.id = t.departure_city_id
join nata.cities ac on ac.id = t.arrival_city_id
where t.traveler_id::text ~ '^5eed0000-0000-4000-8000-0000000000(2[1-9]|3[0-9]|40)$'
group by dc.name, ac.name
order by trips desc, departure, arrival;

-- Check 3: cities the delivery price cannot use (no coordinates). Expect 0 rows.
select country_code, name from nata.cities
where name in ('Pointe-Noire', 'Brazzaville', 'Kinshasa', 'Douala', 'Yaoundé',
               'Libreville', 'Luanda', 'Brussels', 'Montréal', 'Paris')
  and (latitude is null or longitude is null);
