-- Route alerts: the member chooses how many travelers to hear about.
--
-- Run AFTER 20240167_archive_closed_requests.sql. Safe to re-run.
--
-- When saving a route, the member picks how many travelers on it to be
-- notified about (1, 3, 5, 10, or all). Each notification counts; once the
-- limit is reached the route stays saved but quiet, until the member
-- restarts it.
--
--   * nata.route_alerts.max_alerts: the limit (null = every traveler, as
--     before, and for routes saved by older app builds);
--     alerts_sent: how many travelers were notified so far.
--   * public.my_route_alerts(): also returns both.
--   * nata.notify_route_alerts(): skips routes at their limit, and counts.
--   * public.restart_route_alert(p_id): the member starts counting again.

alter table nata.route_alerts
  add column if not exists max_alerts   integer
    check (max_alerts is null or max_alerts between 1 and 50),
  add column if not exists alerts_sent  integer not null default 0;

-- The member saves the two cities and the limit; the count is changed only
-- by the trigger and restart_route_alert.
revoke insert, update on nata.route_alerts from anon, authenticated;
grant insert (from_city_id, to_city_id, max_alerts)
  on nata.route_alerts to authenticated;

drop function if exists public.my_route_alerts();

create or replace function public.my_route_alerts()
returns table (
  id                 uuid,
  from_city_id       integer,
  from_city          text,
  from_country_code  text,
  from_country       text,
  to_city_id         integer,
  to_city            text,
  to_country_code    text,
  to_country         text,
  created_at         timestamptz,
  max_alerts         integer,
  alerts_sent        integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id,
         fc.id, fc.name, btrim(fc.country_code), coalesce(fco.name, ''),
         tc.id, tc.name, btrim(tc.country_code), coalesce(tco.name, ''),
         a.created_at,
         a.max_alerts,
         a.alerts_sent
    from nata.route_alerts a
    join nata.cities fc on fc.id = a.from_city_id
    join nata.cities tc on tc.id = a.to_city_id
    left join nata.countries fco on fco.iso_code = fc.country_code
    left join nata.countries tco on tco.iso_code = tc.country_code
   where a.user_id = auth.uid()
   order by a.created_at desc;
$$;

revoke all on function public.my_route_alerts() from public, anon;
grant execute on function public.my_route_alerts() to authenticated;

-- A trip on a saved route goes live: tell those members, up to each one's
-- limit.
create or replace function nata.notify_route_alerts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  fc        record;
  tc        record;
  traveler  text;
  a         record;
begin
  if new.status <> 'live' or new.departure_date < current_date then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status = 'live' then
    return new;
  end if;

  select c.id, c.name, btrim(c.country_code) code, coalesce(co.name, '') country
    into fc
    from nata.cities c left join nata.countries co on co.iso_code = c.country_code
   where c.id = new.departure_city_id;
  select c.id, c.name, btrim(c.country_code) code, coalesce(co.name, '') country
    into tc
    from nata.cities c left join nata.countries co on co.iso_code = c.country_code
   where c.id = new.arrival_city_id;
  if fc.id is null or tc.id is null then
    return new;
  end if;

  select nullif(btrim(coalesce(p.first_name, '')), '')
    into traveler
    from nata.profiles p where p.id = new.traveler_id;

  -- Only routes that haven't reached their member's travelers limit.
  for a in
    select r.id, r.user_id
      from nata.route_alerts r
     where r.from_city_id = new.departure_city_id
       and r.to_city_id = new.arrival_city_id
       and r.user_id <> new.traveler_id
       and (r.max_alerts is null or r.alerts_sent < r.max_alerts)
  loop
    perform nata.notify(
      a.user_id,
      'trip',
      'trip_match',
      'A traveler is going your way',
      coalesce(traveler, 'A traveler') || ' flies ' || fc.name || ' → '
        || tc.name || ' on ' || to_char(new.departure_date, 'DD Mon'),
      new.id,
      jsonb_build_object(
        'traveler', coalesce(traveler, ''),
        'route', fc.name || ' → ' || tc.name,
        'date', new.departure_date,
        'trip_id', new.id,
        'from_city_id', fc.id, 'from_city', fc.name,
        'from_country_code', fc.code, 'from_country', fc.country,
        'to_city_id', tc.id, 'to_city', tc.name,
        'to_country_code', tc.code, 'to_country', tc.country)
    );
    update nata.route_alerts
       set alerts_sent = alerts_sent + 1
     where id = a.id;
  end loop;
  return new;
end;
$$;

revoke all on function nata.notify_route_alerts() from public, anon, authenticated;

-- The member starts counting again (a route that reached its limit).
create or replace function public.restart_route_alert(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  update nata.route_alerts
     set alerts_sent = 0
   where id = p_id and user_id = auth.uid();
end;
$$;

revoke all on function public.restart_route_alert(uuid) from public, anon;
grant execute on function public.restart_route_alert(uuid) to authenticated;
