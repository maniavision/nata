-- New trips go live at once; senders can open the ticket after acceptance.
--
-- Run AFTER 20240162_trips_access.sql. Safe to re-run.
--
--   * No review for now: a trip a traveler adds is published straight away
--     (status 'live'), so it shows in search and route alerts go out. App
--     versions that still send 'pending_review' are published too. The
--     traveler still can't change the status afterwards except to cancel
--     (trips_guard_status).
--   * "Could not load the ticket": the storage rule for the ticket's blurred
--     copy looked the trip up under the sender's own access rules, and a
--     sender cannot read someone else's trip, so the copy was never found.
--     The check now runs in nata.can_read_shared_ticket, which sees the trip
--     and the request whatever the caller can read; the conditions are the
--     same (the sender of a request the traveler accepted).

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Trips are published when they are added
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "Travelers can create their own trips" on nata.trips;
create policy "Travelers can create their own trips"
  on nata.trips for insert
  to authenticated
  with check (
    auth.uid() = traveler_id
    and status in ('pending_review', 'live')
  );

create or replace function nata.trips_publish_now()
returns trigger
language plpgsql
as $$
begin
  if coalesce(auth.role(), '') = 'authenticated'
     and new.status = 'pending_review' then
    new.status := 'live';
  end if;
  return new;
end;
$$;

drop trigger if exists trips_publish_now on nata.trips;
create trigger trips_publish_now
  before insert on nata.trips
  for each row execute function nata.trips_publish_now();

-- Members' trips still waiting for a review (seed trips stay as they are).
update nata.trips
   set status = 'live'
 where status = 'pending_review'
   and coalesce(ticket_receipt_path, '') not like 'seed/%';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Senders open the ticket's blurred copy once the traveler accepted
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function nata.can_read_shared_ticket(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from nata.trips t
      join nata.delivery_requests r on r.trip_id = t.id
     where t.ticket_shared_path = p_name
       and (storage.foldername(p_name))[1] = t.traveler_id::text
       and r.sender_id = auth.uid()
       and r.status in ('accepted', 'paid', 'handed_off', 'delivered')
  );
$$;

revoke all on function nata.can_read_shared_ticket(text) from public, anon;
grant execute on function nata.can_read_shared_ticket(text) to authenticated;

drop policy if exists "Senders read the ticket of a trip they are paying for"
  on storage.objects;
create policy "Senders read the ticket of a trip they are paying for"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'trip-receipts'
    and nata.can_read_shared_ticket(name)
  );
