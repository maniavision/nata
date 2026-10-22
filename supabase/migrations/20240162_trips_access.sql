-- Travelers can save, see and edit their own trips again.
--
-- Run AFTER 20240161_profiles_on_confirmation.sql. Safe to re-run.
--
-- The live database never received the trip access rules from 20240107 and
-- 20240110: nata.trips had row-level security on but no policy, and the
-- private 'trip-receipts' bucket did not exist. So every "Add a trip" failed
-- (first on the receipt upload, then on the insert) with "Could not save your
-- trip", My trips stayed empty and the profile counted 0 trips and 0 parcels.
--
-- This puts them back, unchanged:
--   * a traveler reads, creates (in review only) and edits their own trips;
--     a trigger lets them set no status but 'cancelled';
--   * a traveler sees the requests made on their trips; a sender sees their
--     own requests;
--   * the private 'trip-receipts' bucket, each traveler in their own folder.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Trips
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "Users can view their own trips" on nata.trips;
create policy "Users can view their own trips"
  on nata.trips for select
  to authenticated
  using (auth.uid() = traveler_id);

drop policy if exists "Travelers can create their own trips" on nata.trips;
create policy "Travelers can create their own trips"
  on nata.trips for insert
  to authenticated
  with check (
    auth.uid() = traveler_id
    -- New trips always start in review; only Nata can make them 'live'.
    and status = 'pending_review'
  );

drop policy if exists "Travelers can update their own trips" on nata.trips;
create policy "Travelers can update their own trips"
  on nata.trips for update
  to authenticated
  using (auth.uid() = traveler_id)
  with check (auth.uid() = traveler_id);

-- Row-level security cannot compare old and new values, so a trigger stops a
-- signed-in traveler from publishing their own trip (pending_review -> live) or
-- reopening a finished one. The only status a traveler may set is 'cancelled'.
create or replace function nata.trips_guard_status()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status
     and coalesce(auth.role(), '') = 'authenticated'
     and new.status <> 'cancelled' then
    raise exception 'Trip status can only be changed by Nata review';
  end if;
  return new;
end;
$$;

drop trigger if exists trips_guard_status on nata.trips;
create trigger trips_guard_status
  before update on nata.trips
  for each row execute function nata.trips_guard_status();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Requests: the sender's own, and those made on the traveler's trips
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "Users can view their own delivery requests"
  on nata.delivery_requests;
create policy "Users can view their own delivery requests"
  on nata.delivery_requests for select
  to authenticated
  using (auth.uid() = sender_id);

drop policy if exists "Travelers can view requests on their trips"
  on nata.delivery_requests;
create policy "Travelers can view requests on their trips"
  on nata.delivery_requests for select
  to authenticated
  using (
    exists (
      select 1 from nata.trips t
      where t.id = delivery_requests.trip_id
        and t.traveler_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Private bucket for flight receipts (path: {user_id}/{timestamp}.{ext})
-- ─────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('trip-receipts', 'trip-receipts', false)
on conflict (id) do update set public = false;

drop policy if exists "Travelers read their own receipts" on storage.objects;
create policy "Travelers read their own receipts"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'trip-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Travelers upload their own receipts" on storage.objects;
create policy "Travelers upload their own receipts"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'trip-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Travelers update their own receipts" on storage.objects;
create policy "Travelers update their own receipts"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'trip-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'trip-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Travelers delete their own receipts" on storage.objects;
create policy "Travelers delete their own receipts"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'trip-receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
