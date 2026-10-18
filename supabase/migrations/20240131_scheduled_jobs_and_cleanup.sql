-- Scheduled jobs (exchange rates, request expiry) and two leftovers removed.
--
-- Run AFTER 20240130_chat_after_payment.sql. Safe to re-run.
--
--   * Exchange rates are fetched by the database itself (the http extension)
--     every 6 hours, so accepting a request can fix its price in the sender's
--     currency. This replaces the refresh-exchange-rates edge function: no
--     deployment and no service key in a scheduled job.
--   * nata.expire_stale_requests() (already in the database) runs every 10
--     minutes: pending requests the traveler did not answer, and accepted
--     requests not paid in time (set_request_expiry gives 24 hours), expire.
--   * The create_request_conversation trigger is removed: it opened a
--     conversation as soon as a request was sent. Conversations now open when
--     the request is paid (open_conversation_on_payment, 20240130).
--   * The old create_delivery_request (single item, 12 arguments) is removed.
--     The app uses the items version, which also enforces the 5-per-city
--     limit.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Extensions
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists http with schema extensions;
create extension if not exists pg_cron;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Exchange rates, fetched by the database
-- ─────────────────────────────────────────────────────────────────────────────
-- Units of each currency per US dollar, from the same source the app uses for
-- its estimates (https://open.er-api.com/v6/latest/USD). Returns how many
-- currencies were updated; 0 if the source could not be read (the previous
-- rates are kept).
create or replace function nata.refresh_exchange_rates()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  resp     record;
  body     jsonb;
  cur      text;
  rate     numeric;
  updated  integer := 0;
begin
  begin
    select * into resp
      from extensions.http_get('https://open.er-api.com/v6/latest/USD');
  exception when others then
    raise warning 'refresh_exchange_rates: source unreachable: %', sqlerrm;
    return 0;
  end;

  if resp.status <> 200 then
    raise warning 'refresh_exchange_rates: source answered %', resp.status;
    return 0;
  end if;

  body := resp.content::jsonb;
  if coalesce(body ->> 'result', '') <> 'success' then
    raise warning 'refresh_exchange_rates: source gave no rates';
    return 0;
  end if;

  -- The currencies the app offers, plus XAF (same value as XOF).
  foreach cur in array array['EUR', 'GBP', 'XOF', 'XAF'] loop
    rate := (body -> 'rates' ->> cur)::numeric;
    if rate is not null and rate > 0 then
      insert into nata.exchange_rates (currency, per_usd, updated_at)
      values (cur, rate, now())
      on conflict (currency) do update
        set per_usd = excluded.per_usd, updated_at = excluded.updated_at;
      updated := updated + 1;
    end if;
  end loop;

  return updated;
end;
$$;

-- Only the scheduler (and the dashboard) runs it, never the app.
revoke all on function nata.refresh_exchange_rates() from public;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Schedules (re-running replaces them)
-- ─────────────────────────────────────────────────────────────────────────────
select cron.schedule(
  'refresh-exchange-rates', '0 */6 * * *',
  $job$ select nata.refresh_exchange_rates(); $job$
);

select cron.schedule(
  'expire-stale-requests', '*/10 * * * *',
  $job$ select nata.expire_stale_requests(); $job$
);

-- Fill the rates now rather than waiting for the first run.
select nata.refresh_exchange_rates();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Leftovers removed
-- ─────────────────────────────────────────────────────────────────────────────
drop trigger if exists create_request_conversation on nata.delivery_requests;
drop function if exists nata.create_request_conversation();

drop function if exists public.create_delivery_request(
  uuid, uuid, text, text, text, numeric, text, text, text, text, text[], numeric
);

-- Check (run after):
--   select currency, per_usd, updated_at from nata.exchange_rates;
--   select jobname, schedule, active from cron.job;
