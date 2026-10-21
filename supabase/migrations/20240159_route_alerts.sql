-- Route alerts: a member saves the routes they often send on (from a city to
-- a city) and is notified, and pushed, when a trip on one of them goes live.
--
-- Run AFTER 20240158_chat_live.sql. Safe to re-run.
--
--   * nata.route_alerts: up to 5 routes per member, each from one city to
--     another. Members see, add and remove only their own.
--   * public.my_route_alerts() lists them with city and country names.
--   * When a trip becomes 'live' (created live, or approved later) and
--     leaves today or later, every member with that exact route is
--     notified (event trip_match), except the traveler. The notification
--     carries both places, so tapping it opens the search for that route.

create table if not exists nata.route_alerts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  from_city_id  integer not null references nata.cities (id),
  to_city_id    integer not null references nata.cities (id),
  created_at    timestamptz not null default now(),
  constraint route_alerts_unique unique (user_id, from_city_id, to_city_id),
  constraint route_alerts_two_places check (from_city_id <> to_city_id)
);
create index if not exists route_alerts_route_idx
  on nata.route_alerts (from_city_id, to_city_id);

alter table nata.route_alerts enable row level security;
revoke all on nata.route_alerts from anon, authenticated;
grant select, insert, delete on nata.route_alerts to authenticated;

drop policy if exists "Members see their route alerts" on nata.route_alerts;
create policy "Members see their route alerts"
  on nata.route_alerts for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Members add their route alerts" on nata.route_alerts;
create policy "Members add their route alerts"
  on nata.route_alerts for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Members remove their route alerts" on nata.route_alerts;
create policy "Members remove their route alerts"
  on nata.route_alerts for delete to authenticated
  using (user_id = auth.uid());

-- At most 5 per member: nata:route_alert_limit.
create or replace function nata.route_alerts_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from nata.route_alerts a where a.user_id = new.user_id) >= 5 then
    raise exception 'nata:route_alert_limit';
  end if;
  return new;
end;
$$;

drop trigger if exists route_alerts_limit on nata.route_alerts;
create trigger route_alerts_limit
  before insert on nata.route_alerts
  for each row execute function nata.route_alerts_limit();

-- The signed-in member's routes, with names, newest first.
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
  created_at         timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id,
         fc.id, fc.name, btrim(fc.country_code), coalesce(fco.name, ''),
         tc.id, tc.name, btrim(tc.country_code), coalesce(tco.name, ''),
         a.created_at
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

-- A trip on a saved route goes live: tell those members.
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

  for a in
    select distinct r.user_id
      from nata.route_alerts r
     where r.from_city_id = new.departure_city_id
       and r.to_city_id = new.arrival_city_id
       and r.user_id <> new.traveler_id
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
  end loop;
  return new;
end;
$$;

revoke all on function nata.notify_route_alerts() from public, anon, authenticated;

drop trigger if exists notify_route_alerts on nata.trips;
create trigger notify_route_alerts
  after insert or update of status on nata.trips
  for each row execute function nata.notify_route_alerts();
