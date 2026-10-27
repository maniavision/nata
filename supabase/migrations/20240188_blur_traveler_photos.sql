-- Traveler photos are blurred until the traveler accepts a request.
--
-- Run AFTER 20240187_nata_balance.sql. Safe to re-run.
--
-- For travelers' privacy, the app blurs a traveler's photo where people
-- browse (search, Home, their profile, the request form, a request not
-- accepted yet) until the traveler accepts one of the viewer's requests.
--
--   * nata.photo_revealed(traveler): whether the signed-in member may see
--     it clearly: they are the traveler, or the traveler accepted (paid,
--     picked up, delivered) one of their requests.
--   * public.search_travelers(): also returns photo_revealed (the live
--     function with only that added).
--   * public.get_traveler_profile(): also returns photo_revealed.
--
-- The photo itself still sits in the public user-assets bucket: this hides
-- it on screen, not from someone reading the app's traffic.

create or replace function nata.photo_revealed(p_traveler uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
     and (auth.uid() = p_traveler
          or exists (
            select 1
              from nata.delivery_requests d
              join nata.trips t on t.id = d.trip_id
             where t.traveler_id = p_traveler
               and d.sender_id = auth.uid()
               and (d.status in ('accepted', 'paid', 'handed_off', 'delivered')
                    or (d.status = 'cancelled' and d.price_fixed_at is not null))));
$$;
revoke all on function nata.photo_revealed(uuid) from public, anon, authenticated;

drop function if exists public.search_travelers(text, text, text, text, date, integer);
CREATE OR REPLACE FUNCTION public.search_travelers(p_departure_country text DEFAULT NULL::text, p_departure_city text DEFAULT NULL::text, p_arrival_country text DEFAULT NULL::text, p_arrival_city text DEFAULT NULL::text, p_date date DEFAULT NULL::date, p_limit integer DEFAULT 50)
 RETURNS TABLE(trip_id uuid, traveler_id uuid, first_name text, last_name text, avatar_path text, avg_rating numeric, items_delivered_count integer, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, price numeric, currency text, max_weight_kg numeric, max_size text, photo_revealed boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    t.id,
    t.traveler_id,
    -- The traveler's pseudonym when they chose one (20240183).
    nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym),
    -- Visitors who aren't signed in get only the initial (the app shows
    -- "Amara K." anyway); none with a pseudonym.
    case when auth.uid() is null then left(nata.public_last(p.last_name, p.use_pseudonym), 1) else nata.public_last(p.last_name, p.use_pseudonym) end,
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
    t.max_size,
    -- The photo shows clearly only once the traveler accepted one of the
    -- viewer's requests (20240188); blurred otherwise.
    nata.photo_revealed(t.traveler_id)
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
$function$;

revoke all on function public.search_travelers(text, text, text, text, date, integer) from public;
grant execute on function public.search_travelers(text, text, text, text, date, integer)
  to anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_traveler_profile(p_traveler_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'id',                    p.id,
    -- The pseudonym, except for the traveler themself (20240183).
    'first_name',            case when p.id = auth.uid() then p.first_name
                                  else nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym) end,
    'last_name',             case when p.id = auth.uid() then p.last_name
                                  else nata.public_last(p.last_name, p.use_pseudonym) end,
    'avatar_path',           p.avatar_path,
    'photo_revealed',        nata.photo_revealed(p.id),
    'verification_status',   p.verification_status,
    'avg_rating',            p.avg_rating,
    'items_delivered_count', p.items_delivered_count,
    'member_since',          p.created_at,
    'trips', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'trip_id',           t.id,
          'traveler_id',       t.traveler_id,
          'departure_city',    dc.name,
          'departure_country', dc.country_code::text,
          'arrival_city',      ac.name,
          'arrival_country',   ac.country_code::text,
          'departure_date',    t.departure_date,
          'arrival_date',      t.arrival_date,
          'price',             t.price,
          'currency',          t.currency::text,
          'max_weight_kg',     t.max_weight_kg,
          'max_size',          t.max_size
        )
        order by t.departure_date
      )
      from nata.trips t
      join nata.cities dc on dc.id = t.departure_city_id
      join nata.cities ac on ac.id = t.arrival_city_id
      where t.traveler_id = p.id
        and t.status = 'live'
        and t.departure_date >= current_date
    ), '[]'::jsonb)
  )
  from nata.profiles p
  where p.id = p_traveler_id;
$function$;
