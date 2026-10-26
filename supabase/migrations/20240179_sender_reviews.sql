-- The traveler reviews the sender once the item is delivered.
--
-- Run AFTER 20240178_emergency_contact_required.sql. Safe to re-run.
--
-- Senders already rate travelers (20240135). Now the traveler of a delivered
-- request rates its sender too: 1-5 stars, what stood out, and an optional
-- comment. A member's rating as a traveler and as a sender are kept apart.
--
--   * nata.reviews.reviewee_role: 'traveler' (by the sender, as before) or
--     'sender' (by the traveler).
--   * nata.profiles.sender_avg_rating: the member's average as a sender
--     (avg_rating stays their rating as a traveler).
--   * public.submit_sender_review(...): the traveler of a delivered request
--     rates its sender. Tags: clear_instructions, well_packed,
--     on_time_pickup, friendly, carry_again.
--   * public.submit_traveler_review(...) and public.list_traveler_reviews(...)
--     count only reviews of the member as a traveler.
--   * public.list_incoming_requests(): also returns the sender's rating as a
--     sender and whether the traveler has reviewed them.

alter table nata.reviews
  add column if not exists reviewee_role text not null default 'traveler';
alter table nata.reviews
  drop constraint if exists reviews_reviewee_role_check;
alter table nata.reviews
  add constraint reviews_reviewee_role_check
    check (reviewee_role in ('traveler', 'sender'));

alter table nata.profiles
  add column if not exists sender_avg_rating numeric(2, 1);

-- -----------------------------------------------------------------------------
-- 1. Reviewing the sender
-- -----------------------------------------------------------------------------
drop function if exists public.submit_sender_review(uuid, integer, text[], text);

create or replace function public.submit_sender_review(
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

  select r.id, r.status, r.sender_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id and t.traveler_id = uid;

  if not found then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'delivered' then
    raise exception 'nata:request_not_delivered';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'nata:review_invalid';
  end if;
  if not v_tags <@ array['clear_instructions', 'well_packed', 'on_time_pickup',
                       'friendly', 'carry_again']
     or char_length(v_comment) > 1000 then
    raise exception 'nata:review_invalid';
  end if;
  if exists (select 1 from nata.reviews v
              where v.request_id = p_request_id and v.reviewer_id = uid) then
    raise exception 'nata:already_reviewed';
  end if;

  insert into nata.reviews
    (request_id, reviewer_id, reviewee_id, reviewee_role, rating, comment, tags)
  values
    (p_request_id, uid, req.sender_id, 'sender', p_rating, v_comment, v_tags)
  returning id into new_id;

  update nata.profiles p
     set sender_avg_rating = (select round(avg(v.rating)::numeric, 1)
                                from nata.reviews v
                               where v.reviewee_id = req.sender_id
                                 and v.reviewee_role = 'sender')
   where p.id = req.sender_id;

  return new_id;
end;
$$;

revoke all on function public.submit_sender_review(uuid, integer, text[], text) from public;
grant execute on function public.submit_sender_review(uuid, integer, text[], text) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. A traveler's rating counts only reviews of them as a traveler
--    Same as in 20240135_reviews.sql, with reviewee_role.
-- -----------------------------------------------------------------------------
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

  insert into nata.reviews
    (request_id, reviewer_id, reviewee_id, reviewee_role, rating, comment, tags)
  values
    (p_request_id, uid, req.traveler_id, 'traveler', p_rating, v_comment, v_tags)
  returning id into new_id;

  update nata.profiles p
     set avg_rating = (select round(avg(v.rating)::numeric, 1)
                         from nata.reviews v
                        where v.reviewee_id = req.traveler_id
                          and v.reviewee_role = 'traveler')
   where p.id = req.traveler_id;

  return new_id;
end;
$$;

revoke all on function public.submit_traveler_review(uuid, integer, text[], text) from public;
grant execute on function public.submit_traveler_review(uuid, integer, text[], text) to authenticated;

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
     and v.reviewee_role = 'traveler'
     and auth.uid() is not null
   order by v.created_at desc
   limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.list_traveler_reviews(uuid, integer) from public;
grant execute on function public.list_traveler_reviews(uuid, integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. The traveler's requests, with the sender's rating and the review
--    Same as in 20240139_delivery_handover.sql plus sender_rating and
--    sender_reviewed.
-- -----------------------------------------------------------------------------
drop function if exists public.list_incoming_requests();

create or replace function public.list_incoming_requests()
returns table (
  request_id          uuid,
  status              text,
  created_at          timestamptz,
  expires_at          timestamptz,
  responded_at        timestamptz,
  payout_usd          numeric,
  items               jsonb,
  item_weight_kg      numeric,
  item_size           text,
  item_size_class     text,
  photo_paths         text[],
  sender_id           uuid,
  sender_first_name   text,
  sender_last_name    text,
  sender_avatar_path  text,
  sender_verified     boolean,
  sender_deliveries   integer,
  recipient_name      text,
  recipient_phone     text,
  trip_id             uuid,
  departure_city      text,
  departure_country   text,
  arrival_city        text,
  arrival_country     text,
  departure_date      date,
  arrival_date        date,
  picked_up_at        timestamptz,
  delivered_at        timestamptz,
  code_attempts_left  integer,
  sender_rating       numeric,
  sender_reviewed     boolean
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
    r.expires_at,
    r.responded_at,
    r.traveler_price,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'name', i.name, 'category', i.category,
                'description', i.description) order by i.position)
         from nata.request_items i where i.request_id = r.id),
      '[]'::jsonb),
    r.item_weight_kg,
    r.item_size,
    r.item_size_class,
    coalesce(
      (select array_agg(ph.photo_path order by ph.photo_path)
         from nata.request_photos ph
        where ph.request_id = r.id and ph.type = 'item'),
      '{}'::text[]),
    r.sender_id,
    sp.first_name,
    sp.last_name,
    sp.avatar_path,
    coalesce(sp.verification_status = 'verified', false),
    (select count(*)::integer from nata.delivery_requests d
      where d.sender_id = r.sender_id and d.status = 'delivered'),
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then rr.name end,
    case when r.status in ('accepted', 'paid', 'handed_off', 'delivered')
         then rr.phone end,
    t.id,
    dc.name,
    dc.country_code::text,
    ac.name,
    ac.country_code::text,
    t.departure_date,
    t.arrival_date,
    r.picked_up_at,
    r.delivered_at,
    greatest(0, 5 - coalesce(r.delivery_code_attempts, 0)),
    sp.sender_avg_rating,
    exists (select 1 from nata.reviews v
             where v.request_id = r.id and v.reviewer_id = auth.uid())
  from nata.delivery_requests r
  join nata.trips t     on t.id  = r.trip_id
  join nata.profiles sp on sp.id = r.sender_id
  join nata.cities dc   on dc.id = t.departure_city_id
  join nata.cities ac   on ac.id = t.arrival_city_id
  left join nata.request_recipients rr on rr.request_id = r.id
  where auth.uid() is not null
    and t.traveler_id = auth.uid()
    and (
      r.status in ('pending', 'accepted', 'paid', 'handed_off')
      or (r.status = 'delivered'
          and coalesce(r.delivered_at, r.updated_at) > now() - interval '30 days')
    )
  order by r.created_at desc;
$$;

revoke all on function public.list_incoming_requests() from public;
grant execute on function public.list_incoming_requests() to authenticated;
