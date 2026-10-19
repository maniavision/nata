-- A delivered request frees its place on the trip.
--
-- Run AFTER 20240156 (account deletion). Safe to re-run.
--
-- A traveler can carry at most 3 requests at a time on each trip, each from a
-- different sender (20240153). Until now accepted, paid, picked-up and
-- delivered requests all counted, so a trip was full for good after 3
-- deliveries. Now only the ones still in progress count (accepted, paid,
-- picked up): once a request is delivered, the traveler can take another
-- one, from a new sender or the same one again.
--
-- nata.trip_sender_count is used by the request triggers and by the search
-- (full trips leave it), so both follow.

create or replace function nata.trip_sender_count(p_trip uuid, p_except uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(distinct r.sender_id)::integer
    from nata.delivery_requests r
   where r.trip_id = p_trip
     and r.id <> coalesce(p_except, '00000000-0000-0000-0000-000000000000')
     and r.status in ('accepted', 'paid', 'handed_off');
$$;

revoke all on function nata.trip_sender_count(uuid, uuid) from public, anon, authenticated;

create or replace function nata.requests_check_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform nata.require_verified(new.sender_id);
    -- Lock the trip so two requests can't both take its last place.
    perform 1 from nata.trips t where t.id = new.trip_id for update;
    if nata.trip_sender_count(new.trip_id, new.id) >= 3 then
      raise exception 'nata:trip_full';
    end if;
    return new;
  end if;

  -- Accepting.
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    perform 1 from nata.trips t where t.id = new.trip_id for update;
    if exists (select 1 from nata.delivery_requests r
                where r.trip_id = new.trip_id
                  and r.id <> new.id
                  and r.sender_id = new.sender_id
                  and r.status in ('accepted', 'paid', 'handed_off')) then
      raise exception 'nata:sender_on_trip';
    end if;
    if nata.trip_sender_count(new.trip_id, new.id) >= 3 then
      raise exception 'nata:trip_full';
    end if;
  end if;
  return new;
end;
$$;
