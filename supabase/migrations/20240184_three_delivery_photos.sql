-- Up to 3 photos at pickup and at handover.
--
-- Run AFTER 20240183_traveler_pseudonym.sql. Safe to re-run.
--
-- The traveler used to attach one photo of the sealed item at pickup and
-- one of the handover. Now up to 3 each, kept in order:
--
--   * delivery_requests.pickup_photo_paths / handover_photo_paths (text[],
--     at most 3), filled from the single paths of 20240144. The single
--     columns stay and hold the first photo, for older app versions.
--   * public.set_delivery_photos(p_request_id, p_kind, p_paths): the
--     traveler sets a step's photos (1 to 3, in the request's folder).
--   * public.set_delivery_photo (one path, older apps) now also sets the
--     list to that one photo.
--   * public.delivery_photos / support_delivery_photos: also return the
--     lists.

alter table nata.delivery_requests
  add column if not exists pickup_photo_paths   text[] not null default '{}',
  add column if not exists handover_photo_paths text[] not null default '{}';

alter table nata.delivery_requests
  drop constraint if exists delivery_requests_photo_paths_check;
alter table nata.delivery_requests
  add constraint delivery_requests_photo_paths_check check (
    cardinality(pickup_photo_paths) <= 3
    and cardinality(handover_photo_paths) <= 3);

update nata.delivery_requests
   set pickup_photo_paths = array[pickup_photo_path]
 where pickup_photo_path is not null and cardinality(pickup_photo_paths) = 0;
update nata.delivery_requests
   set handover_photo_paths = array[handover_photo_path]
 where handover_photo_path is not null
   and cardinality(handover_photo_paths) = 0;

-- -----------------------------------------------------------------------------
-- 1. Setting a step's photos
-- -----------------------------------------------------------------------------
create or replace function public.set_delivery_photos(
  p_request_id uuid,
  p_kind       text,     -- 'pickup' or 'handover'
  p_paths      text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
  p    text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if p_kind not in ('pickup', 'handover')
     or p_paths is null
     or cardinality(p_paths) not between 1 and 3 then
    raise exception 'nata:photo_invalid';
  end if;
  foreach p in array p_paths loop
    if p is null or split_part(p, '/', 1) <> p_request_id::text then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  select r.id, r.status, t.traveler_id into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id
   for update of r;
  if not found or req.traveler_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status not in ('paid', 'handed_off', 'delivered') then
    raise exception 'nata:request_not_paid';
  end if;

  if p_kind = 'pickup' then
    update nata.delivery_requests
       set pickup_photo_paths = p_paths, pickup_photo_path = p_paths[1]
     where id = p_request_id;
  else
    update nata.delivery_requests
       set handover_photo_paths = p_paths, handover_photo_path = p_paths[1]
     where id = p_request_id;
  end if;
end;
$$;

revoke all on function public.set_delivery_photos(uuid, text, text[])
  from public, anon;
grant execute on function public.set_delivery_photos(uuid, text, text[])
  to authenticated;

-- Older apps: one photo, which becomes the step's only photo.
create or replace function public.set_delivery_photo(
  p_request_id uuid,
  p_kind       text,
  p_path       text
)
returns void
language sql
security definer
set search_path = ''
as $$
  select public.set_delivery_photos(p_request_id, p_kind, array[p_path]);
$$;

revoke all on function public.set_delivery_photo(uuid, text, text)
  from public, anon;
grant execute on function public.set_delivery_photo(uuid, text, text)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Seeing them
-- -----------------------------------------------------------------------------
drop function if exists public.delivery_photos(uuid);
create function public.delivery_photos(p_request_id uuid)
returns table (
  pickup_photo_path    text,
  handover_photo_path  text,
  pickup_photo_paths   text[],
  handover_photo_paths text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.pickup_photo_path, r.handover_photo_path,
         r.pickup_photo_paths, r.handover_photo_paths
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id
     and auth.uid() in (r.sender_id, t.traveler_id);
$$;

revoke all on function public.delivery_photos(uuid) from public, anon;
grant execute on function public.delivery_photos(uuid) to authenticated;

drop function if exists public.support_delivery_photos(uuid);
create function public.support_delivery_photos(p_request uuid)
returns table (
  pickup_photo_path    text,
  handover_photo_path  text,
  pickup_photo_paths   text[],
  handover_photo_paths text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select r.pickup_photo_path, r.handover_photo_path,
           r.pickup_photo_paths, r.handover_photo_paths
      from nata.delivery_requests r where r.id = p_request;
end;
$$;
revoke all on function public.support_delivery_photos(uuid) from public, anon;
grant execute on function public.support_delivery_photos(uuid) to authenticated;
