-- The traveler sees the recipient's name, never their phone number.
--
-- Run AFTER 20240181_recipient_link.sql. Safe to re-run.
--
-- Until now an accepted request showed the traveler the recipient's name
-- and phone. Now the traveler only gets the name: they write to the
-- recipient from the delivery task, and the recipient answers from the
-- private link texted to them (20240181), so neither sees the other's
-- number.
--
--   * public.list_incoming_requests(): recipient_phone is always null.
--     Same as in 20240179_sender_reviews.sql otherwise; the column stays so
--     older app versions keep working.
--   * nata.request_recipients: the "traveler reads recipient after
--     accepting" policy is dropped, so a traveler can't read the row (and
--     its phone) directly either. The sender still manages it.

drop policy if exists "traveler reads recipient after accepting"
  on nata.request_recipients;

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
    -- Never the recipient's phone: the traveler writes to them from the
    -- app, and they answer from their link (20240181).
    null::text,
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
