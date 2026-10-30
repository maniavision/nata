-- Carrying limits in the traveler's own currency, by where they live.
--
-- Run AFTER 20240196_stripe_customers.sql. Safe to re-run.
--
-- The limits (20240194) were the same everywhere, in US dollars. They now
-- follow the traveler's country of residence, in round amounts of its
-- currency, and are higher where incomes are:
--
--   lives in                  level 1    level 2    level 3
--   United States             $200       $600       $2,000
--   United Kingdom            £200       £600       £2,000
--   rest of Europe            €200       €600       €2,000
--   XAF / XOF countries       60,000     180,000    600,000  (local currency)
--   anywhere else / unknown   $100       $300       $1,000
--
-- The levels themselves don't change: level 2 after 3 deliveries, level 3
-- after 10 rated 4.5 or more. nata.carry_limit also returns the currency,
-- the limit and next limit in it, and the three amounts (limit_usd stays,
-- converted at today's rate, for the comparisons in dollars). A request's
-- deposit (20240195) is due when its declared value, converted into the
-- limit's currency, is above the limit.

-- -----------------------------------------------------------------------------
-- 1. The amounts for a traveler
-- -----------------------------------------------------------------------------
create or replace function nata.carry_tiers(p_user uuid)
returns table (currency text, tiers numeric[])
language sql
stable
security definer
set search_path = ''
as $$
  select
    case
      when c.iso_code = 'US' then 'USD'
      when c.iso_code = 'GB' then 'GBP'
      when c.continent = 'EU' then 'EUR'
      when c.currency_code in ('XAF', 'XOF') then c.currency_code::text
      else 'USD'
    end,
    case
      when c.iso_code in ('US', 'GB') or c.continent = 'EU'
        then array[200, 600, 2000]::numeric[]
      when c.currency_code in ('XAF', 'XOF')
        then array[60000, 180000, 600000]::numeric[]
      else array[100, 300, 1000]::numeric[]
    end
  from (select 1) one
  left join nata.profiles p on p.id = p_user
  left join nata.countries c
    on c.iso_code = upper(btrim(p.country_of_residence::text));
$$;

revoke all on function nata.carry_tiers(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. The limit
-- -----------------------------------------------------------------------------
drop function if exists public.my_carry_limit();
drop function if exists nata.carry_limit(uuid);

create function nata.carry_limit(p_user uuid)
returns table (
  level              integer,
  limit_usd          numeric,
  delivered          integer,
  rating             numeric,
  next_limit_usd     numeric,
  deliveries_needed  integer,
  rating_needed      numeric,
  currency           text,
  limit_amount       numeric,
  next_limit_amount  numeric,
  tiers              numeric[]
)
language sql
stable
security definer
set search_path = ''
as $$
  with s as (
    select
      (select count(*)::integer
         from nata.delivery_requests r
         join nata.trips t on t.id = r.trip_id
        where t.traveler_id = p_user and r.status = 'delivered') as delivered,
      (select p.avg_rating from nata.profiles p where p.id = p_user) as rating
  ),
  lv as (
    select s.*,
           case when s.delivered >= 10 and coalesce(s.rating, 0) >= 4.5 then 3
                when s.delivered >= 3 then 2
                else 1 end as level
      from s
  ),
  t as (
    select ct.currency, ct.tiers,
           case when ct.currency = 'USD' then 1 else nata.recent_rate(ct.currency) end as rate
      from nata.carry_tiers(p_user) ct
  )
  select
    lv.level,
    -- In dollars; the dollar amounts when the rate isn't known.
    coalesce(round(t.tiers[lv.level] / nullif(t.rate, 0), 2),
             (array[100, 300, 1000]::numeric[])[lv.level]),
    lv.delivered,
    lv.rating,
    case when lv.level < 3
         then coalesce(round(t.tiers[lv.level + 1] / nullif(t.rate, 0), 2),
                       (array[100, 300, 1000]::numeric[])[lv.level + 1]) end,
    case lv.level when 1 then 3 - lv.delivered
                  when 2 then greatest(0, 10 - lv.delivered)
                  else 0 end,
    case when lv.level = 2 then 4.5 end::numeric,
    t.currency,
    t.tiers[lv.level],
    case when lv.level < 3 then t.tiers[lv.level + 1] end,
    t.tiers
  from lv, t;
$$;

revoke all on function nata.carry_limit(uuid) from public, anon, authenticated;
grant execute on function nata.carry_limit(uuid) to service_role;

create function public.my_carry_limit()
returns table (
  level              integer,
  limit_usd          numeric,
  delivered          integer,
  rating             numeric,
  next_limit_usd     numeric,
  deliveries_needed  integer,
  rating_needed      numeric,
  currency           text,
  limit_amount       numeric,
  next_limit_amount  numeric,
  tiers              numeric[]
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from nata.carry_limit(auth.uid()) where auth.uid() is not null;
$$;

revoke all on function public.my_carry_limit() from public, anon;
grant execute on function public.my_carry_limit() to authenticated;

-- -----------------------------------------------------------------------------
-- 3. When a deposit is due
-- -----------------------------------------------------------------------------
-- The declared value, converted into the limit's currency, above the limit.
-- A value whose rate is unknown counts as above it.
drop function if exists nata.deposit_due(uuid);

create function nata.deposit_due(p_request_id uuid)
returns table (required boolean, amount numeric, currency text,
               declared_usd numeric, limit_usd numeric,
               limit_amount numeric, limit_currency text)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  req    record;
  lim    record;
  usd    numeric;
  local  numeric;
begin
  select r.declared_value, upper(btrim(r.declared_currency::text)) as cur,
         t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id;
  if not found or req.declared_value is null or req.declared_value <= 0 then
    return query select false, null::numeric, null::text, null::numeric,
                        null::numeric, null::numeric, null::text;
    return;
  end if;
  req.cur := coalesce(req.cur, 'USD');
  select * into lim from nata.carry_limit(req.traveler_id);

  usd := case when req.cur = 'USD' then req.declared_value
              else nata.to_usd(req.declared_value, req.cur, now()) end;
  local := case
    when req.cur = lim.currency then req.declared_value
    when lim.currency = 'USD' then usd
    else usd * nata.recent_rate(lim.currency) end;

  return query select local is null or local > lim.limit_amount,
                      req.declared_value, req.cur, usd, lim.limit_usd,
                      lim.limit_amount, lim.currency;
end;
$fn$;

revoke all on function nata.deposit_due(uuid) from public, anon, authenticated;
grant execute on function nata.deposit_due(uuid) to service_role;

-- What request_deposit tells the app now includes the limit in the
-- traveler's currency.
create or replace function public.request_deposit(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  req  record;
  due  record;
  pay  nata.payments%rowtype;
  st   text := 'none';
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  select r.id, r.sender_id, t.traveler_id into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id;
  if not found or uid not in (req.sender_id, req.traveler_id) then
    raise exception 'nata:request_not_found';
  end if;

  select * into due from nata.deposit_due(p_request_id);
  select p.* into pay from nata.payments p
   where p.request_id = p_request_id and p.purpose = 'deposit'
     and p.status <> 'failed'
   order by p.created_at desc limit 1;
  if found then
    st := case
      when pay.status = 'released' then 'paid_to_sender'
      when pay.status = 'refunded' then 'refunded'
      when pay.refund_status is not null or pay.needs_refund then 'refunding'
      when pay.status = 'held' then 'held'
      else 'pending' end;
  end if;

  return jsonb_build_object(
    'required', coalesce(due.required, false),
    'amount', due.amount,
    'currency', due.currency,
    'limit_usd', due.limit_usd,
    -- The limit as the traveler sees it, in their own currency (20240197).
    'limit_amount', due.limit_amount,
    'limit_currency', due.limit_currency,
    'status', st,
    'paid_amount', pay.amount,
    'paid_currency', pay.currency,
    'method', pay.method,
    -- How it is paid: the request's rule (20240173), mobile money or card.
    'kind', nata.checkout_kind(p_request_id),
    'tx_ref', case when uid = req.traveler_id then pay.tx_ref end);
end;
$$;

revoke all on function public.request_deposit(uuid) from public, anon;
grant execute on function public.request_deposit(uuid) to authenticated;
