-- Senders only ever see a copy of the traveler's flight ticket with the
-- booking reference (PNR) and barcodes blurred: with the reference and the
-- traveler's last name, anyone can change or cancel the booking.
--
-- Run AFTER 20240135_reviews.sql. Safe to re-run.
--
--   * nata.trips.ticket_shared_path: the blurred copy, made by the app when
--     the trip is saved (lib/services/ticket_redaction_service.dart). It must
--     be in the traveler's own folder.
--   * Storage: senders can open the blurred copy, no longer the original.
--   * public.list_my_sent_requests(): returns the blurred copy's path,
--     whether a ticket is on file and whether there is a booking reference,
--     but not the original's path or the reference itself.

alter table nata.trips
  add column if not exists ticket_shared_path text;

alter table nata.trips
  drop constraint if exists trips_ticket_shared_path_own_folder;
alter table nata.trips
  add constraint trips_ticket_shared_path_own_folder
  check (ticket_shared_path is null
         or ticket_shared_path like traveler_id::text || '/%');

-- -----------------------------------------------------------------------------
-- 1. Senders open the blurred copy only
-- -----------------------------------------------------------------------------
drop policy if exists "Senders read the ticket of a trip they are paying for"
  on storage.objects;
create policy "Senders read the ticket of a trip they are paying for"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'trip-receipts'
    and exists (
      select 1
        from nata.trips t
        join nata.delivery_requests r on r.trip_id = t.id
       where t.ticket_shared_path = storage.objects.name
         and (storage.foldername(storage.objects.name))[1] = t.traveler_id::text
         and r.sender_id = auth.uid()
         and r.status in ('accepted', 'paid', 'handed_off', 'delivered')
    )
  );

-- -----------------------------------------------------------------------------
-- 2. The sender's requests: the blurred copy, never the reference
--    Same as in 20240135_reviews.sql, with ticket_receipt_path and
--    booking_reference replaced by ticket_on_file, ticket_shared_path and
--    has_booking_reference.
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
  -- Whether the traveler uploaded a ticket, and the copy senders may open
  -- (booking reference blurred; null when none could be made).
  ticket_on_file         boolean,
  ticket_shared_path     text,
  -- Only whether there is one: the reference itself stays private.
  has_booking_reference  boolean,
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
    coalesce(t.ticket_receipt_path, '') <> '',
    -- The ticket only once the traveler accepted: it is checked before
    -- paying. Never the original, which shows the booking reference.
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
