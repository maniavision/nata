-- ============================================================================
-- Test data: three conversations for YOUR account, with a few messages each.
--
-- DEV / STAGING ONLY. Requires seed_test_travelers.sql to have been run first
-- (it needs the fake travelers' live trips) and the messaging migration.
--
-- "You" are the oldest real account in nata.profiles (not a seed user). Each
-- conversation is a delivery request from you to one of the fake travelers.
-- Re-running is safe (fixed ids). Removing the fake travelers removes all of
-- this too (their trips cascade to requests, conversations and messages).
-- ============================================================================

begin;

with me as (
  select id from nata.profiles
  where id::text not like '5eed0000-%'
  order by created_at asc
  limit 1
),
picked as (
  -- three different fake travelers, each with their soonest live trip,
  -- numbered 1..3 (the numbering is done AFTER picking, so it has no gaps)
  select x.trip_id, x.traveler_id, row_number() over (order by x.traveler_id)::int as n
  from (
    select distinct on (t.traveler_id) t.id as trip_id, t.traveler_id
    from nata.trips t
    where t.traveler_id::text like '5eed0000-%' and t.status = 'live'
    order by t.traveler_id, t.departure_date
    limit 3
  ) x
)
insert into nata.delivery_requests (
  id, trip_id, sender_id, item_description, item_weight_kg, item_size,
  recipient_name, recipient_phone, status
)
select
  md5('seed-req-' || p.n)::uuid,
  p.trip_id,
  me.id,
  (array['iPhone 15 Pro (sealed)', 'Sony headphones (retail box)', 'Documents envelope'])[p.n],
  (array[0.5, 0.9, 0.2])[p.n],
  (array['Shoebox (30×20×15 cm)', 'Shoebox (30×20×15 cm)', 'Envelope / Document'])[p.n],
  'Seed Recipient',
  '+10000000000',
  (array['accepted', 'paid', 'delivered'])[p.n]
from picked p, me
on conflict (id) do nothing;

-- The trigger has created the conversations; now the messages.
insert into nata.messages (id, conversation_id, author_id, body, read_at, created_at)
select
  md5('seed-msg-' || r.n || '-' || m.k)::uuid,
  c.id,
  case when m.mine then r.sender_id else r.traveler_id end,
  m.body,
  -- everything is read, except the traveler's last message in the first two
  -- conversations, so the unread badge can be seen
  case when (not m.mine) and m.k = 3 and r.n <= 2 then null
       else now() - interval '1 hour' end,
  now() - (m.minutes_ago || ' minutes')::interval
from (
  select dr.id as request_id, dr.sender_id, t.traveler_id,
         row_number() over (order by dr.id) as n
  from nata.delivery_requests dr
  join nata.trips t on t.id = dr.trip_id
  where dr.id in (md5('seed-req-1')::uuid, md5('seed-req-2')::uuid, md5('seed-req-3')::uuid)
) r
join nata.conversations c on c.request_id = r.request_id
cross join lateral (values
  (1, true,  'Hi! Can you carry this for me on your flight?', 300),
  (2, false, 'Hello! Yes, I have space in my cabin bag.',      240),
  (3, false, 'Meeting you at the arrival gate tomorrow morning.', 20)
) as m(k, mine, body, minutes_ago)
on conflict (id) do nothing;

commit;

select
  (select count(*) from nata.conversations c
     join nata.delivery_requests r on r.id = c.request_id
    where r.id in (md5('seed-req-1')::uuid, md5('seed-req-2')::uuid, md5('seed-req-3')::uuid)) as conversations,
  (select count(*) from nata.messages
    where id in (select md5('seed-msg-' || a || '-' || b)::uuid
                   from generate_series(1,3) a, generate_series(1,3) b)) as messages;
