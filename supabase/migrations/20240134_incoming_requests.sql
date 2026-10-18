-- The traveler's side of requests: what was asked of them, and declining.
--
-- Run AFTER 20240133_checkout_traveler_id.sql. Safe to re-run.
--
--   * public.list_incoming_requests(): the requests made on the signed-in
--     traveler's trips that still matter: waiting for an answer, accepted,
--     paid, in transit, and those delivered in the last 30 days. Newest first.
--     The recipient's name and phone are only given once the traveler has
--     accepted.
--   * public.decline_delivery_request(p_id, p_reason): the trip's traveler
--     turns down a request that is still waiting for an answer.
-- Accepting is public.accept_delivery_request (20240129), which also fixes
-- the price in the sender's currency.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Requests on my trips
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.list_incoming_requests();

create or replace function public.list_incoming_requests()
returns table (
  request_id          uuid,
  status              text,
  created_at          timestamptz,
  expires_at          timestamptz,
  responded_at        timestamptz,
  -- What the traveler earns: the delivery cost, in US dollars.
  payout_usd          numeric,
  items               jsonb,
  item_weight_kg      numeric,
  item_size           text,
  item_size_class     text,
  photo_paths         text[],
  sender_id           uuid,
  sender_first_name   text,
  sender_last_name    text,
  sender_avatar_path  text,
  sender_verified     boolean,
  -- Deliveries this sender has completed before.
  sender_deliveries   integer,
  recipient_name      text,
  recipient_phone     text,
  trip_id             uuid,
  departure_city      text,
  departure_country   text,
  arrival_city        text,
  arrival_country     text,
  departure_date      date,
  arrival_date        date
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.status,
    r.created_at,
    r.expires_at,
    r.responded_at,
    r.traveler_price,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'name', i.name, 'category', i.category,
                'description', i.description) order by i.position)
         from nata.request_items i where i.request_id = r.id),
      '[]'::jsonb),
    r.item_weight_kg,
    r.item_size,
    r.item_size_class,
    coalesce(
      (select array_agg(ph.photo_path order by ph.photo_path)
         from nata.request_photos ph
        where ph.request_id = r.id and ph.type = 'item'),
      '{}'::text[]),
    r.sender_id,
    sp.first_name,
    sp.last_name,
    sp.avatar_path,
    coalesce(sp.verification_status = 'verified', false),
    (select count(*)::integer from nata.delivery_requests d
      where d.sender_id = r.sender_id and d.status = 'delivered'),
    -- Personal details of the recipient only once the traveler accepted.
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then rr.name end,
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then rr.phone end,
    t.id,
    dc.name,
    dc.country_code::text,
    ac.name,
    ac.country_code::text,
    t.departure_date,
    t.arrival_date
  from nata.delivery_requests r
  join nata.trips t     on t.id  = r.trip_id
  join nata.profiles sp on sp.id = r.sender_id
  join nata.cities dc   on dc.id = t.departure_city_id
  join nata.cities ac   on ac.id = t.arrival_city_id
  left join nata.request_recipients rr on rr.request_id = r.id
  where auth.uid() is not null
    and t.traveler_id = auth.uid()
    and (
      r.status in ('pending', 'accepted', 'paid', 'handed_off')
      or (r.status = 'delivered'
          and coalesce(r.delivered_at, r.updated_at) > now() - interval '30 days')
    )
  order by r.created_at desc;
$$;

revoke all on function public.list_incoming_requests() from public;
grant execute on function public.list_incoming_requests() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Declining
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.decline_delivery_request(uuid, text);

create or replace function public.decline_delivery_request(
  p_id      uuid,
  p_reason  text default null
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

  select r.id, r.status, r.expires_at, t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id
   for update of r;

  if not found or req.traveler_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'pending'
     or (req.expires_at is not null and req.expires_at < now()) then
    raise exception 'nata:request_not_pending';
  end if;

  update nata.delivery_requests
     set status          = 'declined',
         declined_reason = nullif(left(btrim(coalesce(p_reason, '')), 300), ''),
         responded_at    = now()
   where id = p_id;
end;
$$;

revoke all on function public.decline_delivery_request(uuid, text) from public;
grant execute on function public.decline_delivery_request(uuid, text) to authenticated;
