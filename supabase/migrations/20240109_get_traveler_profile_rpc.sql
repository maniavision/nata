-- Public profile of one traveler, used by the "Traveler Profile" screen.
--
-- Same reasoning as search_travelers: row-level security hides other users'
-- rows, so this SECURITY DEFINER function returns only public fields: the
-- profile plus the traveler's upcoming live trips, as a single JSON object.
-- Returns NULL if the traveler does not exist.
--
-- Run in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql

create or replace function public.get_traveler_profile(p_traveler_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id',                    p.id,
    'first_name',            p.first_name,
    'last_name',             p.last_name,
    'avatar_path',           p.avatar_path,
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
$$;

revoke all on function public.get_traveler_profile(uuid) from public;
grant execute on function public.get_traveler_profile(uuid) to authenticated;
