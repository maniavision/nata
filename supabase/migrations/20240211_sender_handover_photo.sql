-- The sender's side of the handover to the traveler.
--
-- Run AFTER 20240210_stuck_id_reviews.sql. Safe to re-run.
--
-- Until now only the traveler took photos at pickup (of the item). The
-- sender now gets a "Hand over your item" screen while the request is paid
-- or picked up:
--
--   * They see the traveler's verified face (the selfie from the traveler's
--     ID check) to check the right person came for the item.
--     public.handover_traveler_face(p_request_id) gives its path, and a
--     storage policy lets the request's sender read that one file, only
--     while the delivery is under way (paid or picked up).
--   * They can take a photo of the traveler with the item (optional).
--     It goes in the request's folder of `handover-photos` as
--     {request_id}/sender-<time>.jpg, and is saved with
--     public.set_sender_handover_photo(p_request_id, p_path) in
--     delivery_requests.sender_handover_photo_path.
--   * public.delivery_photos and public.support_delivery_photos also
--     return it.

alter table nata.delivery_requests
  add column if not exists sender_handover_photo_path text;

-- -----------------------------------------------------------------------------
-- 1. The traveler's verified face
-- -----------------------------------------------------------------------------

-- Whether the signed-in member is the sender of a delivery under way on the
-- trip of the traveler whose ID folder p_name is in.
create or replace function nata.can_see_handover_face(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select split_part(p_name, '/', 2) = 'selfie.jpg'
     and exists (
       select 1
         from nata.delivery_requests r
         join nata.trips t on t.id = r.trip_id
        where t.traveler_id::text = split_part(p_name, '/', 1)
          and r.sender_id = auth.uid()
          and r.status in ('paid', 'handed_off'));
$$;
revoke all on function nata.can_see_handover_face(text) from public, anon;
grant execute on function nata.can_see_handover_face(text) to authenticated;

drop policy if exists "Senders see their traveler's face at handover" on storage.objects;
create policy "Senders see their traveler's face at handover"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'identity-documents'
    and nata.can_see_handover_face(name)
  );

-- The traveler's selfie path (null when they have none, e.g. verified
-- before face scans) and whether they're verified, for the request's sender
-- while the delivery is under way.
drop function if exists public.handover_traveler_face(uuid);
create function public.handover_traveler_face(p_request_id uuid)
returns table (selfie_path text, verified boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select case when nata.selfie_uploaded_at(t.traveler_id) is not null
              then t.traveler_id::text || '/selfie.jpg' end,
         p.verification_status = 'verified'
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
    join nata.profiles p on p.id = t.traveler_id
   where r.id = p_request_id
     and r.sender_id = auth.uid()
     and r.status in ('paid', 'handed_off');
$$;
revoke all on function public.handover_traveler_face(uuid) from public, anon;
grant execute on function public.handover_traveler_face(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. The sender's photo of the traveler with the item
-- -----------------------------------------------------------------------------

create or replace function nata.can_add_sender_photo(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select split_part(p_name, '/', 2) like 'sender-%'
     and exists (
       select 1
         from nata.delivery_requests r
        where r.id::text = split_part(p_name, '/', 1)
          and r.sender_id = auth.uid()
          and r.status in ('paid', 'handed_off'));
$$;
revoke all on function nata.can_add_sender_photo(text) from public, anon;
grant execute on function nata.can_add_sender_photo(text) to authenticated;

-- Senders already see the request's photos ("Senders and travelers see
-- delivery photos", 20240144); this lets them add their own.
drop policy if exists "Senders upload their handover photo" on storage.objects;
create policy "Senders upload their handover photo"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'handover-photos'
    and nata.can_add_sender_photo(name)
  );

drop function if exists public.set_sender_handover_photo(uuid, text);
create function public.set_sender_handover_photo(
  p_request_id uuid,
  p_path       text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  req record;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if p_path is null
     or split_part(p_path, '/', 1) <> p_request_id::text
     or split_part(p_path, '/', 2) not like 'sender-%' then
    raise exception 'nata:photo_invalid';
  end if;

  select r.id, r.status, r.sender_id into req
    from nata.delivery_requests r
   where r.id = p_request_id
   for update;
  if not found or req.sender_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status not in ('paid', 'handed_off') then
    raise exception 'nata:request_not_paid';
  end if;

  update nata.delivery_requests set sender_handover_photo_path = p_path
   where id = p_request_id;
end;
$$;
revoke all on function public.set_sender_handover_photo(uuid, text) from public, anon;
grant execute on function public.set_sender_handover_photo(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Seeing it (the members, and Support)
-- -----------------------------------------------------------------------------
drop function if exists public.delivery_photos(uuid);
create function public.delivery_photos(p_request_id uuid)
returns table (
  pickup_photo_path          text,
  handover_photo_path        text,
  pickup_photo_paths         text[],
  handover_photo_paths       text[],
  sender_handover_photo_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.pickup_photo_path, r.handover_photo_path,
         r.pickup_photo_paths, r.handover_photo_paths,
         r.sender_handover_photo_path
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
  pickup_photo_path          text,
  handover_photo_path        text,
  pickup_photo_paths         text[],
  handover_photo_paths       text[],
  sender_handover_photo_path text
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
           r.pickup_photo_paths, r.handover_photo_paths,
           r.sender_handover_photo_path
      from nata.delivery_requests r where r.id = p_request;
end;
$$;
revoke all on function public.support_delivery_photos(uuid) from public, anon;
grant execute on function public.support_delivery_photos(uuid) to authenticated;
