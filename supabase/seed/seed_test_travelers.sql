-- ============================================================================
-- Test data: 20 fake travelers with upcoming "live" trips.
--
-- DEV / STAGING ONLY. Never run this against production.
--
-- Run in the Supabase SQL Editor (it runs as postgres, so RLS is bypassed):
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql
--
-- Properties
--   * Safe to re-run: fixed ids + upserts. Re-running also moves the trip
--     dates forward so they are always in the future.
--   * The fake users CANNOT log in: no password, no phone number (the app
--     signs in by SMS OTP), and the account is banned until 2999.
--   * Easy to remove: all are emails seed+N@nata.test. See
--     remove_test_travelers.sql.
--   * Requires: nata.countries populated (for the city inserts), plus the
--     nata.profiles / nata.cities / nata.trips tables.
-- ============================================================================

begin;

-- 1. Cities (skipped for any country that is not in nata.countries) -----------
insert into nata.cities (country_code, name, latitude, longitude, is_capital)
select v.cc, v.name, v.lat, v.lon, v.cap
from (values
  ('NG', 'Lagos',         6.524400,    3.379200, false),
  ('NG', 'Abuja',         9.076500,    7.398600, true),
  ('GH', 'Accra',         5.603700,   -0.187000, true),
  ('KE', 'Nairobi',     -1.292100,   36.821900, true),
  ('ZA', 'Johannesburg', -26.204100,  28.047300, false),
  ('SN', 'Dakar',        14.716700,  -17.467700, true),
  ('CI', 'Abidjan',       5.360000,   -4.008300, false),
  ('GB', 'London',       51.507400,   -0.127800, true),
  ('FR', 'Paris',        48.856600,    2.352200, true),
  ('US', 'New York',     40.712800,  -74.006000, false),
  ('US', 'Houston',      29.760400,  -95.369800, false),
  ('CA', 'Toronto',      43.653200,  -79.383200, false),
  ('DE', 'Berlin',       52.520000,   13.405000, true),
  ('AE', 'Dubai',        25.204800,   55.270800, false),
  ('ES', 'Madrid',       40.416800,   -3.703800, true)
) as v(cc, name, lat, lon, cap)
where exists (select 1 from nata.countries c where c.iso_code = v.cc)
on conflict (country_code, name) do nothing;

-- 2. Fake auth users (login impossible, see header) ---------------------------
with t(n, first_name, last_name) as (values
  ( 1, 'Amara',   'Kalu'),     ( 2, 'Daniel',  'Okafor'),
  ( 3, 'Maya',    'Tariq'),    ( 4, 'Chidi',   'Eze'),
  ( 5, 'Ngozi',   'Adeyemi'),  ( 6, 'Kwame',   'Mensah'),
  ( 7, 'Aisha',   'Bello'),    ( 8, 'Tunde',   'Bakare'),
  ( 9, 'Fatou',   'Diop'),     (10, 'Ibrahim', 'Sow'),
  (11, 'Zainab',  'Musa'),     (12, 'Emeka',   'Nwosu'),
  (13, 'Nia',     'Johnson'),  (14, 'Samuel',  'Osei'),
  (15, 'Grace',   'Wanjiru'),  (16, 'Daniel',  'Otieno'),
  (17, 'Lerato',  'Dlamini'),  (18, 'Thabo',   'Mokoena'),
  (19, 'Sarah',   'Mitchell'), (20, 'Yaw',     'Boateng')
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
  '',                                   -- no password -> password login impossible
  now(),
  '{"provider":"seed","providers":["seed"],"seed":true}'::jsonb,
  jsonb_build_object('first_name', first_name, 'last_name', last_name, 'seed', true),
  now(),
  now(),
  '2999-12-31 00:00:00+00'::timestamptz, -- banned: cannot sign in
  '', '', '', ''
from t
on conflict (id) do nothing;

-- 3. Profiles (upsert, in case a trigger already created empty ones) ----------
with t(n, first_name, last_name, gender, rating, delivered) as (values
  ( 1, 'Amara',   'Kalu',     'women', 4.9,  28), ( 2, 'Daniel',  'Okafor',   'men',   5.0,  41),
  ( 3, 'Maya',    'Tariq',    'women', 4.8,  19), ( 4, 'Chidi',   'Eze',      'men',   4.7,  35),
  ( 5, 'Ngozi',   'Adeyemi',  'women', 4.9,  62), ( 6, 'Kwame',   'Mensah',   'men',   4.6,  12),
  ( 7, 'Aisha',   'Bello',    'women', 4.8,  47), ( 8, 'Tunde',   'Bakare',   'men',   4.5,   8),
  ( 9, 'Fatou',   'Diop',     'women', 5.0,  73), (10, 'Ibrahim', 'Sow',      'men',   4.7,  24),
  (11, 'Zainab',  'Musa',     'women', 4.6,  15), (12, 'Emeka',   'Nwosu',    'men',   4.9,  88),
  (13, 'Nia',     'Johnson',  'women', 4.4,   5), (14, 'Samuel',  'Osei',     'men',   4.8,  31),
  (15, 'Grace',   'Wanjiru',  'women', 4.9,  54), (16, 'Daniel',  'Otieno',   'men',   4.3,   9),
  (17, 'Lerato',  'Dlamini',  'women', 4.7,  22), (18, 'Thabo',   'Mokoena',  'men',   4.8,  39),
  (19, 'Sarah',   'Mitchell', 'women', 4.6,  17), (20, 'Yaw',     'Boateng',  'men',   5.0, 101)
)
insert into nata.profiles (
  id, first_name, last_name, avatar_path,
  verification_status, items_delivered_count, avg_rating
)
select
  ('5eed0000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  first_name,
  last_name,
  -- Full URL: the app's getAvatarUrl() passes http(s) URLs through unchanged.
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

-- 4. Trips: 1-3 live trips per traveler on realistic routes -------------------
--    Routes whose cities are missing are skipped by the inner joins below.
with r(idx, dep_cc, dep_city, arr_cc, arr_city, base_price, flight_days) as (values
  ( 1, 'NG', 'Lagos',        'GB', 'London',   30, 1),
  ( 2, 'NG', 'Lagos',        'US', 'New York', 45, 1),
  ( 3, 'NG', 'Abuja',        'GB', 'London',   35, 1),
  ( 4, 'GH', 'Accra',        'GB', 'London',   32, 1),
  ( 5, 'NG', 'Lagos',        'GH', 'Accra',    15, 0),
  ( 6, 'KE', 'Nairobi',      'GB', 'London',   38, 1),
  ( 7, 'ZA', 'Johannesburg', 'GB', 'London',   40, 1),
  ( 8, 'GB', 'London',       'NG', 'Lagos',    28, 1),
  ( 9, 'US', 'New York',     'NG', 'Lagos',    40, 1),
  (10, 'FR', 'Paris',        'SN', 'Dakar',    25, 1),
  (11, 'CA', 'Toronto',      'NG', 'Lagos',    42, 1),
  (12, 'DE', 'Berlin',       'GH', 'Accra',    30, 1),
  (13, 'AE', 'Dubai',        'NG', 'Lagos',    33, 1),
  (14, 'NG', 'Lagos',        'CA', 'Toronto',  44, 1)
),
tr as (
  select n, k
  from generate_series(1, 20) as n,
       lateral generate_series(1, 1 + (n % 3)) as k
),
planned as (
  select
    tr.n,
    tr.k,
    r.*,
    current_date + (2 + ((tr.n * 7 + tr.k * 11) % 40)) as dep_date
  from tr
  join r on r.idx = ((tr.n - 1) + 5 * (tr.k - 1)) % 14 + 1
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

-- Sanity check: what was created ------------------------------------------------
select
  (select count(*) from auth.users   where email like 'seed+%@nata.test') as fake_users,
  (select count(*) from nata.profiles where id::text like '5eed0000-%')    as profiles,
  (select count(*) from nata.trips    where traveler_id::text like '5eed0000-%') as trips;
