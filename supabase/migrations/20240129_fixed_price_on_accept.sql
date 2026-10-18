-- The price a sender pays is an estimate until the traveler accepts; then it
-- is fixed in the sender's currency.
--
-- Run AFTER 20240128_whole_prices.sql. Safe to re-run.
--
-- Prices are worked out and stored in US dollars (traveler_price,
-- platform_fee, total_amount). Before the traveler answers, the app shows them
-- in the sender's currency at today's rate, as an estimate. When the traveler
-- accepts, the amounts are converted once, at that day's rate, rounded up to
-- whole amounts, and stored: from then on they never change.
--
--   * nata.exchange_rates: units of each currency per US dollar. Written only
--     by nata.refresh_exchange_rates() on a schedule
--     (20240131_scheduled_jobs_and_cleanup.sql).
--   * nata.delivery_requests:
--       display_currency          the sender's currency, recorded when the
--                                 request is created (from user_settings)
--       exchange_rate             the rate used when the price was fixed
--       display_cost / display_fee / display_total
--                                 the fixed price in display_currency
--       display_cancellation_fee  the cancellation fee in display_currency
--       price_fixed_at            when the traveler accepted
--   * public.accept_delivery_request(p_id): the trip's traveler accepts a
--     pending request; the price is fixed in the same step. Refuses with
--     'nata:rate_unavailable' if there is no rate from the last 48 hours.
--   * public.cancel_delivery_request: also records the fee in the sender's
--     currency once the price is fixed.
--   * public.list_my_sent_requests(): also returns the fixed price.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Exchange rates
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists nata.exchange_rates (
  currency    char(3)        primary key check (currency ~ '^[A-Z]{3}$'),
  per_usd     numeric(18, 8) not null check (per_usd > 0),
  updated_at  timestamptz    not null default now()
);

alter table nata.exchange_rates enable row level security;

drop policy if exists "Anyone signed in can read exchange rates" on nata.exchange_rates;
create policy "Anyone signed in can read exchange rates"
  on nata.exchange_rates for select
  to authenticated
  using (true);
-- No insert/update policy: only nata.refresh_exchange_rates() writes.

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. The fixed price on the request
-- ─────────────────────────────────────────────────────────────────────────────
alter table nata.delivery_requests
  add column if not exists display_currency         char(3),
  add column if not exists exchange_rate            numeric(18, 8),
  add column if not exists display_cost             numeric(14, 2),
  add column if not exists display_fee              numeric(14, 2),
  add column if not exists display_total            numeric(14, 2),
  add column if not exists display_cancellation_fee numeric(14, 2),
  add column if not exists price_fixed_at           timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'delivery_requests_display_currency_check') then
    alter table nata.delivery_requests
      add constraint delivery_requests_display_currency_check
      check (display_currency ~ '^[A-Z]{3}$');
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'delivery_requests_display_total_matches_check') then
    alter table nata.delivery_requests
      add constraint delivery_requests_display_total_matches_check
      check (display_total is null or display_total = display_cost + display_fee);
  end if;
end $$;

-- The sender's currency when the request is made (they pick it on the first
-- screen; it is saved to user_settings when they sign in).
create or replace function nata.set_request_display_currency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.display_currency is null then
    select upper(btrim(s.currency_code))
      into new.display_currency
      from nata.user_settings s
     where s.user_id = new.sender_id;
    if new.display_currency is null or new.display_currency !~ '^[A-Z]{3}$' then
      new.display_currency := 'USD';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists set_request_display_currency on nata.delivery_requests;
create trigger set_request_display_currency
  before insert on nata.delivery_requests
  for each row execute function nata.set_request_display_currency();

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Accepting fixes the price
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists public.accept_delivery_request(uuid);

create or replace function public.accept_delivery_request(p_id uuid)
returns table (
  display_currency text,
  exchange_rate    numeric,
  display_cost     numeric,
  display_fee      numeric,
  display_total    numeric
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  uid   uuid := auth.uid();
  req   record;
  cur   text;
  rate  numeric;
  cost  numeric;
  fee   numeric;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.expires_at, r.traveler_price, r.platform_fee,
         coalesce(r.display_currency, 'USD') as cur, t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_id
   for update of r;

  if not found or req.traveler_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'pending'
     or (req.expires_at is not null and req.expires_at < now()) then
    raise exception 'nata:request_not_pending';
  end if;

  cur := req.cur;
  if cur = 'USD' then
    rate := 1;
  else
    select x.per_usd into rate
      from nata.exchange_rates x
     where x.currency = cur
       and x.updated_at > now() - interval '48 hours';
    if rate is null then
      raise exception 'nata:rate_unavailable';
    end if;
  end if;

  -- Each line converted and rounded up, as the app shows it; the total is
  -- their sum.
  cost := ceil(req.traveler_price * rate);
  fee  := ceil(req.platform_fee * rate);

  update nata.delivery_requests r
     set status           = 'accepted',
         responded_at     = now(),
         display_currency = cur,
         exchange_rate    = rate,
         display_cost     = cost,
         display_fee      = fee,
         display_total    = cost + fee,
         price_fixed_at   = now()
   where r.id = p_id;

  return query select cur, rate, cost, fee, cost + fee;
end;
$$;

revoke all on function public.accept_delivery_request(uuid) from public;
grant execute on function public.accept_delivery_request(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Cancelling records the fee in the sender's currency too
--    Same as in 20240127_cancel_delivery_requests.sql, plus
--    display_cancellation_fee.
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
  select r.id, r.status, r.total_amount, r.cancellation_fee, r.cancelled_at,
         r.display_total
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
     set status                   = 'cancelled',
         cancellation_fee         = fee,
         -- Once the price is fixed, the fee is 10% of the fixed price in the
         -- sender's currency, rounded up.
         display_cancellation_fee = case
           when fee > 0 and req.display_total is not null
             then ceil(req.display_total * 0.10)
           when req.display_total is not null then 0
         end,
         cancelled_at             = now()
   where id = p_id;

  return fee;
end;
$$;

revoke all on function public.cancel_delivery_request(uuid, numeric) from public;
grant execute on function public.cancel_delivery_request(uuid, numeric) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. The sender's requests, with the fixed price
--    Same as in 20240127_cancel_delivery_requests.sql plus the display_*
--    columns and price_fixed_at.
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Keeping the rates fresh
-- ─────────────────────────────────────────────────────────────────────────────
-- The rates are fetched by the database itself every 6 hours: see
-- 20240131_scheduled_jobs_and_cleanup.sql.
