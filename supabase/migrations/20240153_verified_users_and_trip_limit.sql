-- Only verified users post trips or send requests; a trip carries for at
-- most 3 senders.
--
-- Run AFTER 20240152_bank_transfer.sql. Safe to re-run.
--
--   * Creating a trip or a delivery request needs a passed identity check
--     (profiles.verification_status = 'verified'; 'pending' is not enough).
--     Otherwise: nata:not_verified.
--   * On each trip, a traveler can accept at most 3 requests, each from a
--     different sender. Requests count while accepted, paid, picked up or
--     delivered. Accepting a 4th, or a second one from the same sender, is
--     refused with nata:trip_full / nata:sender_on_trip, and so is sending a
--     new request to a trip that already has 3.
--
-- Both are checked by triggers, so they hold however the row is written.

-- -----------------------------------------------------------------------------
-- 1. Verified users only
-- -----------------------------------------------------------------------------
create or replace function nata.require_verified(p_user uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from nata.profiles p
                  where p.id = p_user and p.verification_status = 'verified') then
    raise exception 'nata:not_verified';
  end if;
end;
$$;

revoke all on function nata.require_verified(uuid) from public, anon, authenticated;

create or replace function nata.trips_require_verified()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform nata.require_verified(new.traveler_id);
  return new;
end;
$$;

drop trigger if exists require_verified on nata.trips;
create trigger require_verified
  before insert on nata.trips
  for each row execute function nata.trips_require_verified();

-- -----------------------------------------------------------------------------
-- 2. At most 3 senders per trip
-- -----------------------------------------------------------------------------
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
     and r.status in ('accepted', 'paid', 'handed_off', 'delivered');
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
                  and r.status in ('accepted', 'paid', 'handed_off', 'delivered')) then
      raise exception 'nata:sender_on_trip';
    end if;
    if nata.trip_sender_count(new.trip_id, new.id) >= 3 then
      raise exception 'nata:trip_full';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists check_rules on nata.delivery_requests;
create trigger check_rules
  before insert or update of status on nata.delivery_requests
  for each row execute function nata.requests_check_rules();

-- -----------------------------------------------------------------------------
-- 3. Full trips leave the search
-- -----------------------------------------------------------------------------
-- public.search_travelers (20240146), without the trips that already carry
-- for 3 senders.
create or replace function public.search_travelers(
  p_departure_country text    default null,
  p_departure_city    text    default null,
  p_arrival_country   text    default null,
  p_arrival_city      text    default null,
  p_date              date    default null,
  p_limit             integer default 50
)
returns table (
  trip_id                uuid,
  traveler_id            uuid,
  first_name             text,
  last_name              text,
  avatar_path            text,
  avg_rating             numeric,
  items_delivered_count  integer,
  departure_city         text,
  departure_country      text,
  arrival_city           text,
  arrival_country        text,
  departure_date         date,
  arrival_date           date,
  price                  numeric,
  currency               text,
  max_weight_kg          numeric,
  max_size               text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    t.id,
    t.traveler_id,
    p.first_name,
    -- Visitors who aren't signed in get only the initial (the app shows
    -- "Amara K." anyway).
    case when auth.uid() is null then left(p.last_name, 1) else p.last_name end,
    p.avatar_path,
    p.avg_rating,
    p.items_delivered_count,
    dc.name,
    dc.country_code::text,
    ac.name,
    ac.country_code::text,
    t.departure_date,
    t.arrival_date,
    t.price,
    t.currency::text,
    t.max_weight_kg,
    t.max_size
  from nata.trips t
  join nata.profiles p  on p.id  = t.traveler_id
  join nata.cities   dc on dc.id = t.departure_city_id
  join nata.cities   ac on ac.id = t.arrival_city_id
  where t.status = 'live'
    and t.departure_date >= current_date
    -- never show the signed-in user their own trips as "travelers"
    and t.traveler_id is distinct from auth.uid()
    and (p_departure_country is null or dc.country_code = upper(p_departure_country))
    and (p_departure_city    is null or dc.name ilike p_departure_city)
    and (p_arrival_country   is null or ac.country_code = upper(p_arrival_country))
    and (p_arrival_city      is null or ac.name ilike p_arrival_city)
    and (p_date              is null or t.arrival_date <= p_date)
    -- trips already carrying for 3 senders are full
    and nata.trip_sender_count(t.id, null) < 3
  order by t.departure_date asc, p.avg_rating desc nulls last
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.search_travelers(text, text, text, text, date, integer) from public;
grant execute on function public.search_travelers(text, text, text, text, date, integer) to anon, authenticated;

-- Check (run after):
--   select t.id, nata.trip_sender_count(t.id, null) from nata.trips t
--    where nata.trip_sender_count(t.id, null) > 3;   -- existing trips over
