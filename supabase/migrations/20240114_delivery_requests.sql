-- Sending a delivery request (the "Delivery Request" screen).
--
-- Works with the existing tables nata.delivery_requests and nata.request_photos.
-- No columns are added to them.
--
-- Run in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql
--
-- Safe to re-run.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Creating a request goes through ONE function, so the request and its
--    photos are saved together or not at all, and the rules live in the
--    database rather than only in the app.
--
--    The caller supplies the new request's id. That makes a retry after a
--    dropped connection harmless: the same id never creates a second request.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.create_delivery_request(
  p_id                uuid,
  p_trip_id           uuid,
  p_item_description  text,
  p_item_weight_kg    numeric,
  p_item_size         text,
  p_recipient_name    text,
  p_recipient_phone   text,
  p_photo_paths       text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid     uuid := auth.uid();
  trip    record;
  path    text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Already created by an earlier attempt of the same request: nothing to do.
  if exists (select 1 from nata.delivery_requests where id = p_id and sender_id = uid) then
    return p_id;
  end if;

  select t.id, t.traveler_id, t.status, t.departure_date, t.max_weight_kg
    into trip
    from nata.trips t
   where t.id = p_trip_id;

  if not found or trip.status <> 'live' or trip.departure_date < current_date then
    raise exception 'nata:trip_unavailable';
  end if;

  if trip.traveler_id = uid then
    raise exception 'nata:own_trip';
  end if;

  if coalesce(btrim(p_item_description), '') = '' then
    raise exception 'nata:item_required';
  end if;
  if coalesce(btrim(p_recipient_name), '') = '' or coalesce(btrim(p_recipient_phone), '') = '' then
    raise exception 'nata:recipient_required';
  end if;
  if p_item_weight_kg is null or p_item_weight_kg <= 0 then
    raise exception 'nata:weight_invalid';
  end if;
  if trip.max_weight_kg is not null and p_item_weight_kg > trip.max_weight_kg then
    raise exception 'nata:weight_too_heavy';
  end if;
  if coalesce(array_length(p_photo_paths, 1), 0) = 0 then
    raise exception 'nata:photo_required';
  end if;

  -- One open request per sender and trip.
  if exists (
    select 1 from nata.delivery_requests r
     where r.trip_id = p_trip_id
       and r.sender_id = uid
       and r.status in ('pending', 'accepted', 'paid', 'handed_off')
  ) then
    raise exception 'nata:duplicate';
  end if;

  insert into nata.delivery_requests (
    id, trip_id, sender_id, item_description, item_weight_kg, item_size,
    recipient_name, recipient_phone, status
  ) values (
    p_id, p_trip_id, uid, btrim(p_item_description), p_item_weight_kg,
    nullif(btrim(coalesce(p_item_size, '')), ''),
    btrim(p_recipient_name), btrim(p_recipient_phone), 'pending'
  );

  foreach path in array p_photo_paths loop
    -- A photo must be in the sender's own folder for this request.
    if path not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
    insert into nata.request_photos (request_id, uploaded_by, photo_path, type)
    values (p_id, uid, path, 'item');
  end loop;

  return p_id;
end;
$$;

revoke all on function public.create_delivery_request(uuid, uuid, text, numeric, text, text, text, text[]) from public;
grant execute on function public.create_delivery_request(uuid, uuid, text, numeric, text, text, text, text[]) to authenticated;

-- No direct inserts: requests are created only through the function above.
alter table nata.delivery_requests enable row level security;
alter table nata.request_photos    enable row level security;

drop policy if exists "Users can create their own delivery requests"
  on nata.delivery_requests;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Who can see a request's photos: its sender and the trip's traveler.
--    (Reading requests themselves: see 20240107 / 20240110.)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function nata.is_request_member(p_request text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rid uuid;
begin
  begin
    rid := p_request::uuid;
  exception when others then
    return false;
  end;

  return exists (
    select 1
      from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.id = rid
       and auth.uid() is not null
       and (r.sender_id = auth.uid() or t.traveler_id = auth.uid())
  );
end;
$$;

revoke all on function nata.is_request_member(text) from public;
grant execute on function nata.is_request_member(text) to authenticated;

drop policy if exists "Participants can read request photos" on nata.request_photos;
create policy "Participants can read request photos"
  on nata.request_photos for select
  to authenticated
  using (nata.is_request_member(request_id::text));

revoke all on nata.request_photos from authenticated;
grant select on nata.request_photos to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Private bucket for the photos.
--    Path convention: {sender_user_id}/{request_id}/{n}.{ext}
--    The sender uploads into their own folder BEFORE the request exists (the
--    request row is created afterwards, together with the photo rows). Both
--    participants can read once the request exists.
-- ─────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('request-photos', 'request-photos', false)
on conflict (id) do update set public = false;

drop policy if exists "Senders upload request photos" on storage.objects;
create policy "Senders upload request photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Retrying a send writes the same file names again (so no orphans pile up).
drop policy if exists "Senders replace their own request photos" on storage.objects;
create policy "Senders replace their own request photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Senders remove their own request photos" on storage.objects;
create policy "Senders remove their own request photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Participants read request photos" on storage.objects;
create policy "Participants read request photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'request-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or nata.is_request_member((storage.foldername(name))[2])
    )
  );
