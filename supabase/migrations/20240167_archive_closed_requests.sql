-- The Archive also takes cancelled and expired requests.
--
-- Run AFTER 20240166_request_archive.sql. Safe to re-run.
--
-- Like delivered ones (20240166), a cancelled or expired request moves to
-- the Archive 24 hours after it closed, or straight away when swiped left.
--
--   * public.archive_request(): also for cancelled and expired requests.
--   * public.my_closed_requests(): the user's delivered, cancelled and
--     expired requests (sent or carried), with when each closed (delivered,
--     cancelled, or its deadline passed) and whether the user archived it.
--     public.my_delivered_requests() stays for older app builds.

create or replace function public.archive_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (
    select 1
      from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.id = p_request_id
       and r.status in ('delivered', 'cancelled', 'expired')
       and (r.sender_id = uid or t.traveler_id = uid)
  ) then
    raise exception 'nata:request_not_found';
  end if;
  insert into nata.request_archives (user_id, request_id)
  values (uid, p_request_id)
  on conflict (user_id, request_id) do nothing;
end;
$$;

revoke all on function public.archive_request(uuid) from public, anon;
grant execute on function public.archive_request(uuid) to authenticated;

create or replace function public.my_closed_requests()
returns table (
  request_id  uuid,
  status      text,
  closed_at   timestamptz,
  archived    boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id,
         r.status::text,
         case r.status
           when 'delivered' then coalesce(r.delivered_at, r.updated_at)
           when 'cancelled' then coalesce(r.cancelled_at, r.updated_at)
           else coalesce(r.expires_at, r.updated_at)
         end,
         exists (select 1 from nata.request_archives a
                  where a.user_id = auth.uid() and a.request_id = r.id)
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.status in ('delivered', 'cancelled', 'expired')
     and auth.uid() is not null
     and (r.sender_id = auth.uid() or t.traveler_id = auth.uid());
$$;

revoke all on function public.my_closed_requests() from public, anon;
grant execute on function public.my_closed_requests() to authenticated;
