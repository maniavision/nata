-- Prices are whole dollars, always rounded up.
--
-- Run AFTER 20240127_cancel_delivery_requests.sql. Safe to re-run.
--
--   * nata.delivery_cost_usd: the same formula, then rounded up to a whole
--     dollar (the formula is first rounded to cents, as before, so 36.00
--     stays 36 and 36.25 becomes 37).
--   * nata.platform_fee_for: 10% of the cost, rounded up to a whole dollar.
--   * nata.cancellation_fee_for: 10% of the total, rounded up to a whole
--     dollar.
--
-- create_delivery_request and update_delivery_request call these, so new and
-- edited requests get whole prices without changing those functions. The app
-- does the same sums (lib/services/delivery_pricing.dart), so the total the
-- sender is shown matches and no 'nata:price_changed' is raised.
-- Requests already saved keep the price they were made with.

create or replace function nata.delivery_cost_usd(
  distance_km double precision,
  hours       integer,
  weight_kg   numeric
)
returns numeric
language plpgsql
immutable
as $$
begin
  if distance_km < 0 then raise exception 'nata:distance_invalid'; end if;
  if weight_kg   < 0 then raise exception 'nata:weight_invalid';   end if;
  if hours       < 24 then raise exception 'nata:hours_invalid';   end if;

  return ceil(
           round(
             5.00
             + distance_km::numeric * 0.0123456789
             + weight_kg * 3.00
             + round(750.00 / hours, 4),
             2));
end;
$$;

create or replace function nata.platform_fee_for(traveler_price numeric)
returns numeric
language sql
immutable
as $$ select ceil(traveler_price * 0.10); $$;

create or replace function nata.cancellation_fee_for(p_status text, p_total numeric)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_status = 'pending'               then 0::numeric
    when p_status in ('accepted', 'paid')   then ceil(coalesce(p_total, 0) * 0.10)
    else null  -- cannot be cancelled
  end;
$$;

-- Check (run after): every row should say ok = true. Same values as the
-- app's unit tests.
--
--   select expected, nata.delivery_cost_usd(d, h, w) as got,
--          nata.delivery_cost_usd(d, h, w) = expected as ok
--   from (values
--     (0::double precision,      24, 0::numeric,    37::numeric),  -- 36.25
--     (100,                      24, 1,             41),           -- 40.48
--     (5000,                     24, 0.9,          101),           -- 100.68
--     (5000,                    720, 0.9,           71),           -- 70.47
--     (20000,                    24, 10,           314)            -- 313.16
--   ) as t(d, h, w, expected);
--
--   select nata.platform_fee_for(37) = 4, nata.platform_fee_for(30) = 3,
--          nata.cancellation_fee_for('accepted', 111) = 12;
