-- ============================================================================
-- Removes seed_demo_screenshots.sql's data. Amara's account (+1 202 555 0101)
-- stays, verified and with nothing in it, for App Review.
-- ============================================================================

begin;

do $$
declare
  amara uuid;
  reqs  uuid[];
begin
  select id into amara from auth.users where phone = '12025550101';

  select array_agg(r.id) into reqs
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id in (select md5('demo-req-' || g)::uuid from generate_series(1, 7) g)
      or r.sender_id = amara or t.traveler_id = amara
      or t.id in (select md5('demo-trip-' || g)::uuid from generate_series(1, 8) g);

  delete from nata.payouts
   where payment_id in (select id from nata.payments where request_id = any(reqs))
      or traveler_id = amara;
  delete from nata.payments where request_id = any(reqs) or sender_id = amara;
  delete from nata.reviews where request_id = any(reqs);
  -- Reports and blocks from trying the chat (20240190), and the staff
  -- notifications about those reports.
  delete from nata.notifications n
   where n.payload ->> 'event' = 'chat_reported'
     and n.related_id in (select id from nata.conversations
                           where request_id = any(reqs));
  delete from nata.chat_reports
   where reporter_id = amara or reported_id = amara
      or conversation_id in (select id from nata.conversations
                              where request_id = any(reqs));
  delete from nata.user_blocks
   where blocker_id = amara or blocked_id = amara;
  delete from nata.messages
   where conversation_id in (select id from nata.conversations where request_id = any(reqs));
  delete from nata.conversations where request_id = any(reqs);
  delete from nata.request_items where request_id = any(reqs);
  delete from nata.delivery_requests where id = any(reqs);
  delete from nata.trips
   where id in (select md5('demo-trip-' || g)::uuid from generate_series(1, 8) g)
      or traveler_id = amara;
  delete from nata.route_alerts where user_id = amara;
  delete from nata.notifications where user_id = amara;

  update nata.profiles
     set items_delivered_count = 0, avg_rating = null, sender_avg_rating = null
   where id = amara;

  -- The demo people (their profiles go with them).
  delete from auth.users
   where email like 'demo+%@nata.test'
     and raw_app_meta_data ->> 'provider' = 'demo';
end $$;

commit;

select
  (select count(*) from auth.users where email like 'demo+%@nata.test') as demo_people_left,
  (select count(*) from nata.trips where id in (select md5('demo-trip-' || g)::uuid from generate_series(1, 8) g)) as trips_left;
