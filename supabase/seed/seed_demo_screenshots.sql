-- ============================================================================
-- Demo data for the App Store screenshots: Amara Mensah's account
-- (+1 202 555 0101, see demo_accounts.md) and made-up people around her.
--
-- Run AFTER Amara has signed up in the app (her auth user must exist).
-- Remove it with remove_demo_screenshots.sql (Amara's account is kept).
--
--   * Demo people: ids de300000-0000-4000-8000-0000000000NN, emails
--     demo+N@nata.test, provider 'demo'. They can't sign in (no password,
--     banned until 2999).
--   * Route alerts aren't sent for the demo trips: notify_route_alerts is
--     turned off while they're added (members watching New York → Accra
--     would otherwise be told about travelers who don't exist).
--   * No SMS: requests are added with their final status, and the recipient
--     messages are only sent when a status changes.
-- ============================================================================

begin;

alter table nata.trips disable trigger notify_route_alerts;

do $$
declare
  amara uuid;
  d     text := 'de300000-0000-4000-8000-';
  kwame uuid := (d || '000000000002')::uuid;
  lea   uuid := (d || '000000000003')::uuid;
  david uuid := (d || '000000000004')::uuid;
  grace uuid := (d || '000000000005')::uuid;
  kofi  uuid := (d || '000000000006')::uuid;
  nadia uuid := (d || '000000000007')::uuid;
  nyc   int; accra int; london int; lagos int; paris int; dakar int;
begin
  select id into amara from auth.users where phone = '12025550101';
  if amara is null then
    raise exception 'Sign up as Amara (+1 202 555 0101) in the app first';
  end if;

  select id into nyc    from nata.cities where country_code = 'US' and name = 'New York';
  select id into accra  from nata.cities where country_code = 'GH' and name = 'Accra';
  select id into london from nata.cities where country_code = 'GB' and name = 'London';
  select id into lagos  from nata.cities where country_code = 'NG' and name = 'Lagos';
  select id into paris  from nata.cities where country_code = 'FR' and name = 'Paris';
  select id into dakar  from nata.cities where country_code = 'SN' and name = 'Dakar';
  if nyc is null or accra is null or london is null or lagos is null
     or paris is null or dakar is null then
    raise exception 'A demo city is missing from nata.cities';
  end if;

  -- People ------------------------------------------------------------------
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, banned_until,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  select '00000000-0000-0000-0000-000000000000'::uuid, (d || lpad(n::text, 12, '0'))::uuid,
         'authenticated', 'authenticated', 'demo+' || n || '@nata.test', '', now(),
         '{"provider":"demo","providers":["demo"],"demo":true}'::jsonb,
         jsonb_build_object('first_name', f, 'last_name', l, 'demo', true),
         now() - interval '200 days', now(), '2999-12-31 00:00:00+00'::timestamptz,
         '', '', '', ''
    from (values (2, 'Kwame', 'Boateng'), (3, 'Léa', 'Martin'),
                 (4, 'David', 'Okafor'), (5, 'Grace', 'Mbemba'),
                 (6, 'Kofi', 'Asante'),  (7, 'Nadia', 'Diallo')) v(n, f, l)
  on conflict (id) do nothing;

  insert into nata.profiles (id, first_name, last_name, avatar_path, verification_status,
                             items_delivered_count, avg_rating, sender_avg_rating,
                             country_of_residence)
  values
    (amara, 'Amara', 'Mensah', 'https://randomuser.me/api/portraits/women/44.jpg', 'verified', 14, 4.9, 5.0, 'US'),
    (kwame, 'Kwame', 'Boateng', 'https://randomuser.me/api/portraits/men/32.jpg',   'verified', 37, 4.9, null, 'US'),
    (lea,   'Léa',   'Martin',  'https://randomuser.me/api/portraits/women/68.jpg', 'verified', 22, 5.0, null, 'FR'),
    (david, 'David', 'Okafor',  'https://randomuser.me/api/portraits/men/75.jpg',   'verified', 18, 4.8, 4.9, 'GB'),
    (grace, 'Grace', 'Mbemba',  'https://randomuser.me/api/portraits/women/90.jpg', 'verified', 0,  null, 5.0, 'US'),
    (kofi,  'Kofi',  'Asante',  'https://randomuser.me/api/portraits/men/52.jpg',   'verified', 9,  4.7, null, 'US'),
    (nadia, 'Nadia', 'Diallo',  'https://randomuser.me/api/portraits/women/26.jpg', 'verified', 26, 4.9, null, 'US')
  on conflict (id) do update set
    first_name = excluded.first_name, last_name = excluded.last_name,
    avatar_path = excluded.avatar_path, verification_status = excluded.verification_status,
    items_delivered_count = excluded.items_delivered_count, avg_rating = excluded.avg_rating,
    sender_avg_rating = excluded.sender_avg_rating,
    country_of_residence = excluded.country_of_residence;

  update auth.users
     set raw_user_meta_data = raw_user_meta_data
           || '{"first_name":"Amara","last_name":"Mensah"}'::jsonb
   where id = amara;

  -- Trips -------------------------------------------------------------------
  insert into nata.trips (id, traveler_id, departure_city_id, departure_date,
                          arrival_city_id, arrival_date, price, currency,
                          max_weight_kg, max_size, ticket_receipt_path,
                          booking_reference, status)
  values
    (md5('demo-trip-1')::uuid, kwame, nyc, date '2026-11-06', accra, date '2026-11-07', 25, 'USD', 10, 'Backpack size',          'demo/ticket_placeholder.pdf', 'DEMO01', 'live'),
    (md5('demo-trip-2')::uuid, kofi,  nyc, date '2026-11-09', accra, date '2026-11-10', 22, 'USD', 5,  'Shoebox (30×20×15 cm)',  'demo/ticket_placeholder.pdf', 'DEMO02', 'live'),
    (md5('demo-trip-3')::uuid, nadia, nyc, date '2026-11-14', accra, date '2026-11-15', 30, 'USD', 8,  'Backpack size',          'demo/ticket_placeholder.pdf', 'DEMO03', 'live'),
    (md5('demo-trip-4')::uuid, david, london, date '2026-11-02', lagos, date '2026-11-02', 28, 'USD', 6, 'Backpack size',         'demo/ticket_placeholder.pdf', 'DEMO04', 'live'),
    (md5('demo-trip-5')::uuid, lea,   paris, date '2026-10-14', dakar, date '2026-10-14', 20, 'USD', 3,  'Envelope / Document',   'demo/ticket_placeholder.pdf', 'DEMO05', 'completed'),
    (md5('demo-trip-6')::uuid, lea,   paris, date '2026-11-09', dakar, date '2026-11-09', 20, 'USD', 3,  'Shoebox (30×20×15 cm)', 'demo/ticket_placeholder.pdf', 'DEMO06', 'live'),
    (md5('demo-trip-7')::uuid, amara, nyc, date '2026-11-12', lagos, date '2026-11-13', 30, 'USD', 7,  'Backpack size',          'demo/ticket_placeholder.pdf', 'DEMO07', 'live'),
    (md5('demo-trip-8')::uuid, amara, nyc, date '2026-09-20', accra, date '2026-09-21', 30, 'USD', 7,  'Backpack size',          'demo/ticket_placeholder.pdf', 'DEMO08', 'completed')
  on conflict (id) do nothing;

  -- Requests (added with their final status) ----------------------------------
  insert into nata.delivery_requests (
    id, trip_id, sender_id, item_name, item_category, item_description,
    item_weight_kg, item_size, item_size_class, recipient_name, recipient_phone,
    status, traveler_price, platform_fee, total_amount, currency,
    display_currency, exchange_rate, display_cost, display_fee, display_total,
    declared_value, declared_currency, price_fixed_at, responded_at, paid_at,
    picked_up_at, delivered_at, created_at)
  select md5('demo-req-' || n)::uuid, md5('demo-trip-' || t)::uuid, s, item, cat, '',
         kg, size, cls, rname, '+12025550199',
         st, price, fee, price + fee, 'USD', 'USD', 1, price, fee, price + fee,
         val, 'USD',
         case when st <> 'pending' then now() - (h || ' hours')::interval end,
         case when st <> 'pending' then now() - (h || ' hours')::interval end,
         case when st in ('paid', 'handed_off', 'delivered')
              then now() - ((h - 1) || ' hours')::interval end,
         case when st in ('handed_off', 'delivered')
              then now() - ((h - 20) || ' hours')::interval end,
         case when st = 'delivered' then now() - ((h - 40) || ' hours')::interval end,
         now() - ((h + 2) || ' hours')::interval
    from (values
      -- n, trip, sender, item, category, kg, size, size class, recipient, status, price, fee, value, hours ago
      (1, 1, amara, 'MacBook Air (sealed)',      'electronics', 1.3, 'Shoebox (30×20×15 cm)', 'shoebox',  'Yaw Mensah',   'paid',       45, 4.50, 999, 26),
      (2, 4, amara, 'Ankara wedding fabric',     'apparel',     2.0, 'Backpack size',         'backpack', 'Ngozi Eze',    'handed_off', 38, 3.80, 250, 30),
      (3, 5, amara, 'Visa documents',            'documents',   0.3, 'Envelope / Document',   'envelope', 'Awa Ndiaye',   'delivered',  20, 2.00, 0,   400),
      (4, 2, amara, 'Kids'' clothes',            'apparel',     1.5, 'Shoebox (30×20×15 cm)', 'shoebox',  'Yaw Mensah',   'pending',    24, 2.40, 120, 3),
      (5, 7, grace, 'Phone for my mother',       'electronics', 0.4, 'Shoebox (30×20×15 cm)', 'shoebox',  'Mireille Mbemba', 'paid',    30, 3.00, 600, 6),
      (6, 7, david, 'Birth certificate copies',  'documents',   0.2, 'Envelope / Document',   'envelope', 'Chika Okafor', 'pending',    15, 1.50, 0,   2),
      (7, 8, grace, 'Laptop charger and books',  'electronics', 2.0, 'Backpack size',         'backpack', 'Mireille Mbemba', 'delivered', 42, 4.20, 180, 900)
    ) v(n, t, s, item, cat, kg, size, cls, rname, st, price, fee, val, h)
  on conflict (id) do nothing;

  insert into nata.request_items (request_id, position, name, category)
  select id, 1, item_name, item_category
    from nata.delivery_requests
   where id in (select md5('demo-req-' || g)::uuid from generate_series(1, 7) g)
  on conflict do nothing;

  -- Payments: held for the paid and picked-up ones, released when delivered.
  insert into nata.payments (request_id, sender_id, amount, service_fee, currency,
                             method, provider, tx_ref, status, completed_at,
                             base_amount, base_currency)
  select r.id, r.sender_id, r.total_amount, r.platform_fee, 'USD', 'card', 'stripe',
         'demo_' || r.id, case when r.status = 'delivered' then 'released' else 'held' end,
         r.paid_at, r.total_amount, 'USD'
    from nata.delivery_requests r
   where r.id in (select md5('demo-req-' || g)::uuid from generate_series(1, 7) g)
     and r.status in ('paid', 'handed_off', 'delivered')
     and not exists (select 1 from nata.payments p where p.request_id = r.id);

  -- Payouts: Léa's was paid; Amara's is waiting in her Nata balance.
  insert into nata.payouts (payment_id, traveler_id, amount, currency, status, kind, paid_at, created_at)
  select p.id, t.traveler_id, r.traveler_price, 'USD',
         case when t.traveler_id = amara then 'pending' else 'paid' end, 'earning',
         case when t.traveler_id = amara then null else r.delivered_at end, r.delivered_at
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
    join nata.payments p on p.request_id = r.id
   where r.id in (md5('demo-req-3')::uuid, md5('demo-req-7')::uuid)
  on conflict (payment_id) do nothing;

  -- Reviews ------------------------------------------------------------------
  insert into nata.reviews (request_id, reviewer_id, reviewee_id, rating, comment, reviewee_role, created_at)
  values
    (md5('demo-req-3')::uuid, amara, lea,   5, 'Super quick and kept me updated the whole way. Thank you Léa!', 'traveler', now() - interval '13 days'),
    (md5('demo-req-7')::uuid, grace, amara, 5, 'Amara was lovely and my mother got everything the day after.',   'traveler', now() - interval '36 days'),
    (md5('demo-req-7')::uuid, amara, grace, 5, 'Well packed and right on time for the handover.',               'sender',   now() - interval '36 days')
  on conflict do nothing;

  -- Chats --------------------------------------------------------------------
  insert into nata.conversations (request_id)
  select md5('demo-req-' || g)::uuid from unnest(array[1, 2, 5]) g
  on conflict (request_id) do nothing;

  insert into nata.messages (conversation_id, author_id, body, read_at, created_at)
  select c.id, m.author, m.body,
         case when m.unread then null else now() - interval '10 minutes' end,
         now() - (m.minutes_ago || ' minutes')::interval
    from (values
      (1, amara, 'Hi Kwame! The laptop is packed in its original box.', false, 1500),
      (1, kwame, 'Great, thanks! Can we meet at Penn Station on Tuesday around 6pm?', false, 1460),
      (1, amara, 'Perfect, see you there.', false, 1440),
      (1, kwame, 'I''ll message you when I land in Accra so Yaw can meet me at the airport.', true, 25),
      (2, david, 'Got it, packed safely. Flying out tomorrow morning.', false, 600),
      (2, amara, 'Thank you David! Ngozi will be waiting at arrivals.', false, 590),
      (5, grace, 'Hello Amara, thank you for accepting! The phone is for my mother in Lagos.', false, 300),
      (5, amara, 'Happy to help! Is it still sealed?', false, 280),
      (5, grace, 'Yes, sealed in the box. I can drop it off in Brooklyn on Saturday.', true, 45)
    ) m(req, author, body, unread, minutes_ago)
    join nata.conversations c on c.request_id = md5('demo-req-' || m.req)::uuid
   where not exists (select 1 from nata.messages x
                      where x.conversation_id = c.id and x.body = m.body);
end $$;

alter table nata.trips enable trigger notify_route_alerts;

commit;

select
  (select count(*) from auth.users where email like 'demo+%@nata.test') as demo_people,
  (select count(*) from nata.trips where id in (select md5('demo-trip-' || g)::uuid from generate_series(1, 8) g)) as trips,
  (select count(*) from nata.delivery_requests where id in (select md5('demo-req-' || g)::uuid from generate_series(1, 7) g)) as requests,
  (select count(*) from nata.messages m join nata.conversations c on c.id = m.conversation_id
    where c.request_id in (select md5('demo-req-' || g)::uuid from generate_series(1, 7) g)) as messages;
