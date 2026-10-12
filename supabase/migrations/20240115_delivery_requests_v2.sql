-- Delivery requests v2: uses the columns added by your "recommended additions"
-- migration (frozen price, expiry, item_name / item_category, size class,
-- request_recipients).
--
-- Run AFTER your additions script and AFTER 20240114_delivery_requests.sql.
-- Safe to re-run.
--
-- What changes
--   * public.create_delivery_request now
--       - computes the price itself from the trip (the app cannot set it) and
--         freezes it on the request; if the price changed since the sender
--         looked at it, it refuses with nata:price_changed
--       - stores item_name / item_category / item_size_class
--       - checks the item's size class against the trip's max size
--       - writes the recipient to nata.request_recipients ONLY (the traveler
--         can read it only after accepting)
--       - sets expires_at (traveler has 48 hours to respond)
--   * recipient_name / recipient_phone stop being required, so new requests no
--     longer write them. Existing rows keep their values until you run
--     20240116_drop_recipient_columns.sql.
--   * list_conversations shows item_name (item_description is now just notes).

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. New requests no longer fill the old recipient columns
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'nata' and table_name = 'delivery_requests'
                and column_name = 'recipient_name') then
    alter table nata.delivery_requests
      alter column recipient_name  drop not null,
      alter column recipient_phone drop not null;
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Helpers
-- ─────────────────────────────────────────────────────────────────────────────
-- trips.max_size is free text ("Envelope / Document", "Shoebox (30×20×15 cm)",
-- "Backpack size"); this turns it into the size class used on requests.
create or replace function nata.trip_size_class(max_size text)
returns text
language sql
immutable
as $$
  select case
           when lower(btrim(coalesce(max_size, ''))) like 'envelope%' then 'envelope'
           when lower(btrim(coalesce(max_size, ''))) like 'shoebox%'  then 'shoebox'
           when lower(btrim(coalesce(max_size, ''))) like 'backpack%' then 'backpack'
         end;
$$;

-- How long a traveler has to respond to a new request.
create or replace function nata.request_response_window()
returns interval
language sql
immutable
as $$ select interval '48 hours'; $$;

-- Platform protection & escrow fee: 10% of the traveler's price.
create or replace function nata.platform_fee_for(traveler_price numeric)
returns numeric
language sql
immutable
as $$ select round(traveler_price * 0.10, 2); $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Create a request
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.create_delivery_request(uuid, uuid, text, numeric, text, text, text, text[]);

create or replace function public.create_delivery_request(
  p_id                uuid,
  p_trip_id           uuid,
  p_item_name         text,
  p_item_category     text,
  p_item_description  text,
  p_item_weight_kg    numeric,
  p_item_size         text,
  p_item_size_class   text,
  p_recipient_name    text,
  p_recipient_phone   text,
  p_photo_paths       text[],
  p_expected_total    numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid         uuid := auth.uid();
  trip        record;
  path        text;
  fee         numeric(10, 2);
  total       numeric(10, 2);
  trip_class  text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Already created by an earlier attempt of the same request: nothing to do.
  if exists (select 1 from nata.delivery_requests where id = p_id and sender_id = uid) then
    return p_id;
  end if;

  select t.id, t.traveler_id, t.status, t.departure_date, t.max_weight_kg,
         t.max_size, t.price, t.currency
    into trip
    from nata.trips t
   where t.id = p_trip_id;

  if not found or trip.status <> 'live' or trip.departure_date < current_date then
    raise exception 'nata:trip_unavailable';
  end if;
  if trip.traveler_id = uid then
    raise exception 'nata:own_trip';
  end if;

  if coalesce(btrim(p_item_name), '') = '' then
    raise exception 'nata:item_required';
  end if;
  if p_item_category is null or p_item_category not in ('electronics', 'apparel', 'documents') then
    raise exception 'nata:item_category_invalid';
  end if;
  if coalesce(btrim(p_recipient_name), '') = '' then
    raise exception 'nata:recipient_required';
  end if;
  if p_recipient_phone is null or p_recipient_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'nata:phone_invalid';
  end if;
  if p_item_weight_kg is null or p_item_weight_kg <= 0 then
    raise exception 'nata:weight_invalid';
  end if;
  if trip.max_weight_kg is not null and p_item_weight_kg > trip.max_weight_kg then
    raise exception 'nata:weight_too_heavy';
  end if;

  if p_item_size_class is null or p_item_size_class not in ('envelope', 'shoebox', 'backpack') then
    raise exception 'nata:size_required';
  end if;
  trip_class := nata.trip_size_class(trip.max_size);
  if trip_class is not null
     and nata.size_class_rank(p_item_size_class) > nata.size_class_rank(trip_class) then
    raise exception 'nata:size_too_big';
  end if;

  if coalesce(array_length(p_photo_paths, 1), 0) = 0 then
    raise exception 'nata:photo_required';
  end if;

  -- The price is the trip's price at this moment, frozen on the request. If it
  -- is not what the sender was shown, they must look again before sending.
  fee   := nata.platform_fee_for(trip.price);
  total := trip.price + fee;
  if p_expected_total is not null and abs(p_expected_total - total) > 0.005 then
    raise exception 'nata:price_changed';
  end if;

  -- One open request per sender and trip (also enforced by a unique index).
  if exists (
    select 1 from nata.delivery_requests r
     where r.trip_id = p_trip_id
       and r.sender_id = uid
       and r.status in ('pending', 'accepted', 'paid', 'handed_off')
  ) then
    raise exception 'nata:duplicate';
  end if;

  begin
    insert into nata.delivery_requests (
      id, trip_id, sender_id,
      item_name, item_category, item_description,
      item_weight_kg, item_size, item_size_class,
      traveler_price, platform_fee, total_amount, currency,
      expires_at, status
    ) values (
      p_id, p_trip_id, uid,
      btrim(p_item_name), p_item_category, coalesce(btrim(p_item_description), ''),
      p_item_weight_kg, nullif(btrim(coalesce(p_item_size, '')), ''), p_item_size_class,
      trip.price, fee, total, upper(btrim(trip.currency)),
      now() + nata.request_response_window(), 'pending'
    );
  exception when unique_violation then
    raise exception 'nata:duplicate';
  end;

  -- The recipient lives in its own table: the traveler only sees it after
  -- accepting (see "traveler reads recipient after accepting").
  insert into nata.request_recipients (request_id, name, phone)
  values (p_id, btrim(p_recipient_name), p_recipient_phone);

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

revoke all on function public.create_delivery_request(uuid, uuid, text, text, text, numeric, text, text, text, text, text[], numeric) from public;
grant execute on function public.create_delivery_request(uuid, uuid, text, text, text, numeric, text, text, text, text, text[], numeric) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. The Messages list shows the item's name
--    (item_description is now only the sender's notes)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.list_conversations()
returns table (
  conversation_id       uuid,
  request_id            uuid,
  created_at            timestamptz,
  updated_at            timestamptz,
  other_user_id         uuid,
  other_first_name      text,
  other_last_name       text,
  other_avatar_path     text,
  other_verified        boolean,
  i_am_traveler         boolean,
  departure_city        text,
  arrival_city          text,
  item_description      text,
  request_status        text,
  last_body             text,
  last_attachment_path  text,
  last_message_at       timestamptz,
  last_author_id        uuid,
  unread_count          integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    c.request_id,
    c.created_at,
    c.updated_at,
    other.id,
    other.first_name,
    other.last_name,
    other.avatar_path,
    (other.verification_status = 'verified'),
    (t.traveler_id = auth.uid()),
    dc.name,
    ac.name,
    coalesce(nullif(btrim(r.item_name), ''), r.item_description),
    r.status,
    lm.body,
    lm.attachment_path,
    lm.created_at,
    lm.author_id,
    coalesce(un.n, 0)::integer
  from nata.conversations c
  join nata.delivery_requests r on r.id = c.request_id
  join nata.trips t on t.id = r.trip_id
  join nata.cities dc on dc.id = t.departure_city_id
  join nata.cities ac on ac.id = t.arrival_city_id
  left join nata.profiles other
    on other.id = case when r.sender_id = auth.uid()
                       then t.traveler_id else r.sender_id end
  left join lateral (
    select m.body, m.attachment_path, m.created_at, m.author_id
    from nata.messages m
    where m.conversation_id = c.id
    order by m.created_at desc
    limit 1
  ) lm on true
  left join lateral (
    select count(*) as n
    from nata.messages m
    where m.conversation_id = c.id
      and m.author_id <> auth.uid()
      and m.read_at is null
  ) un on true
  where auth.uid() is not null
    and (r.sender_id = auth.uid() or t.traveler_id = auth.uid())
  order by coalesce(lm.created_at, c.created_at) desc;
$$;

revoke all on function public.list_conversations() from public;
grant execute on function public.list_conversations() to authenticated;
