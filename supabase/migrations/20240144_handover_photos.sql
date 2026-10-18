-- Photos at pickup and at handover.
--
-- Run AFTER 20240143_disputes.sql. Safe to re-run.
--
--   * Private bucket `handover-photos`, one folder per request:
--     {request_id}/pickup.jpg (the sealed item, taken by the traveler when
--     they collect it) and {request_id}/handover.jpg (with the recipient).
--     The request's traveler uploads them; its sender and traveler can see
--     them.
--   * delivery_requests.pickup_photo_path / handover_photo_path, set with
--     public.set_delivery_photo(p_request_id, p_kind, p_path) by the traveler.
--   * public.delivery_photos(p_request_id): both paths, for the request's
--     sender or traveler.

alter table nata.delivery_requests
  add column if not exists pickup_photo_path   text,
  add column if not exists handover_photo_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('handover-photos', 'handover-photos', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

-- Whether the signed-in user is the traveler (or, with p_or_sender, the
-- sender) of the request a photo's folder belongs to.
create or replace function nata.can_use_delivery_photo(
  p_name text,
  p_or_sender boolean
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.id::text = split_part(p_name, '/', 1)
       and (t.traveler_id = auth.uid()
            or (p_or_sender and r.sender_id = auth.uid()))
  );
$$;

drop policy if exists "Travelers upload delivery photos" on storage.objects;
create policy "Travelers upload delivery photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'handover-photos'
    and nata.can_use_delivery_photo(name, false)
  );

drop policy if exists "Travelers replace delivery photos" on storage.objects;
create policy "Travelers replace delivery photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'handover-photos'
    and nata.can_use_delivery_photo(name, false)
  );

drop policy if exists "Senders and travelers see delivery photos" on storage.objects;
create policy "Senders and travelers see delivery photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'handover-photos'
    and nata.can_use_delivery_photo(name, true)
  );

drop function if exists public.set_delivery_photo(uuid, text, text);
create function public.set_delivery_photo(
  p_request_id uuid,
  p_kind       text,   -- 'pickup' or 'handover'
  p_path       text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if p_kind not in ('pickup', 'handover')
     or p_path is null
     or split_part(p_path, '/', 1) <> p_request_id::text then
    raise exception 'nata:photo_invalid';
  end if;

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
    update nata.delivery_requests set pickup_photo_path = p_path
     where id = p_request_id;
  else
    update nata.delivery_requests set handover_photo_path = p_path
     where id = p_request_id;
  end if;
end;
$$;

revoke all on function public.set_delivery_photo(uuid, text, text) from public, anon;
grant execute on function public.set_delivery_photo(uuid, text, text) to authenticated;

drop function if exists public.delivery_photos(uuid);
create function public.delivery_photos(p_request_id uuid)
returns table (pickup_photo_path text, handover_photo_path text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.pickup_photo_path, r.handover_photo_path
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id
     and auth.uid() in (r.sender_id, t.traveler_id);
$$;

revoke all on function public.delivery_photos(uuid) from public, anon;
grant execute on function public.delivery_photos(uuid) to authenticated;
