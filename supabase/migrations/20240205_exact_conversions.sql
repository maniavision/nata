-- Converted prices no longer gain a unit from rounding.
--
-- Run AFTER 20240204_simpler_request_form.sql. Safe to re-run.
--
-- Converted amounts are rounded up, so nobody pays less than the price. But
-- converting between two currencies at the same rate (XOF and XAF, both
-- pegged to the euro) left a tiny remainder: 1,976 XOF came out as
-- 1,976.0000000000000089 XAF and was charged as 1,977. nata.round_up first
-- drops anything past the sixth decimal, then rounds up as before. It is
-- used by mobile_money_charge, deposit_charge, naira_amount and
-- accept_delivery_request. Payments already made keep their amounts.

create or replace function nata.round_up(p_amount numeric, p_places int default 0)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select round(ceil(round(p_amount * power(10::numeric, p_places), 6))
               / power(10::numeric, p_places), p_places);
$$;

revoke all on function nata.round_up(numeric, int) from public;

CREATE OR REPLACE FUNCTION nata.mobile_money_charge(p_request_id uuid, p_country text)
 RETURNS TABLE(currency text, amount numeric, base_amount numeric, base_currency text, country_code text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  if not exists (select 1 from nata.mobile_money_networks n
                  where n.country_code = upper(btrim(p_country))) then
    raise exception 'nata:mobile_money_unavailable';
  end if;
  select upper(btrim(c.currency_code::text)) into local_cur
    from nata.countries c where c.iso_code = upper(btrim(p_country));
  if local_cur is null or local_cur = '' then
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

  -- A whole amount: most networks take no decimals.
  return query select local_cur,
                      nata.round_up(req.display_total / from_rate * to_rate),
                      req.display_total,
                      upper(btrim(req.display_currency::text)),
                      upper(btrim(p_country));
end;
$function$;

CREATE OR REPLACE FUNCTION nata.deposit_charge(p_request_id uuid, p_country text)
 RETURNS TABLE(currency text, amount numeric, base_amount numeric, base_currency text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  due       record;
  local_cur text;
  from_rate numeric;
  to_rate   numeric;
begin
  select * into due from nata.deposit_due(p_request_id);
  if due.amount is null then
    raise exception 'nata:deposit_not_due';
  end if;
  if p_country is null or btrim(p_country) = '' then
    return query select due.currency, due.amount, due.amount, due.currency;
    return;
  end if;

  if not exists (select 1 from nata.mobile_money_networks n
                  where n.country_code = upper(btrim(p_country))) then
    raise exception 'nata:mobile_money_unavailable';
  end if;
  select upper(btrim(c.currency_code::text)) into local_cur
    from nata.countries c where c.iso_code = upper(btrim(p_country));
  if local_cur is null or local_cur = '' then
    raise exception 'nata:mobile_money_unavailable';
  end if;
  if local_cur = due.currency then
    return query select local_cur, nata.round_up(due.amount), due.amount, due.currency;
    return;
  end if;

  from_rate := nata.recent_rate(due.currency);
  to_rate := nata.recent_rate(local_cur);
  if from_rate is null or to_rate is null then
    raise exception 'nata:rate_unavailable';
  end if;
  return query select local_cur, nata.round_up(due.amount / from_rate * to_rate),
                      due.amount, due.currency;
end;
$function$;

CREATE OR REPLACE FUNCTION nata.naira_amount(p_amount numeric, p_currency text)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  from_rate numeric;
  to_rate   numeric;
begin
  if upper(btrim(p_currency)) = 'NGN' then
    return nata.round_up(p_amount);
  end if;
  from_rate := nata.recent_rate(upper(btrim(p_currency)));
  to_rate := nata.recent_rate('NGN');
  if from_rate is null or to_rate is null or from_rate <= 0 then
    raise exception 'nata:rate_unavailable';
  end if;
  return nata.round_up(p_amount / from_rate * to_rate);
end;
$function$;

CREATE OR REPLACE FUNCTION public.accept_delivery_request(p_id uuid)
 RETURNS TABLE(display_currency text, exchange_rate numeric, display_cost numeric, display_fee numeric, display_total numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare
  uid   uuid := auth.uid();
  req   record;
  cur   text;
  rate  numeric;
  base  numeric;
  cost  numeric;
  fee   numeric;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.expires_at, r.traveler_price, r.platform_fee,
         r.pricing, r.currency::text as fee_cur,
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

  if req.pricing = 'flat' then
    -- The fee is in its own currency (USD, EUR or GBP): exact in that
    -- currency, else converted and rounded up.
    cost := 0;
    if cur = req.fee_cur then
      rate := 1;
      fee := req.platform_fee;
    else
      if req.fee_cur = 'USD' then
        base := 1;
      else
        select x.per_usd into base
          from nata.exchange_rates x
         where x.currency = req.fee_cur
           and x.updated_at > now() - interval '48 hours';
        if base is null then
          raise exception 'nata:rate_unavailable';
        end if;
      end if;
      fee := case when rate >= 10 then nata.round_up(req.platform_fee * rate / base)
                  else nata.round_up(req.platform_fee * rate / base, 2) end;
      rate := rate / base;
    end if;
  else
    -- Each line converted and rounded up, as the app shows it; the total is
    -- their sum.
    cost := nata.round_up(req.traveler_price * rate);
    fee  := nata.round_up(req.platform_fee * rate);
  end if;

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
$function$;
