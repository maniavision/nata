-- Checkout: the sender also checks the traveler's ID photo before paying.
--
-- Run AFTER 20240132_checkout_ticket.sql. Safe to re-run.
--
-- The sender sees only the face photo on the traveler's ID and the name that
-- was checked against the ID, never the ID page itself (passport number,
-- date of birth...). The photo comes from the traveler-id-photo edge
-- function, which checks who is asking.
--
--   * nata.delivery_requests.id_checked_at: when the sender confirmed they
--     checked the ID ("I've checked this ID"); kept as evidence for disputes.
--   * public.confirm_id_checked(p_id): records it.
--   * public.list_my_sent_requests(): also returns id_checked_at and
--     traveler_verified.

alter table nata.delivery_requests
  add column if not exists id_checked_at timestamptz;

-- "I've checked this ID": same rules as confirm_ticket_checked.
drop function if exists public.confirm_id_checked(uuid);

create or replace function public.confirm_id_checked(p_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid      uuid := auth.uid();
  req      record;
  checked  timestamptz;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.id_checked_at
    into req
    from nata.delivery_requests r
   where r.id = p_id and r.sender_id = uid
   for update;

  if not found then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'accepted' then
    raise exception 'nata:request_not_payable';
  end if;

  -- The first time counts; a retry changes nothing.
  checked := req.id_checked_at;
  if checked is null then
    checked := now();
    update nata.delivery_requests
       set id_checked_at = checked
     where id = p_id;
  end if;

  return checked;
end;
$$;

revoke all on function public.confirm_id_checked(uuid) from public;
grant execute on function public.confirm_id_checked(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The sender's requests, with the ID check
--    Same as in 20240132_checkout_ticket.sql plus id_checked_at and
--    traveler_verified.
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
