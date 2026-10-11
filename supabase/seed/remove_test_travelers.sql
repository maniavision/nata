-- Removes everything created by seed_test_travelers.sql.
-- Deleting the auth users cascades to nata.profiles -> nata.trips ->
-- nata.delivery_requests. Cities are left in place (they are reference data).
--
-- Only touches accounts whose email is seed+N@nata.test AND that were
-- created by the seed (provider = 'seed'), so real users are never affected.

delete from auth.users
where email like 'seed+%@nata.test'
  and raw_app_meta_data ->> 'provider' = 'seed';
