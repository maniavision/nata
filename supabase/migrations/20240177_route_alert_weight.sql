-- Route alerts: an optional weight to send.
--
-- Run AFTER 20240176_push_every_event.sql. Safe to re-run.
--
-- When saving a route, the member can say how much they want to send. Then
-- only travelers who can carry at least that much on the route are
-- notified; a trip that gives no weight limit still is. Left empty, every
-- traveler on the route counts, as before.
--
--   * nata.route_alerts.min_weight_kg: the weight (null = any).
--   * public.my_route_alerts(): also returns it.
--   * nata.notify_route_alerts(): skips trips that carry less.

alter table nata.route_alerts
  add column if not exists min_weight_kg numeric(6, 2)
    check (min_weight_kg is null or (min_weight_kg > 0 and min_weight_kg <= 100));

grant insert (from_city_id, to_city_id, max_alerts, min_weight_kg)
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
  alerts_sent        integer,
  min_weight_kg      numeric
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
         a.alerts_sent,
         a.min_weight_kg
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
-- limit, when it can carry what they want to send.
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
       -- The weight the member wants to send, when they gave one: a trip
       -- that names a smaller limit doesn't match (one with no limit does).
       and (r.min_weight_kg is null or new.max_weight_kg is null
            or new.max_weight_kg >= r.min_weight_kg)
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
        'max_weight_kg', new.max_weight_kg,
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
