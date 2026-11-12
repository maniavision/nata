-- The Parcel Market: travelers find items to carry.
--
-- Run AFTER 20240212_nigeria_flat_fees.sql. Safe to re-run.
--
-- Until now only senders started a match. A sender may now also show a
-- request (one item or a bundle: one group_id) on the market, where
-- travelers with a live trip on that route offer to carry it.
--
--   * nata.market_items: the requests on the market, one row per group.
--     public.set_market_listing(group, listed) puts one on or takes it off.
--     A listing stays up 30 days at most, and only while nobody is paid.
--   * public.list_market(): the listings that fit one of the signed-in
--     traveler's live trips (same destination, leaving from a city the
--     sender chose). The sender shows under their public name (pseudonym,
--     20240183) with their photo blurred; no notes, photos or recipient.
--     Each listing counts the sender's pending requests and the offers.
--   * nata.market_offers / public.offer_to_carry(group, trip): at most 5
--     pending offers per item. When the sender already sent this traveler a
--     pending request for the item, the offer accepts that request instead.
--   * public.list_market_offers(group), accept_market_offer(offer),
--     decline_market_offer(offer), withdraw_market_offer(offer). Accepting
--     an offer creates an accepted request for that trip (the same items and
--     photos), and the sender then pays the flat fee as usual.
--   * Once the fee is paid for any traveler on an item, the item's other
--     pending and accepted requests are cancelled (cancel_reason
--     'item_found'), its pending offers close, and those travelers are told
--     the item found a traveler. This holds for every request sent to
--     several travelers, on the market or not: one item, one traveler.
--   * public.accept_delivery_request() is unchanged for the app; its body
--     moves to nata.accept_request_for(request, traveler) so an offer can
--     use it.

-- -----------------------------------------------------------------------------
-- 1. Listings and offers
-- -----------------------------------------------------------------------------
create table if not exists nata.market_items (
  group_id      uuid primary key,
  sender_id     uuid not null references nata.profiles (id) on delete cascade,
  listed_at     timestamptz not null default now(),
  expires_at    timestamptz not null default now() + interval '30 days',
  closed_at     timestamptz,
  closed_reason text check (closed_reason in ('unlisted', 'found', 'cancelled'))
);
create index if not exists market_items_open_idx
  on nata.market_items (listed_at desc) where closed_at is null;

alter table nata.market_items enable row level security;
revoke all on nata.market_items from public, anon, authenticated;

create table if not exists nata.market_offers (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references nata.market_items (group_id) on delete cascade,
  trip_id      uuid not null references nata.trips (id) on delete cascade,
  traveler_id  uuid not null references nata.profiles (id) on delete cascade,
  status       text not null default 'pending'
               check (status in ('pending', 'accepted', 'declined', 'withdrawn', 'closed')),
  request_id   uuid references nata.delivery_requests (id) on delete set null,
  created_at   timestamptz not null default now(),
  responded_at timestamptz
);
-- One open offer per traveler and item.
create unique index if not exists market_offers_one_pending
  on nata.market_offers (group_id, traveler_id) where status = 'pending';
create index if not exists market_offers_group_idx
  on nata.market_offers (group_id, status);

alter table nata.market_offers enable row level security;
revoke all on nata.market_offers from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Helpers
-- -----------------------------------------------------------------------------
-- A listing is open while it is up, not expired, and nobody on the item has
-- been paid.
create or replace function nata.market_open(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1 from nata.market_items m
            where m.group_id = p_group
              and m.closed_at is null
              and m.expires_at > now())
     and not exists (
           select 1 from nata.delivery_requests r
            where r.group_id = p_group
              and r.status in ('paid', 'handed_off', 'delivered'));
$$;
revoke all on function nata.market_open(uuid) from public, anon, authenticated;

-- Whether a trip fits an item: going to the item's destination, from a city
-- the sender chose, not departed, and able to take its weight.
create or replace function nata.market_trip_fits(p_group uuid, p_trip uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from nata.trips t
      join nata.delivery_requests f on f.id = p_group
     where t.id = p_trip
       and t.status = 'live'
       and t.departure_date >= current_date
       and (t.max_weight_kg is null or f.item_weight_kg <= t.max_weight_kg)
       and exists (
         select 1
           from nata.delivery_requests r
           join nata.trips rt on rt.id = r.trip_id
          where r.group_id = p_group
            and rt.arrival_city_id = t.arrival_city_id
            and rt.departure_city_id = t.departure_city_id));
$$;
revoke all on function nata.market_trip_fits(uuid, uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Listing a request
-- -----------------------------------------------------------------------------
create or replace function public.set_market_listing(p_group_id uuid, p_listed boolean)
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
  if not exists (select 1 from nata.delivery_requests r
                  where r.id = p_group_id and r.group_id = p_group_id
                    and r.sender_id = uid) then
    raise exception 'nata:request_not_found';
  end if;

  if p_listed then
    if exists (select 1 from nata.delivery_requests r
                where r.group_id = p_group_id
                  and r.status in ('paid', 'handed_off', 'delivered')) then
      raise exception 'nata:market_closed';
    end if;
    insert into nata.market_items (group_id, sender_id)
    values (p_group_id, uid)
    on conflict (group_id) do update
       set listed_at = now(),
           expires_at = now() + interval '30 days',
           closed_at = null,
           closed_reason = null;
  else
    update nata.market_items m
       set closed_at = now(), closed_reason = 'unlisted'
     where m.group_id = p_group_id and m.closed_at is null;
    perform nata.close_market_offers(p_group_id, 'closed');
  end if;
end;
$$;
revoke all on function public.set_market_listing(uuid, boolean) from public, anon;
grant execute on function public.set_market_listing(uuid, boolean) to authenticated;

-- Whether the sender's own request is on the market (for the app).
create or replace function public.my_market_listing(p_group_id uuid)
returns table (listed boolean, offers integer)
language sql
stable
security definer
set search_path = ''
as $$
  select nata.market_open(p_group_id),
         (select count(*)::integer from nata.market_offers o
           where o.group_id = p_group_id and o.status = 'pending')
   where exists (select 1 from nata.delivery_requests r
                  where r.id = p_group_id and r.sender_id = auth.uid());
$$;
revoke all on function public.my_market_listing(uuid) from public, anon;
grant execute on function public.my_market_listing(uuid) to authenticated;

-- Closes an item's pending offers and tells those travelers.
create or replace function nata.close_market_offers(p_group uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  o     record;
  route text;
begin
  for o in
    update nata.market_offers m
       set status = p_status, responded_at = now()
     where m.group_id = p_group and m.status = 'pending'
    returning m.id, m.traveler_id, m.trip_id
  loop
    select coalesce(dc.name, '') || ' → ' || coalesce(ac.name, '') into route
      from nata.trips t
      left join nata.cities dc on dc.id = t.departure_city_id
      left join nata.cities ac on ac.id = t.arrival_city_id
     where t.id = o.trip_id;
    perform nata.notify(o.traveler_id, 'request', 'market_offer_closed',
      'Item no longer available',
      'The item you offered to carry on ' || coalesce(route, '') || ' is no longer on the market.',
      o.id, jsonb_build_object('route', coalesce(route, ''), 'offer_id', o.id));
  end loop;
end;
$$;
revoke all on function nata.close_market_offers(uuid, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. The market, for travelers
-- -----------------------------------------------------------------------------
create or replace function public.list_market()
returns table (
  group_id          uuid,
  trip_id           uuid,
  item_name         text,
  item_category     text,
  item_count        integer,
  categories        text[],
  item_weight_kg    numeric,
  departure_city    text,
  departure_country text,
  arrival_city      text,
  arrival_country   text,
  sender_name       text,
  sender_avatar     text,
  sender_verified   boolean,
  sender_rating     numeric,
  pending_requests  integer,
  offers            integer,
  my_offer_id       uuid,
  my_request_id     uuid,
  listed_at         timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select t.id, t.departure_city_id, t.arrival_city_id, t.departure_date
      from nata.trips t
     where t.traveler_id = auth.uid()
       and t.status = 'live'
       and t.departure_date >= current_date
  )
  select distinct on (m.group_id)
    m.group_id,
    mt.id,
    f.item_name,
    f.item_category,
    (select count(*)::integer from nata.request_items i where i.request_id = f.id),
    (select array_agg(distinct i.category) from nata.request_items i where i.request_id = f.id),
    f.item_weight_kg,
    dc.name, dc.country_code::text,
    ac.name, ac.country_code::text,
    nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym),
    p.avatar_path,
    p.verification_status = 'verified',
    p.sender_avg_rating,
    (select count(*)::integer from nata.delivery_requests r
      where r.group_id = m.group_id and r.status = 'pending'
        and (r.expires_at is null or r.expires_at > now())),
    (select count(*)::integer from nata.market_offers o
      where o.group_id = m.group_id and o.status = 'pending'),
    (select o.id from nata.market_offers o
      where o.group_id = m.group_id and o.traveler_id = auth.uid()
        and o.status = 'pending'),
    (select r.id from nata.delivery_requests r
       join nata.trips rt on rt.id = r.trip_id
      where r.group_id = m.group_id and rt.traveler_id = auth.uid()
        and r.status = 'pending'
        and (r.expires_at is null or r.expires_at > now())
      limit 1),
    m.listed_at
  from nata.market_items m
  join nata.delivery_requests f on f.id = m.group_id
  join nata.profiles p on p.id = m.sender_id
  join mine mt on nata.market_trip_fits(m.group_id, mt.id)
  join nata.cities dc on dc.id = mt.departure_city_id
  join nata.cities ac on ac.id = mt.arrival_city_id
  where auth.uid() is not null
    -- Only verified travelers browse what people send.
    and exists (select 1 from nata.profiles me
                 where me.id = auth.uid() and me.verification_status = 'verified')
    and m.sender_id <> auth.uid()
    and p.deleted_at is null
    and nata.market_open(m.group_id)
    and not nata.blocked_between(auth.uid(), m.sender_id)
    -- Not when the traveler already carries it or was turned down for it.
    and not exists (
      select 1 from nata.delivery_requests r
        join nata.trips rt on rt.id = r.trip_id
       where r.group_id = m.group_id and rt.traveler_id = auth.uid()
         and r.status in ('accepted', 'paid', 'handed_off', 'delivered'))
  order by m.group_id, mt.departure_date
$$;
revoke all on function public.list_market() from public, anon;
grant execute on function public.list_market() to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Offering to carry
-- -----------------------------------------------------------------------------
create or replace function public.offer_to_carry(p_group_id uuid, p_trip_id uuid)
returns table (outcome text, offer_id uuid, request_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  uid     uuid := auth.uid();
  item    record;
  pending uuid;
  oid     uuid;
  route   text;
  trav    text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Offers on one item wait for each other, so the limit holds.
  select m.group_id, m.sender_id into item
    from nata.market_items m
   where m.group_id = p_group_id
     for update;
  if not found or not nata.market_open(p_group_id) then
    raise exception 'nata:market_closed';
  end if;
  if item.sender_id = uid then
    raise exception 'nata:own_item';
  end if;
  perform nata.require_verified(uid);
  if nata.blocked_between(uid, item.sender_id) then
    raise exception 'nata:market_closed';
  end if;
  if not exists (select 1 from nata.trips t
                  where t.id = p_trip_id and t.traveler_id = uid) then
    raise exception 'nata:trip_unavailable';
  end if;
  if not nata.market_trip_fits(p_group_id, p_trip_id) then
    raise exception 'nata:trip_does_not_fit';
  end if;
  if nata.trip_sender_count(p_trip_id, null) >= 3 then
    raise exception 'nata:trip_full';
  end if;

  -- The sender already asked this traveler: the offer is a yes.
  select r.id into pending
    from nata.delivery_requests r
    join nata.trips rt on rt.id = r.trip_id
   where r.group_id = p_group_id and rt.traveler_id = uid
     and r.status = 'pending'
     and (r.expires_at is null or r.expires_at > now())
   order by (r.trip_id = p_trip_id) desc
   limit 1;
  if pending is not null then
    perform nata.accept_request_for(pending, uid);
    return query select 'accepted'::text, null::uuid, pending;
    return;
  end if;

  if exists (select 1 from nata.delivery_requests r
               join nata.trips rt on rt.id = r.trip_id
              where r.group_id = p_group_id and rt.traveler_id = uid
                and r.status in ('accepted', 'paid', 'handed_off', 'delivered')) then
    raise exception 'nata:duplicate';
  end if;
  if exists (select 1 from nata.market_offers o
              where o.group_id = p_group_id and o.traveler_id = uid
                and o.status = 'pending') then
    raise exception 'nata:already_offered';
  end if;
  if (select count(*) from nata.market_offers o
       where o.group_id = p_group_id and o.status = 'pending') >= 5 then
    raise exception 'nata:offer_limit';
  end if;

  insert into nata.market_offers (group_id, trip_id, traveler_id)
  values (p_group_id, p_trip_id, uid)
  returning id into oid;

  select coalesce(dc.name, '') || ' → ' || coalesce(ac.name, ''),
         nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym)
    into route, trav
    from nata.trips t
    join nata.profiles p on p.id = t.traveler_id
    left join nata.cities dc on dc.id = t.departure_city_id
    left join nata.cities ac on ac.id = t.arrival_city_id
   where t.id = p_trip_id;
  perform nata.notify(item.sender_id, 'request', 'market_offer_new',
    'New offer to carry',
    coalesce(trav, 'A traveler') || ' offered to carry your item on ' || coalesce(route, '') || '.',
    p_group_id,
    jsonb_build_object('traveler', coalesce(trav, ''), 'route', coalesce(route, ''),
                       'request_id', p_group_id, 'offer_id', oid));

  return query select 'offered'::text, oid, null::uuid;
end;
$$;
revoke all on function public.offer_to_carry(uuid, uuid) from public, anon;
grant execute on function public.offer_to_carry(uuid, uuid) to authenticated;

create or replace function public.withdraw_market_offer(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update nata.market_offers o
     set status = 'withdrawn', responded_at = now()
   where o.id = p_offer_id and o.traveler_id = auth.uid() and o.status = 'pending';
  if not found then
    raise exception 'nata:offer_not_found';
  end if;
end;
$$;
revoke all on function public.withdraw_market_offer(uuid) from public, anon;
grant execute on function public.withdraw_market_offer(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Offers, for the sender
-- -----------------------------------------------------------------------------
create or replace function public.list_market_offers(p_group_id uuid)
returns table (
  offer_id        uuid,
  trip_id         uuid,
  traveler_id     uuid,
  first_name      text,
  last_name       text,
  avatar_path     text,
  photo_revealed  boolean,
  verified        boolean,
  avg_rating      numeric,
  items_delivered integer,
  departure_city  text,
  arrival_city    text,
  departure_date  date,
  arrival_date    date,
  created_at      timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id, o.trip_id, o.traveler_id,
         nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym),
         nata.public_last(p.last_name, p.use_pseudonym),
         p.avatar_path,
         -- Clear once the sender paid this traveler for a delivery (written
         -- out here: nata.photo_revealed, 20240188, isn't live everywhere).
         exists (select 1 from nata.delivery_requests d
                   join nata.trips dt on dt.id = d.trip_id
                  where dt.traveler_id = o.traveler_id
                    and d.sender_id = auth.uid()
                    and d.status in ('paid', 'handed_off', 'delivered')),
         p.verification_status = 'verified',
         p.avg_rating, p.items_delivered_count,
         dc.name, ac.name, t.departure_date, t.arrival_date,
         o.created_at
    from nata.market_offers o
    join nata.market_items m on m.group_id = o.group_id
    join nata.trips t on t.id = o.trip_id
    join nata.profiles p on p.id = o.traveler_id
    join nata.cities dc on dc.id = t.departure_city_id
    join nata.cities ac on ac.id = t.arrival_city_id
   where o.group_id = p_group_id
     and m.sender_id = auth.uid()
     and o.status = 'pending'
   order by o.created_at;
$$;
revoke all on function public.list_market_offers(uuid) from public, anon;
grant execute on function public.list_market_offers(uuid) to authenticated;

create or replace function public.decline_market_offer(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  oid      uuid;
  traveler uuid;
begin
  update nata.market_offers mo
     set status = 'declined', responded_at = now()
    from nata.market_items m
   where mo.id = p_offer_id and m.group_id = mo.group_id
     and m.sender_id = auth.uid() and mo.status = 'pending'
  returning mo.id, mo.traveler_id into oid, traveler;
  if not found then
    raise exception 'nata:offer_not_found';
  end if;
  perform nata.notify(traveler, 'request', 'market_offer_declined',
    'Offer declined',
    'The sender chose another traveler for this item.',
    oid, jsonb_build_object('offer_id', oid));
end;
$$;
revoke all on function public.decline_market_offer(uuid) from public, anon;
grant execute on function public.decline_market_offer(uuid) to authenticated;

-- The sender takes an offer: an accepted request for that traveler's trip,
-- with the item's details and photos. The sender then pays the flat fee.
create or replace function public.accept_market_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  o    record;
  f    record;
  fee  record;
  rid  uuid := gen_random_uuid();
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select mo.id, mo.group_id, mo.trip_id, mo.traveler_id, mo.status, m.sender_id
    into o
    from nata.market_offers mo
    join nata.market_items m on m.group_id = mo.group_id
   where mo.id = p_offer_id
     for update of mo;
  if not found or o.sender_id <> uid then
    raise exception 'nata:offer_not_found';
  end if;
  if o.status <> 'pending' then
    raise exception 'nata:offer_not_pending';
  end if;
  if not nata.market_open(o.group_id) then
    raise exception 'nata:market_closed';
  end if;
  if not nata.market_trip_fits(o.group_id, o.trip_id) then
    raise exception 'nata:trip_unavailable';
  end if;
  if exists (select 1 from nata.delivery_requests r
              where r.trip_id = o.trip_id and r.sender_id = uid
                and r.status in ('pending', 'accepted', 'paid', 'handed_off')) then
    raise exception 'nata:duplicate';
  end if;

  select r.* into f from nata.delivery_requests r where r.id = o.group_id;
  select x.amount, x.currency into fee from nata.flat_fee(uid, o.trip_id) x;

  -- No "new request" for the traveler: they offered.
  perform set_config('nata.from_offer', 'on', true);
  insert into nata.delivery_requests (
    id, trip_id, sender_id, group_id, pricing,
    item_name, item_category, item_description,
    item_weight_kg, item_size, item_size_class,
    traveler_price, platform_fee, total_amount, currency,
    display_currency, declared_value, declared_currency,
    expires_at, status
  ) values (
    rid, o.trip_id, uid, o.group_id, 'flat',
    f.item_name, f.item_category, f.item_description,
    f.item_weight_kg, f.item_size, f.item_size_class,
    0, fee.amount, fee.amount, fee.currency,
    f.display_currency, f.declared_value, f.declared_currency,
    now() + nata.request_response_window(), 'pending'
  );

  insert into nata.request_items (request_id, position, name, category, description,
                                  value, value_currency, receipt_path)
  select rid, i.position, i.name, i.category, i.description,
         i.value, i.value_currency, i.receipt_path
    from nata.request_items i where i.request_id = o.group_id;

  insert into nata.request_photos (request_id, uploaded_by, photo_path, type)
  select rid, ph.uploaded_by, ph.photo_path, ph.type
    from nata.request_photos ph
   where ph.request_id = o.group_id and ph.type = 'item';

  perform nata.accept_request_for(rid, o.traveler_id);
  perform set_config('nata.from_offer', 'off', true);

  update nata.market_offers mo
     set status = 'accepted', responded_at = now(), request_id = rid
   where mo.id = o.id;

  return rid;
end;
$$;
revoke all on function public.accept_market_offer(uuid) from public, anon;
grant execute on function public.accept_market_offer(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 7. Accepting, for the traveler or for an offer
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION nata.accept_request_for(p_id uuid, p_traveler uuid)
 RETURNS TABLE(display_currency text, exchange_rate numeric, display_cost numeric, display_fee numeric, display_total numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare
  req   record;
  cur   text;
  rate  numeric;
  base  numeric;
  cost  numeric;
  fee   numeric;
begin
  select r.id, r.status, r.expires_at, r.traveler_price, r.platform_fee,
         r.pricing, r.currency::text as fee_cur,
         coalesce(r.display_currency, 'USD') as cur, t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id
   for update of r;

  if not found or req.traveler_id <> p_traveler then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'pending'
     or (req.expires_at is not null and req.expires_at < now()) then
    raise exception 'nata:request_not_pending';
  end if;

  cur := req.cur;
  if cur = 'USD' then
    rate := 1;
  else
    select x.per_usd into rate
      from nata.exchange_rates x
     where x.currency = cur
       and x.updated_at > now() - interval '48 hours';
    if rate is null then
      raise exception 'nata:rate_unavailable';
    end if;
  end if;

  if req.pricing = 'flat' then
    -- The fee is in its own currency (USD, EUR or GBP): exact in that
    -- currency, else converted and rounded up.
    cost := 0;
    if cur = req.fee_cur then
      rate := 1;
      fee := req.platform_fee;
    else
      if req.fee_cur = 'USD' then
        base := 1;
      else
        select x.per_usd into base
          from nata.exchange_rates x
         where x.currency = req.fee_cur
           and x.updated_at > now() - interval '48 hours';
        if base is null then
          raise exception 'nata:rate_unavailable';
        end if;
      end if;
      fee := case when rate >= 10 then nata.round_up(req.platform_fee * rate / base)
                  else nata.round_up(req.platform_fee * rate / base, 2) end;
      rate := rate / base;
    end if;
  else
    -- Each line converted and rounded up, as the app shows it; the total is
    -- their sum.
    cost := nata.round_up(req.traveler_price * rate);
    fee  := nata.round_up(req.platform_fee * rate);
  end if;

  update nata.delivery_requests r
     set status           = 'accepted',
         responded_at     = now(),
         display_currency = cur,
         exchange_rate    = rate,
         display_cost     = cost,
         display_fee      = fee,
         display_total    = cost + fee,
         price_fixed_at   = now()
   where r.id = p_id;

  return query select cur, rate, cost, fee, cost + fee;
end;
$function$;
revoke all on function nata.accept_request_for(uuid, uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.accept_delivery_request(p_id uuid)
 RETURNS TABLE(display_currency text, exchange_rate numeric, display_cost numeric, display_fee numeric, display_total numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  return query select * from nata.accept_request_for(p_id, auth.uid());
end;
$function$;

-- -----------------------------------------------------------------------------
-- 8. One item, one traveler
-- -----------------------------------------------------------------------------
create or replace function nata.close_group_on_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid'
     and new.group_id is not null then
    update nata.delivery_requests r
       set status = 'cancelled',
           cancel_reason = 'item_found',
           cancelled_at = now(),
           cancelled_by = null
     where r.group_id = new.group_id
       and r.id <> new.id
       and r.status in ('pending', 'accepted');

    update nata.market_items m
       set closed_at = now(), closed_reason = 'found'
     where m.group_id = new.group_id and m.closed_at is null;
    perform nata.close_market_offers(new.group_id, 'closed');
  end if;

  -- A sender who cancels everything left on an item takes it off the market.
  if new.status = 'cancelled' and old.status is distinct from 'cancelled'
     and new.group_id is not null
     and coalesce(new.cancel_reason, '') <> 'item_found'
     and new.cancelled_by = new.sender_id
     and not exists (select 1 from nata.delivery_requests r
                      where r.group_id = new.group_id
                        and r.status in ('pending', 'accepted', 'paid', 'handed_off', 'delivered')) then
    update nata.market_items m
       set closed_at = now(), closed_reason = 'cancelled'
     where m.group_id = new.group_id and m.closed_at is null;
    perform nata.close_market_offers(new.group_id, 'closed');
  end if;
  return new;
end;
$$;

drop trigger if exists close_group_on_payment on nata.delivery_requests;
create trigger close_group_on_payment
  after update of status on nata.delivery_requests
  for each row execute function nata.close_group_on_payment();

-- -----------------------------------------------------------------------------
-- 9. Notifications (the live function, with the market's cases added)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION nata.notify_request_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  traveler   uuid;
  sender     text;
  trav_name  text;
  trav_shown text;
  route      text;
  info       jsonb;
  from_offer boolean := coalesce(current_setting('nata.from_offer', true), '') = 'on';
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  select t.traveler_id,
         coalesce(dc.name, '') || ' → ' || coalesce(ac.name, ''),
         tp.first_name,
         nata.public_first(tp.first_name, tp.pseudonym, tp.use_pseudonym)
    into traveler, route, trav_name, trav_shown
    from nata.trips t
    left join nata.cities dc on dc.id = t.departure_city_id
    left join nata.cities ac on ac.id = t.arrival_city_id
    left join nata.profiles tp on tp.id = t.traveler_id
   where t.id = new.trip_id;

  select p.first_name into sender from nata.profiles p where p.id = new.sender_id;

  info := jsonb_build_object(
    'sender', coalesce(sender, ''),
    'traveler', coalesce(trav_name, ''),
    'route', coalesce(route, ''),
    'request_id', new.id);

  if tg_op = 'INSERT' then
    -- A request made from the traveler's own offer (20240213).
    if from_offer then
      return new;
    end if;
    perform nata.notify(traveler, 'request', 'request_new',
      'New delivery request',
      coalesce(sender, 'A sender') || ' wants you to carry an item on ' || route || '.',
      new.id, info);
    return new;
  end if;

  case new.status
    when 'accepted' then
      if from_offer then
        perform nata.notify(traveler, 'request', 'market_offer_accepted',
          'Offer accepted',
          coalesce(sender, 'The sender') || ' accepted your offer on ' || route || '. The chat opens once they pay the Nata fee.',
          new.id, info);
        return new;
      end if;
      if new.pricing = 'flat' then
        perform nata.notify(new.sender_id, 'request', 'request_accepted_fee',
          'Request accepted',
          coalesce(trav_name, 'The traveler') || ' accepted your request. Pay the Nata fee within 24 hours to start chatting.',
          new.id, info);
        return new;
      end if;
      perform nata.notify(new.sender_id, 'request', 'request_accepted',
        'Request accepted',
        coalesce(trav_name, 'The traveler') || ' accepted your request. Pay within 24 hours to confirm it.',
        new.id, info);
    when 'declined' then
      -- Not accepted: the sender only knows the traveler's public name.
      perform nata.notify(new.sender_id, 'request', 'request_declined',
        'Request declined',
        coalesce(trav_shown, 'The traveler') || ' can''t take your item. Find another traveler on ' || route || '.',
        new.id, info || jsonb_build_object('traveler', coalesce(trav_shown, '')));
    when 'expired' then
      if old.status = 'pending' then
        perform nata.notify(new.sender_id, 'request', 'request_expired_unanswered',
          'Request expired',
          coalesce(trav_shown, 'The traveler') || ' didn''t answer in time. Find another traveler.',
          new.id, info || jsonb_build_object('traveler', coalesce(trav_shown, '')));
      else
        perform nata.notify(new.sender_id, 'request', 'request_expired_unpaid',
          'Request expired',
          'The 24 hours to pay have passed, so the request was closed.',
          new.id, info);
        perform nata.notify(traveler, 'request', 'request_expired_unpaid_traveler',
          'Request expired',
          coalesce(sender, 'The sender') || ' didn''t pay in time, so the request was closed.',
          new.id, info);
      end if;
    when 'cancelled' then
      -- Another traveler was paid for this item (20240213).
      if new.cancel_reason = 'item_found' then
        perform nata.notify(traveler, 'request', 'request_item_found',
          'Item found a traveler',
          'The item on ' || route || ' found another traveler, so this request was closed.',
          new.id, info);
        return new;
      end if;
      if auth.uid() is not null and auth.uid() = traveler then
        perform nata.notify(new.sender_id, 'request', 'request_cancelled_by_traveler',
          'Request cancelled',
          coalesce(trav_name, 'The traveler') || ' cancelled your request.',
          new.id, info);
      else
        perform nata.notify(traveler, 'request', 'request_cancelled_by_sender',
          'Request cancelled',
          coalesce(sender, 'The sender') || ' cancelled their request on ' || route || '.',
          new.id, info);
      end if;
    when 'paid' then
      if new.pricing = 'flat' then
        perform nata.notify(traveler, 'payment', 'contact_fee_paid',
          'Chat is open',
          coalesce(sender, 'The sender') || ' paid the Nata fee. Agree on the price and the handover in the chat.',
          new.id, info);
        perform nata.notify(new.sender_id, 'payment', 'contact_fee_received',
          'Chat is open',
          'You can now chat with ' || coalesce(trav_name, 'the traveler')
            || ' to agree on the price and the handover.',
          new.id, info);
        return new;
      end if;
      perform nata.notify(traveler, 'payment', 'request_paid',
        'Payment secured',
        coalesce(sender, 'The sender') || ' paid. The money is held safely until delivery, and chat is open.',
        new.id, info);
      perform nata.notify(new.sender_id, 'payment', 'payment_received',
        'Payment received',
        'Your payment is held safely until delivery. You can now chat with '
          || coalesce(trav_name, 'the traveler') || '.',
        new.id, info);
    when 'handed_off' then
      perform nata.notify(new.sender_id, 'trip', 'item_picked_up',
        'Item picked up',
        coalesce(trav_name, 'The traveler') || ' has your item and is on the way.',
        new.id, info);
    when 'delivered' then
      if new.pricing = 'flat' and new.receipt_confirmed_at is null then
        perform nata.notify(new.sender_id, 'request', 'delivered_by_traveler',
          'Item delivered',
          coalesce(trav_name, 'The traveler') || ' says they delivered your item. Confirm it and leave a review.',
          new.id, info);
        return new;
      end if;
      if new.pricing = 'flat' then
        perform nata.notify(traveler, 'request', 'delivery_confirmed_by_sender',
          'Delivery confirmed',
          coalesce(sender, 'The sender') || ' confirmed you delivered their item.',
          new.id, info);
        return new;
      end if;
      perform nata.notify(new.sender_id, 'request', 'item_delivered',
        'Item delivered',
        coalesce(trav_name, 'The traveler') || ' delivered your item. Confirm you received it.',
        new.id, info);
      perform nata.notify(traveler, 'payment', 'delivery_confirmed',
        'Delivery confirmed',
        'You delivered ' || coalesce(sender, 'the sender') || '''s item. Your payout is on its way.',
        new.id, info);
    else
      null;
  end case;
  return new;
end;
$function$;
