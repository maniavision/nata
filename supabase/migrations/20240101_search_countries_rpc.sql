-- Run this in the Supabase SQL Editor to enable live country search.
-- Authentication: sign in at https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql

create or replace function public.search_countries(query text default '')
returns table (
  iso_code  text,
  name      text,
  phone_code text
)
language sql
stable
security definer
as $$
  select
    iso_code::text,
    name,
    phone_code
  from nata.countries
  where
    query = ''
    or name ilike '%' || query || '%'
  order by
    -- Exact match first, then starts-with, then contains
    case
      when lower(name) = lower(query)          then 0
      when lower(name) like lower(query) || '%' then 1
      else 2
    end,
    name
  limit 10;
$$;

-- Allow anon + authenticated users to call this function
grant execute on function public.search_countries(text) to anon, authenticated;
