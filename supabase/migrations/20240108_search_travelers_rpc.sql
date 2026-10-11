-- Public traveler search used by the "Travelers Found" screen.
--
-- Row-level security only lets users read their OWN trips, so the app cannot
-- query nata.trips directly to find other people's trips. This SECURITY DEFINER
-- function exposes just the public fields needed to show a traveler card,
-- following the same pattern as public.search_countries.
--
-- Run in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql
--
-- All filters are optional (NULL = no filter).
--   p_*_country : ISO 3166-1 alpha-2 code, e.g. 'NG'
--   p_*_city    : city name, case-insensitive exact match, e.g. 'Lagos'
--   p_date      : latest acceptable delivery date; matches trips arriving on
--                 or before this date

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
    p.last_name,
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
  order by t.departure_date asc, p.avg_rating desc nulls last
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.search_travelers(text, text, text, text, date, integer) from public;
grant execute on function public.search_travelers(text, text, text, text, date, integer) to authenticated;
