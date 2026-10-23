-- Archiving delivered requests on the Requests screen.
--
-- Run AFTER 20240165_pawapay_mobile_money.sql. Safe to re-run.
--
-- A delivered request moves to the Archive (of Incoming for the traveler, of
-- Outgoing for the sender) 24 hours after delivery, or straight away when
-- that person swipes it away. Each side archives for themselves.
--
--   * nata.request_archives: who swiped which delivered request away.
--   * public.archive_request(p_request_id): the sender or the traveler
--     archives a delivered request (nata:request_not_found otherwise).
--   * public.my_delivered_requests(): the delivered requests the user sent or
--     carried, with when they were delivered and whether the user archived
--     them; the app puts them in the Archive once archived or 24 hours old.

create table if not exists nata.request_archives (
  user_id      uuid not null references auth.users (id) on delete cascade,
  request_id   uuid not null references nata.delivery_requests (id) on delete cascade,
  archived_at  timestamptz not null default now(),
  primary key (user_id, request_id)
);
alter table nata.request_archives enable row level security;
revoke all on nata.request_archives from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. Archiving one
-- -----------------------------------------------------------------------------
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
       and r.status = 'delivered'
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

-- -----------------------------------------------------------------------------
-- 2. What is delivered, and what was archived
-- -----------------------------------------------------------------------------
create or replace function public.my_delivered_requests()
returns table (
  request_id    uuid,
  delivered_at  timestamptz,
  archived      boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id,
         coalesce(r.delivered_at, r.updated_at),
         exists (select 1 from nata.request_archives a
                  where a.user_id = auth.uid() and a.request_id = r.id)
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.status = 'delivered'
     and auth.uid() is not null
     and (r.sender_id = auth.uid() or t.traveler_id = auth.uid());
$$;

revoke all on function public.my_delivered_requests() from public, anon;
grant execute on function public.my_delivered_requests() to authenticated;
