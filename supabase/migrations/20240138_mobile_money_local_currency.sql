-- Mobile money in the wallet's own currency.
--
-- Run AFTER 20240137_flutterwave_payments.sql. Safe to re-run.
--
-- A mobile money wallet can only be charged in its country's currency (M-Pesa
-- in KES, MTN Ghana in GHS, Orange Money Senegal in XOF...), while a request's
-- price is fixed in the sender's currency (USD, EUR, GBP or XOF). So when the
-- sender pays with mobile money, the fixed price is converted at payment time
-- into the currency of the wallet's country (nata.countries.currency_code),
-- at the latest rate, rounded up to a whole amount. The escrow keeps the fixed
-- price as well (payments.base_amount / base_currency).
--
--   * nata.refresh_exchange_rates(): now keeps a rate for every currency in
--     nata.countries, not only the app's.
--   * public.mobile_money_options(p_request_id): for the sender, each country
--     whose mobile money Flutterwave takes, with the amount it would charge
--     and which country to suggest (profile country, else the phone number's).
--   * nata.mobile_money_charge(p_request_id, p_country): the amount to charge,
--     for the create-payment edge function.

-- -----------------------------------------------------------------------------
-- 1. Rates for every country's currency
-- -----------------------------------------------------------------------------
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

  -- The app's currencies, and every country's (for mobile money).
  for cur in
    select distinct upper(btrim(c)) from (
      select unnest(array['EUR', 'GBP', 'XOF', 'XAF']) as c
      union
      select currency_code::text from nata.countries
       where currency_code is not null
    ) x
    where upper(btrim(c)) <> 'USD'
  loop
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

revoke all on function nata.refresh_exchange_rates() from public;

-- Fill the new rates now rather than waiting for the next run.
select nata.refresh_exchange_rates();

-- -----------------------------------------------------------------------------
-- 2. What a payment records when it was converted
-- -----------------------------------------------------------------------------
alter table nata.payments
  -- The price fixed when the traveler accepted, before conversion.
  add column if not exists base_amount    numeric,
  add column if not exists base_currency  char(3),
  -- The country of the mobile money wallet.
  add column if not exists country_code   char(2);

-- -----------------------------------------------------------------------------
-- 3. Converting
-- -----------------------------------------------------------------------------
-- The currencies Flutterwave takes mobile money in.
create or replace function nata.mobile_money_currencies()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['KES', 'GHS', 'UGX', 'RWF', 'ZMW', 'TZS', 'XOF', 'XAF'];
$$;

-- Units of [p_currency] per US dollar, if the rate is recent (2 days).
create or replace function nata.recent_rate(p_currency text)
returns numeric
language sql
stable
set search_path = ''
as $$
  select case when upper(p_currency) = 'USD' then 1::numeric
              else (select e.per_usd from nata.exchange_rates e
                     where e.currency = upper(p_currency)
                       and e.updated_at > now() - interval '2 days'
                       and e.per_usd > 0)
         end;
$$;

-- The amount to charge in the currency of [p_country]'s mobile money for the
-- request's fixed price. Raises nata:mobile_money_unavailable when that
-- country's mobile money isn't supported, nata:rate_unavailable without a
-- recent rate, nata:request_not_payable when there is no fixed price.
drop function if exists nata.mobile_money_charge(uuid, text);

create or replace function nata.mobile_money_charge(p_request_id uuid, p_country text)
returns table (
  currency       text,
  amount         numeric,
  base_amount    numeric,
  base_currency  text,
  country_code   text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  req       record;
  local_cur text;
  from_rate numeric;
  to_rate   numeric;
begin
  select r.display_total, r.display_currency into req
    from nata.delivery_requests r where r.id = p_request_id;
  if not found or req.display_total is null or req.display_currency is null then
    raise exception 'nata:request_not_payable';
  end if;

  select upper(btrim(c.currency_code::text)) into local_cur
    from nata.countries c where c.iso_code = upper(btrim(p_country));
  if local_cur is null or not (local_cur = any (nata.mobile_money_currencies())) then
    raise exception 'nata:mobile_money_unavailable';
  end if;

  if local_cur = upper(btrim(req.display_currency::text)) then
    return query select local_cur, req.display_total, req.display_total,
                        upper(btrim(req.display_currency::text)), upper(btrim(p_country));
    return;
  end if;

  from_rate := nata.recent_rate(btrim(req.display_currency::text));
  to_rate := nata.recent_rate(local_cur);
  if from_rate is null or to_rate is null then
    raise exception 'nata:rate_unavailable';
  end if;

  return query select local_cur,
                      ceil(req.display_total / from_rate * to_rate),
                      req.display_total,
                      upper(btrim(req.display_currency::text)),
                      upper(btrim(p_country));
end;
$$;

revoke all on function nata.mobile_money_charge(uuid, text) from public;
revoke all on function nata.mobile_money_charge(uuid, text) from anon, authenticated;
grant execute on function nata.mobile_money_charge(uuid, text) to service_role;

-- -----------------------------------------------------------------------------
-- 4. The sender's choices at checkout
-- -----------------------------------------------------------------------------
drop function if exists public.mobile_money_options(uuid);

create or replace function public.mobile_money_options(p_request_id uuid)
returns table (
  country_code  text,
  country_name  text,
  currency      text,
  amount        numeric,
  suggested     boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid        uuid := auth.uid();
  home       text;
  phone      text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (select 1 from nata.delivery_requests r
                  where r.id = p_request_id and r.sender_id = uid
                    and r.status = 'accepted' and r.display_total is not null) then
    raise exception 'nata:request_not_payable';
  end if;

  -- The country to suggest: the profile's, else the phone number's.
  select upper(btrim(p.country_of_residence::text)) into home
    from nata.profiles p where p.id = uid;
  if home is null or home = '' then
    select regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g') into phone
      from auth.users u where u.id = uid;
    if phone <> '' then
      select c.iso_code::text into home
        from nata.countries c
       where regexp_replace(coalesce(c.phone_code, ''), '[^0-9]', '', 'g') <> ''
         and phone like regexp_replace(c.phone_code, '[^0-9]', '', 'g') || '%'
       order by length(regexp_replace(c.phone_code, '[^0-9]', '', 'g')) desc
       limit 1;
    end if;
  end if;

  -- Countries are filtered first, so one without a rate can't fail the rest.
  return query
    with eligible as materialized (
      select c.iso_code::text as iso, c.name
        from nata.countries c
       where upper(btrim(c.currency_code::text)) = any (nata.mobile_money_currencies())
         and nata.recent_rate(btrim(c.currency_code::text)) is not null
    )
    select e.iso,
           e.name,
           m.currency,
           m.amount,
           e.iso = coalesce(home, '')
      from eligible e
      cross join lateral nata.mobile_money_charge(p_request_id, e.iso) m
     order by e.name;
end;
$$;

revoke all on function public.mobile_money_options(uuid) from public;
grant execute on function public.mobile_money_options(uuid) to authenticated;
