-- STEP 2 — run this only AFTER 20240115_delivery_requests_v2.sql is live and
-- the new app version (which no longer writes recipient_name / recipient_phone
-- on delivery_requests) is what people are using.
--
-- Until this runs, requests created before the change still carry the
-- recipient's phone number in delivery_requests, readable by the traveler.
-- Their recipient was already copied to nata.request_recipients by your
-- additions script, so nothing is lost.
--
-- Check first (should return 0): requests whose recipient was not copied.
--   select count(*) from nata.delivery_requests d
--   where d.recipient_name is not null
--     and not exists (select 1 from nata.request_recipients r where r.request_id = d.id);

begin;

drop trigger if exists sync_request_recipient on nata.delivery_requests;
drop function if exists nata.sync_request_recipient();

alter table nata.delivery_requests
  drop column if exists recipient_name,
  drop column if exists recipient_phone;

commit;
