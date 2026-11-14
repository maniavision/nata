-- New notifications reach the open app at once.
--
-- Run AFTER 20240213_parcel_market.sql. Safe to re-run.
--
-- Every change to a request writes a notification for the person it
-- concerns. The app (lib/services/live_updates.dart) listens for the
-- signed-in member's new notifications through Supabase Realtime and reloads
-- Requests and My Trips, so a payment or an acceptance shows without leaving
-- the page. Realtime keeps to the table's read policy: members only hear
-- about their own notifications.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'nata'
       and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table nata.notifications;
  end if;
end;
$$;
