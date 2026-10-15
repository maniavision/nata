-- Senders can cancel their own requests.
--
-- Run AFTER 20240126_destination_request_limit.sql. Safe to re-run.
--
--   * Free while the traveler has not answered (pending).
--   * Once the traveler accepted (accepted or paid): a fee of 10% of the
--     request's total. Payments are not charged by the app yet, so the fee is
--     only worked out here and frozen on the request (cancellation_fee).
--   * Not possible once the parcel is with the traveler (handed_off) or the
--     request is already over (delivered, declined, expired, cancelled).
--
--   * nata.delivery_requests.cancellation_fee / cancelled_at
--   * nata.cancellation_fee_for(status, total): the rule above, in one place.
--   * public.cancel_delivery_request(p_id, p_expected_fee): cancels and
--     returns the fee. p_expected_fee is what the sender was shown: if the
--     traveler accepted in the meantime (free became paid), it refuses with
--     'nata:fee_changed' so the sender is asked again.
--   * public.list_my_sent_requests(): also returns cancellation_fee and
--     cancelled_at.

alter table nata.delivery_requests
  add column if not exists cancellation_fee numeric(10, 2),
  add column if not exists cancelled_at     timestamptz;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. The fee rule
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function nata.cancellation_fee_for(p_status text, p_total numeric)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_status = 'pending'               then 0::numeric
    when p_status in ('accepted', 'paid')   then round(coalesce(p_total, 0) * 0.10, 2)
    else null  -- cannot be cancelled
  end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Cancelling
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.cancel_delivery_request(uuid, numeric);

create or replace function public.cancel_delivery_request(
  p_id            uuid,
  p_expected_fee  numeric default null  -- the fee the sender was shown, in USD
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
  fee  numeric(10, 2);
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Locked, so the traveler accepting at the same moment waits for us (or we
  -- for them) and the fee matches the status it is based on.
  select r.id, r.status, r.total_amount, r.cancellation_fee, r.cancelled_at
    into req
    from nata.delivery_requests r
   where r.id = p_id and r.sender_id = uid
   for update;

  if not found then
    raise exception 'nata:request_not_found';
  end if;

  -- Already cancelled by the sender (a retry): nothing more to do.
  if req.status = 'cancelled' and req.cancelled_at is not null then
    return req.cancellation_fee;
  end if;

  fee := nata.cancellation_fee_for(req.status, req.total_amount);
  if fee is null then
    raise exception 'nata:request_not_cancellable';
  end if;
  if p_expected_fee is not null and abs(p_expected_fee - fee) > 0.005 then
    raise exception 'nata:fee_changed';
  end if;

  update nata.delivery_requests
     set status           = 'cancelled',
         cancellation_fee = fee,
         cancelled_at     = now()
   where id = p_id;

  return fee;
end;
$$;

revoke all on function public.cancel_delivery_request(uuid, numeric) from public;
grant execute on function public.cancel_delivery_request(uuid, numeric) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. The sender's requests, now with the cancellation
--    Same as in 20240125_edit_delivery_requests.sql plus cancellation_fee and
--    cancelled_at.
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.list_my_sent_requests();

create or replace function public.list_my_sent_requests()
returns table (
  request_id             uuid,
  status                 text,
  created_at             timestamptz,
  total_amount           numeric,
  cancellation_fee       numeric,
  cancelled_at           timestamptz,
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
