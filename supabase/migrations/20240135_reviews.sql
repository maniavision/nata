-- The sender confirms receipt and reviews the traveler.
--
-- Run AFTER 20240134_incoming_requests.sql. Safe to re-run.
--
-- Once a request is delivered, the sender confirms they received it (from the
-- traveler's "delivered" notification, or the request card) and is then asked
-- to rate the traveler. Reviews are public as soon as they are submitted and
-- cannot be edited.
--
--   * nata.delivery_requests.receipt_confirmed_at, set by
--     public.confirm_receipt(p_id).
--   * nata.reviews.tags: what stood out (on_time, communication, careful,
--     flexible_pickup, use_again). One review per person per request.
--   * public.submit_traveler_review(...): the sender of a delivered request
--     rates its traveler (1-5), with tags and an optional comment; the
--     traveler's average rating is updated.
--   * public.list_traveler_reviews(p_traveler_id, p_limit): a traveler's
--     latest reviews for their public profile, with the total count.
--   * public.list_my_sent_requests(): also returns receipt_confirmed_at and
--     whether the sender has reviewed.

alter table nata.delivery_requests
  add column if not exists receipt_confirmed_at timestamptz;

alter table nata.reviews
  add column if not exists tags text[] not null default '{}';

create unique index if not exists reviews_one_per_reviewer
  on nata.reviews (request_id, reviewer_id);

-- -----------------------------------------------------------------------------
-- 1. Confirming receipt
-- -----------------------------------------------------------------------------
drop function if exists public.confirm_receipt(uuid);

create or replace function public.confirm_receipt(p_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid      uuid := auth.uid();
  req      record;
  stamped  timestamptz;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.receipt_confirmed_at
    into req
    from nata.delivery_requests r
   where r.id = p_id and r.sender_id = uid
   for update;

  if not found then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'delivered' then
    raise exception 'nata:request_not_delivered';
  end if;

  stamped := req.receipt_confirmed_at;
  if stamped is null then
    stamped := now();
    update nata.delivery_requests
       set receipt_confirmed_at = stamped
     where id = p_id;
  end if;
  return stamped;
end;
$$;

revoke all on function public.confirm_receipt(uuid) from public;
grant execute on function public.confirm_receipt(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Reviewing the traveler
-- -----------------------------------------------------------------------------
drop function if exists public.submit_traveler_review(uuid, integer, text[], text);

create or replace function public.submit_traveler_review(
  p_request_id  uuid,
  p_rating      integer,
  p_tags        text[] default '{}',
  p_comment     text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid       uuid := auth.uid();
  req       record;
  v_tags    text[] := coalesce(p_tags, '{}');
  v_comment text := btrim(coalesce(p_comment, ''));
  new_id    uuid;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.sender_id, t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id and r.sender_id = uid;

  if not found then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'delivered' then
    raise exception 'nata:request_not_delivered';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'nata:review_invalid';
  end if;
  if not v_tags <@ array['on_time', 'communication', 'careful',
                       'flexible_pickup', 'use_again']
     or char_length(v_comment) > 1000 then
    raise exception 'nata:review_invalid';
  end if;
  if exists (select 1 from nata.reviews v
              where v.request_id = p_request_id and v.reviewer_id = uid) then
    raise exception 'nata:already_reviewed';
  end if;

  insert into nata.reviews (request_id, reviewer_id, reviewee_id, rating, comment, tags)
  values (p_request_id, uid, req.traveler_id, p_rating, v_comment, v_tags)
  returning id into new_id;

  update nata.profiles p
     set avg_rating = (select round(avg(v.rating)::numeric, 1)
                         from nata.reviews v
                        where v.reviewee_id = req.traveler_id)
   where p.id = req.traveler_id;

  return new_id;
end;
$$;

revoke all on function public.submit_traveler_review(uuid, integer, text[], text) from public;
grant execute on function public.submit_traveler_review(uuid, integer, text[], text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. A traveler's reviews, for their public profile
-- -----------------------------------------------------------------------------
drop function if exists public.list_traveler_reviews(uuid, integer);

create or replace function public.list_traveler_reviews(
  p_traveler_id  uuid,
  p_limit        integer default 10
)
returns table (
  review_id          uuid,
  rating             integer,
  tags               text[],
  comment            text,
  created_at         timestamptz,
  reviewer_first     text,
  reviewer_initial   text,
  total              integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.id,
         v.rating::integer,
         v.tags,
         v.comment,
         v.created_at,
         p.first_name,
         left(coalesce(p.last_name, ''), 1),
         (count(*) over ())::integer
    from nata.reviews v
    join nata.profiles p on p.id = v.reviewer_id
   where v.reviewee_id = p_traveler_id
     and auth.uid() is not null
   order by v.created_at desc
   limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.list_traveler_reviews(uuid, integer) from public;
grant execute on function public.list_traveler_reviews(uuid, integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. The sender's requests, with receipt and review
--    Same as in 20240133_checkout_traveler_id.sql plus receipt_confirmed_at
--    and reviewed.
-- -----------------------------------------------------------------------------
drop function if exists public.list_my_sent_requests();

create or replace function public.list_my_sent_requests()
returns table (
  request_id             uuid,
  status                 text,
  created_at             timestamptz,
  total_amount           numeric,
  cancellation_fee       numeric,
  cancelled_at           timestamptz,
  display_currency       text,
  exchange_rate          numeric,
  display_cost           numeric,
  display_fee            numeric,
  display_total          numeric,
  display_cancellation_fee numeric,
  price_fixed_at         timestamptz,
  expires_at             timestamptz,
  ticket_checked_at      timestamptz,
  id_checked_at          timestamptz,
  traveler_verified      boolean,
  receipt_confirmed_at   timestamptz,
  reviewed               boolean,
  ticket_receipt_path    text,
  booking_reference      text,
  currency               text,
  item_weight_kg         numeric,
  item_size              text,
  item_size_class        text,
  items                  jsonb,
  recipient_name         text,
  recipient_phone        text,
  photo_paths            text[],
  -- The trip and its traveler, as public.search_travelers returns them.
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
  trip_currency          text,
  max_weight_kg          numeric,
  max_size               text
)
language sql
stable
security definer
set search_path = ''
as $$
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
    -- The traveler's ticket only once they accepted: it is checked before
    -- paying, and is personal until then.
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then nullif(t.ticket_receipt_path, '') end,
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then t.booking_reference end,
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
  from nata.delivery_requests r
  join nata.trips t      on t.id  = r.trip_id
  join nata.profiles p   on p.id  = t.traveler_id
  join nata.cities dc    on dc.id = t.departure_city_id
  join nata.cities ac    on ac.id = t.arrival_city_id
  left join nata.request_recipients rr on rr.request_id = r.id
  where auth.uid() is not null
    and r.sender_id = auth.uid()
  order by r.created_at desc;
$$;

revoke all on function public.list_my_sent_requests() from public;
grant execute on function public.list_my_sent_requests() to authenticated;
