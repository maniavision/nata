-- Travelers may browse under a pseudonym.
--
-- Run AFTER 20240182_hide_recipient_phone.sql. Safe to re-run.
--
-- A traveler chooses in Profile how people who find them see them: their
-- real name ("Daniel O.") or a pseudonym they pick. The pseudonym shows
-- wherever people browse travelers: search, the traveler's profile, route
-- alerts, the sender's requests until the traveler accepts, the declined
-- and unanswered notifications, and the traveler's name on reviews they
-- left for senders. Once the traveler accepts a request, that sender (and
-- the recipient) see the real first name for the handover.
--
--   * nata.profiles.pseudonym / use_pseudonym, checked here (2-20
--     characters: letters, numbers, spaces, . _ -; not "Nata", "admin",
--     "support" or "moderator").
--   * public.set_public_name(use_pseudonym, pseudonym): the member's choice.
--   * nata.public_first / nata.public_last: the name browsing shows.
--   * The functions below are the live ones with only those names changed.

alter table nata.profiles add column if not exists pseudonym text;
alter table nata.profiles
  add column if not exists use_pseudonym boolean not null default false;

alter table nata.profiles drop constraint if exists profiles_pseudonym_check;
alter table nata.profiles add constraint profiles_pseudonym_check check (
  pseudonym is null
  or (char_length(pseudonym) between 2 and 20
      and pseudonym = btrim(pseudonym)
      and pseudonym ~ '^[[:alnum:]][[:alnum:] ._-]*$'
      and pseudonym !~* '(nata|admin|support|moderator)'));
alter table nata.profiles drop constraint if exists profiles_use_pseudonym_check;
alter table nata.profiles add constraint profiles_use_pseudonym_check check (
  not use_pseudonym or pseudonym is not null);

-- -----------------------------------------------------------------------------
-- 1. The name people browsing see
-- -----------------------------------------------------------------------------
create or replace function nata.public_first(
  p_first text, p_pseudonym text, p_use boolean)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when coalesce(p_use, false) and coalesce(p_pseudonym, '') <> ''
              then p_pseudonym else p_first end;
$$;

-- No last name (nor initial) with a pseudonym.
create or replace function nata.public_last(p_last text, p_use boolean)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when coalesce(p_use, false) then '' else p_last end;
$$;

-- -----------------------------------------------------------------------------
-- 2. The member's choice
-- -----------------------------------------------------------------------------
create or replace function public.set_public_name(
  p_use_pseudonym boolean,
  p_pseudonym text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  name text := nullif(btrim(coalesce(p_pseudonym, '')), '');
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if coalesce(p_use_pseudonym, false) and name is null then
    raise exception 'nata:pseudonym_invalid';
  end if;
  if name is not null and (
       char_length(name) not between 2 and 20
       or name !~ '^[[:alnum:]][[:alnum:] ._-]*$') then
    raise exception 'nata:pseudonym_invalid';
  end if;
  if name ~* '(nata|admin|support|moderator)' then
    raise exception 'nata:pseudonym_reserved';
  end if;
  update nata.profiles
     set use_pseudonym = coalesce(p_use_pseudonym, false),
         -- The pseudonym is kept when switching back to the real name.
         pseudonym = coalesce(name, pseudonym)
   where id = uid;
end;
$$;
revoke all on function public.set_public_name(boolean, text) from public, anon;
grant execute on function public.set_public_name(boolean, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Where people browse
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_travelers(p_departure_country text DEFAULT NULL::text, p_departure_city text DEFAULT NULL::text, p_arrival_country text DEFAULT NULL::text, p_arrival_city text DEFAULT NULL::text, p_date date DEFAULT NULL::date, p_limit integer DEFAULT 50)
 RETURNS TABLE(trip_id uuid, traveler_id uuid, first_name text, last_name text, avatar_path text, avg_rating numeric, items_delivered_count integer, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, price numeric, currency text, max_weight_kg numeric, max_size text)
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
$function$;

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

CREATE OR REPLACE FUNCTION public.list_my_sent_requests()
 RETURNS TABLE(request_id uuid, status text, created_at timestamp with time zone, total_amount numeric, cancellation_fee numeric, cancelled_at timestamp with time zone, display_currency text, exchange_rate numeric, display_cost numeric, display_fee numeric, display_total numeric, display_cancellation_fee numeric, price_fixed_at timestamp with time zone, expires_at timestamp with time zone, ticket_checked_at timestamp with time zone, id_checked_at timestamp with time zone, traveler_verified boolean, receipt_confirmed_at timestamp with time zone, reviewed boolean, ticket_on_file boolean, ticket_shared_path text, has_booking_reference boolean, currency text, item_weight_kg numeric, item_size text, item_size_class text, items jsonb, recipient_name text, recipient_phone text, photo_paths text[], trip_id uuid, traveler_id uuid, first_name text, last_name text, avatar_path text, avg_rating numeric, items_delivered_count integer, departure_city text, departure_country text, arrival_city text, arrival_country text, departure_date date, arrival_date date, price numeric, trip_currency text, max_weight_kg numeric, max_size text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    r.id,
    r.status,
    r.created_at,
    r.total_amount,
    r.cancellation_fee,
    r.cancelled_at,
    r.display_currency::text,
    r.exchange_rate,
    r.display_cost,
    r.display_fee,
    r.display_total,
    r.display_cancellation_fee,
    r.price_fixed_at,
    r.expires_at,
    r.ticket_checked_at,
    r.id_checked_at,
    coalesce(p.verification_status = 'verified', false),
    r.receipt_confirmed_at,
    exists (select 1 from nata.reviews v
             where v.request_id = r.id and v.reviewer_id = r.sender_id),
    coalesce(t.ticket_receipt_path, '') <> '',
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then nullif(t.ticket_shared_path, '') end,
    coalesce(t.booking_reference, '') <> '',
    r.currency::text,
    r.item_weight_kg,
    r.item_size,
    r.item_size_class,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'name', i.name, 'category', i.category,
                'description', i.description) order by i.position)
         from nata.request_items i where i.request_id = r.id),
      '[]'::jsonb),
    rr.name,
    rr.phone,
    coalesce(
      (select array_agg(ph.photo_path order by ph.photo_path)
         from nata.request_photos ph
        where ph.request_id = r.id and ph.type = 'item'),
      '{}'::text[]),
    t.id,
    t.traveler_id,
    -- The traveler's real name once they accepted; until then the
    -- pseudonym they browse under (20240183).
    case when (r.status in ('accepted', 'paid', 'handed_off', 'delivered') or (r.status = 'cancelled' and r.price_fixed_at is not null)) then p.first_name
         else nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym) end,
    case when (r.status in ('accepted', 'paid', 'handed_off', 'delivered') or (r.status = 'cancelled' and r.price_fixed_at is not null)) then p.last_name
         else nata.public_last(p.last_name, p.use_pseudonym) end,
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
  from nata.delivery_requests r
  join nata.trips t      on t.id  = r.trip_id
  join nata.profiles p   on p.id  = t.traveler_id
  join nata.cities dc    on dc.id = t.departure_city_id
  join nata.cities ac    on ac.id = t.arrival_city_id
  left join nata.request_recipients rr on rr.request_id = r.id
  where auth.uid() is not null
    and r.sender_id = auth.uid()
  order by r.created_at desc;
$function$;

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
    perform nata.notify(traveler, 'request', 'request_new',
      'New delivery request',
      coalesce(sender, 'A sender') || ' wants you to carry an item on ' || route || '.',
      new.id, info);
    return new;
  end if;

  case new.status
    when 'accepted' then
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

CREATE OR REPLACE FUNCTION nata.notify_route_alerts()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  -- The name the traveler browses under (20240183).
  select nullif(btrim(coalesce(
           nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym), '')), '')
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
$function$;

CREATE OR REPLACE FUNCTION public.list_sender_reviews(p_sender_id uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(review_id uuid, rating integer, tags text[], comment text, created_at timestamp with time zone, reviewer_first text, reviewer_initial text, total integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select v.id,
         v.rating::integer,
         v.tags,
         v.comment,
         v.created_at,
         -- Another traveler reads it: the reviewer's public name (20240183).
         nata.public_first(p.first_name, p.pseudonym, p.use_pseudonym),
         left(coalesce(nata.public_last(p.last_name, p.use_pseudonym), ''), 1),
         (count(*) over ())::integer
    from nata.reviews v
    join nata.profiles p on p.id = v.reviewer_id
   where v.reviewee_id = p_sender_id
     and v.reviewee_role = 'sender'
     and auth.uid() is not null
     and (auth.uid() = p_sender_id
          or exists (select 1
                       from nata.delivery_requests r
                       join nata.trips t on t.id = r.trip_id
                      where r.sender_id = p_sender_id
                        and t.traveler_id = auth.uid()))
   order by v.created_at desc
   limit greatest(1, least(coalesce(p_limit, 10), 50));
$function$;
