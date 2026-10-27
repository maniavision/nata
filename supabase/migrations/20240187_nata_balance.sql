-- The Nata balance: earnings and refunds kept in Nata, spent on deliveries.
--
-- Run AFTER 20240186_recipient_in_app.sql. Safe to re-run.
--
-- No top-ups: the balance is only money Nata already owes the member.
--
--   * Earnings: the payouts of delivered requests (as before). A traveler
--     who turns on "Keep my earnings in Nata" (payout_schedule 'manual')
--     keeps them in the balance; they leave only on Withdraw.
--   * Refunds: a sender who turns on "Refunds go to my Nata balance", and
--     any payment made from the balance, are refunded into the balance at
--     once (a payout to the sender, kind 'refund'), not to the card or
--     mobile money. Refunds in the balance also leave only on Withdraw.
--   * Spending: public.pay_with_balance(request) pays an accepted request
--     from the balance when it covers the whole price. It takes from the
--     oldest payouts first (payouts.spent_amount; a payout fully used is
--     'spent', and the escrow payment it came from is released), converted
--     at the latest exchange rates, and the payment then goes through
--     nata.complete_payment like a card payment: escrow, delivery code.
--   * public.my_balance(), balance_checkout(request): what can be spent.
--   * public.set_balance_preferences(keep_earnings, refunds_to_balance).
--   * nata.claim_payouts(traveler, withdraw): leaves kept money alone
--     unless withdrawing, and sends only what wasn't spent.
--   * public.wallet_history(): refunds to the balance, and the method.

alter table nata.payouts
  add column if not exists spent_amount numeric not null default 0,
  add column if not exists kind text not null default 'earning';
alter table nata.payouts drop constraint if exists payouts_spent_check;
alter table nata.payouts add constraint payouts_spent_check
  check (spent_amount >= 0 and spent_amount <= amount);
alter table nata.payouts drop constraint if exists payouts_kind_check;
alter table nata.payouts add constraint payouts_kind_check
  check (kind in ('earning', 'refund'));
alter table nata.payouts drop constraint if exists payouts_status_check;
alter table nata.payouts add constraint payouts_status_check
  check (status in ('pending', 'processing', 'paid', 'failed', 'spent'));

alter table nata.payments drop constraint if exists payments_method_check;
alter table nata.payments add constraint payments_method_check
  check (method in ('card', 'apple_pay', 'google_pay', 'mobile_money',
                    'bank_transfer', 'balance'));

alter table nata.payment_preferences
  add column if not exists refund_to_balance boolean not null default false;

-- What a payment from the balance used, to follow the money.
create table if not exists nata.balance_spends (
  id          uuid primary key default gen_random_uuid(),
  payment_id  uuid not null references nata.payments (id) on delete restrict,
  payout_id   uuid not null references nata.payouts (id) on delete restrict,
  amount      numeric not null check (amount > 0),   -- in the payout's currency
  currency    text not null,
  created_at  timestamptz not null default now()
);
create index if not exists balance_spends_payment
  on nata.balance_spends (payment_id);
alter table nata.balance_spends enable row level security;
revoke all on nata.balance_spends from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. What's in the balance
-- -----------------------------------------------------------------------------
-- The member's payouts that can be spent: not sent, not being sent, not
-- used up.
create or replace function nata.spendable_usd(p_user uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum((po.amount - po.spent_amount)
                      / nata.recent_rate(po.currency)), 0)
    from nata.payouts po
   where po.traveler_id = p_user
     and po.status in ('pending', 'failed')
     and po.amount > po.spent_amount
     and nata.recent_rate(po.currency) is not null;
$$;
revoke all on function nata.spendable_usd(uuid)
  from public, anon, authenticated;

create or replace function public.my_balance()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'available_usd', round(nata.spendable_usd(auth.uid()), 2),
    'keep_earnings', coalesce((select pp.payout_schedule = 'manual'
                                 from nata.payment_preferences pp
                                where pp.user_id = auth.uid()), false),
    'refunds_to_balance', coalesce((select pp.refund_to_balance
                                      from nata.payment_preferences pp
                                     where pp.user_id = auth.uid()), false))
   where auth.uid() is not null;
$$;
revoke all on function public.my_balance() from public, anon;
grant execute on function public.my_balance() to authenticated;

-- What the sender has in the request's currency, and whether it covers it.
create or replace function public.balance_checkout(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid   uuid := auth.uid();
  req   record;
  cur   text;
  rate  numeric;
  have  numeric;
begin
  select r.sender_id, r.display_total, r.display_currency into req
    from nata.delivery_requests r where r.id = p_request_id;
  if uid is null or not found or req.sender_id <> uid
     or req.display_total is null then
    return null;
  end if;
  cur := coalesce(req.display_currency, 'USD');
  rate := nata.recent_rate(cur);
  if rate is null then
    return null;
  end if;
  have := floor(nata.spendable_usd(uid) * rate * 100) / 100;
  return jsonb_build_object(
    'total', req.display_total,
    'currency', cur,
    'available', have,
    'covers', have >= req.display_total);
end;
$$;
revoke all on function public.balance_checkout(uuid) from public, anon;
grant execute on function public.balance_checkout(uuid) to authenticated;

create or replace function public.set_balance_preferences(
  p_keep_earnings boolean,
  p_refunds_to_balance boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  insert into nata.payment_preferences (user_id, payout_schedule, refund_to_balance)
  values (auth.uid(),
          case when p_keep_earnings then 'manual' else 'automatic' end,
          coalesce(p_refunds_to_balance, false))
  on conflict (user_id) do update
     set payout_schedule = excluded.payout_schedule,
         refund_to_balance = excluded.refund_to_balance,
         updated_at = now();
end;
$$;
revoke all on function public.set_balance_preferences(boolean, boolean)
  from public, anon;
grant execute on function public.set_balance_preferences(boolean, boolean)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Paying from the balance
-- -----------------------------------------------------------------------------
create or replace function public.pay_with_balance(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid       uuid := auth.uid();
  req       record;
  cur       text;
  rate      numeric;
  need_usd  numeric;
  p         record;
  prate     numeric;
  take      numeric;
  pay_id    uuid := gen_random_uuid();
  tx        text;
  outcome   text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  select r.* into req from nata.delivery_requests r
   where r.id = p_request_id for update;
  if not found or req.sender_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'accepted' or req.display_total is null then
    raise exception 'nata:request_not_payable';
  end if;
  if req.expires_at is not null and req.expires_at <= now() then
    raise exception 'nata:request_not_payable';
  end if;
  if req.ticket_checked_at is null then
    raise exception 'nata:request_not_payable';
  end if;
  cur := coalesce(req.display_currency, 'USD');
  rate := nata.recent_rate(cur);
  if rate is null then
    raise exception 'nata:rate_unavailable';
  end if;

  tx := 'nata-balance-' || pay_id::text;
  insert into nata.payments
    (id, request_id, sender_id, provider, tx_ref, amount, service_fee,
     currency, base_amount, base_currency, method, status)
  values
    (pay_id, req.id, uid, 'nata', tx, req.display_total,
     coalesce(req.display_fee, 0), cur, req.display_total, cur,
     'balance', 'pending');

  -- From the oldest payouts, locked so nothing sends or spends them meanwhile.
  need_usd := req.display_total / rate;
  for p in
    select po.* from nata.payouts po
     where po.traveler_id = uid
       and po.status in ('pending', 'failed')
       and po.amount > po.spent_amount
     order by po.created_at
     for update
  loop
    exit when need_usd <= 0;
    prate := nata.recent_rate(p.currency);
    continue when prate is null;
    -- Rounded up to the cent, so the balance never pays less than the price.
    take := least(p.amount - p.spent_amount,
                  ceil(need_usd * prate * 100) / 100);
    continue when take <= 0;
    update nata.payouts
       set spent_amount = spent_amount + take,
           status = case when spent_amount + take >= amount
                         then 'spent' else status end,
           updated_at = now()
     where id = p.id;
    insert into nata.balance_spends (payment_id, payout_id, amount, currency)
    values (pay_id, p.id, take, p.currency);
    -- A payout used up: the escrow payment it came from is settled.
    if p.spent_amount + take >= p.amount and p.kind = 'earning' then
      update nata.payments set status = 'released', updated_at = now()
       where id = p.payment_id and status = 'held';
    end if;
    need_usd := need_usd - take / prate;
  end loop;

  -- Less than a cent short is rounding; more is too little balance (and
  -- everything above is undone).
  if need_usd * rate > 0.01 then
    raise exception 'nata:balance_too_low';
  end if;

  outcome := nata.complete_payment(tx, null, req.display_total, cur, 'balance');
  if outcome <> 'paid' then
    raise exception 'nata:request_not_payable';
  end if;
  return outcome;
end;
$$;
revoke all on function public.pay_with_balance(uuid) from public, anon;
grant execute on function public.pay_with_balance(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Refunds into the balance
-- -----------------------------------------------------------------------------
-- As in 20240130, plus: a payment from the balance, or a sender who keeps
-- refunds in Nata, is refunded into the balance at once (unless the payment
-- already has a payout, as after a delivery).
create or replace function nata.queue_refund(p_payment_id uuid, p_keep_fee boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay  record;
  amt  numeric;
begin
  select * into pay from nata.payments p
   where p.id = p_payment_id and p.status = 'held' and p.refund_status is null
   for update;
  if not found then
    return;
  end if;
  amt := case when p_keep_fee then greatest(0, pay.amount - ceil(pay.amount * 0.10))
              else pay.amount end;

  if (pay.method = 'balance'
      or exists (select 1 from nata.payment_preferences pp
                  where pp.user_id = pay.sender_id and pp.refund_to_balance))
     and not exists (select 1 from nata.payouts po where po.payment_id = pay.id)
  then
    if amt > 0 then
      insert into nata.payouts
        (payment_id, traveler_id, amount, currency, status, kind)
      values (pay.id, pay.sender_id, amt, pay.currency, 'pending', 'refund');
    end if;
    update nata.payments
       set refund_amount = amt, refund_status = 'refunded',
           refunded_at = now(), status = 'refunded', updated_at = now()
     where id = pay.id;
    perform nata.notify(pay.sender_id, 'payment', 'refund_to_balance',
      'Refund added to your Nata balance',
      'The refund for your cancelled request is in your Nata balance.',
      pay.request_id,
      jsonb_build_object('amount', amt, 'currency', pay.currency,
                         'request_id', pay.request_id));
    return;
  end if;

  update nata.payments
     set refund_amount = amt, refund_status = 'pending', updated_at = now()
   where id = pay.id;
end;
$$;
revoke all on function nata.queue_refund(uuid, boolean)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Payouts and history (the live functions with only that changed)
-- -----------------------------------------------------------------------------
drop function if exists nata.claim_payouts(uuid);
CREATE OR REPLACE FUNCTION nata.claim_payouts(p_traveler uuid DEFAULT NULL::uuid, p_withdraw boolean DEFAULT false)
 RETURNS TABLE(payout_id uuid, reference text, amount numeric, currency text, account_bank text, account_number text, holder_name text, debit_currency text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p          record;
  dest       record;
  sent       numeric;
begin
  for p in
    select po.*
      from nata.payouts po
     where po.status = 'pending'
       and (p_traveler is null or po.traveler_id = p_traveler)
       and po.amount > po.spent_amount
       -- Kept in the Nata balance (20240187): refunds to the balance, and
       -- earnings of members who keep them, leave only on Withdraw.
       and (p_withdraw
            or (po.kind = 'earning'
                and not exists (
                  select 1 from nata.payment_preferences pp
                   where pp.user_id = po.traveler_id
                     and pp.payout_schedule = 'manual')))
     order by po.created_at
     for update skip locked
  loop
    -- The account picked at delivery, else the default; only one Nata can
    -- send to: a pawaPay network, or a Stripe account Stripe allows payouts
    -- on. Other accounts (a bank saved for Flutterwave) are passed over, and
    -- with nothing to send to the payout waits.
    select d.account_bank, d.account_number, d.currency, a.holder_name, a.id
      into dest
      from nata.payout_accounts a
      join nata.payout_destinations d on d.account_id = a.id
     where a.user_id = p.traveler_id
       and (a.id = p.payout_account_id or a.is_default)
       and (
         exists (select 1 from nata.mobile_money_networks n
                  where n.provider = d.account_bank)
         or (d.account_bank = 'STRIPE' and exists (
               select 1 from nata.stripe_accounts s
                where s.account_id = d.account_number
                  and s.user_id = p.traveler_id
                  and s.payouts_enabled)))
     order by (a.id is not distinct from p.payout_account_id) desc
     limit 1;
    continue when not found;

    -- What's left of it: part may have been spent from the balance.
    if dest.currency = p.currency then
      sent := p.amount - p.spent_amount;
    elsif dest.currency = 'USD' then
      -- Stripe transfers are in cents: keep them.
      sent := floor((p.amount - p.spent_amount) / nata.recent_rate(p.currency)
                    * nata.recent_rate(dest.currency) * 100) / 100;
    else
      sent := floor((p.amount - p.spent_amount) / nata.recent_rate(p.currency)
                    * nata.recent_rate(dest.currency));
    end if;
    continue when sent is null or sent <= 0;

    update nata.payouts po
       set status = 'processing',
           reference = coalesce(po.reference, 'nata-payout-' || po.id::text),
           payout_account_id = dest.id,
           payout_amount = sent,
           payout_currency = dest.currency,
           sent_at = now(),
           failure_reason = null,
           updated_at = now()
     where po.id = p.id;

    return query
      select p.id, coalesce(p.reference, 'nata-payout-' || p.id::text), sent,
             dest.currency::text, dest.account_bank, dest.account_number,
             dest.holder_name, p.currency::text;
  end loop;
end;
$function$;

revoke all on function nata.claim_payouts(uuid, boolean)
  from public, anon, authenticated;
grant execute on function nata.claim_payouts(uuid, boolean) to service_role;

drop function if exists public.wallet_history(integer);
CREATE OR REPLACE FUNCTION public.wallet_history(p_limit integer DEFAULT 100)
 RETURNS TABLE(kind text, id uuid, amount numeric, currency text, status text, created_at timestamp with time zone, item text, from_city text, to_city text, other_name text, method text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select * from (
    select
      -- A refund kept in the balance (20240187) reads as such.
      case when po.kind = 'refund' then 'refund' else 'payout' end,
      po.id,
      po.amount,
      coalesce(po.currency, pa.currency)::text,
      po.status,
      po.created_at,
      r.item_description,
      dc.name,
      ac.name,
      sp.first_name,
      null::text
    from nata.payouts po
    left join nata.payments pa         on pa.id = po.payment_id
    left join nata.delivery_requests r on r.id = pa.request_id
    left join nata.trips t             on t.id = r.trip_id
    left join nata.cities dc           on dc.id = t.departure_city_id
    left join nata.cities ac           on ac.id = t.arrival_city_id
    left join nata.profiles sp         on sp.id = r.sender_id
    where po.traveler_id = auth.uid()

    union all

    select
      'payment'::text,
      pa.id,
      pa.amount,
      pa.currency::text,
      pa.status,
      coalesce(pa.completed_at, pa.created_at),
      r.item_description,
      dc.name,
      ac.name,
      tp.first_name,
      pa.method
    from nata.payments pa
    join nata.delivery_requests r on r.id = pa.request_id
    join nata.trips t             on t.id = r.trip_id
    left join nata.cities dc      on dc.id = t.departure_city_id
    left join nata.cities ac      on ac.id = t.arrival_city_id
    left join nata.profiles tp    on tp.id = t.traveler_id
    where pa.sender_id = auth.uid()
      and pa.status in ('held', 'released', 'refunded')
  ) h
  order by h.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$function$;

revoke all on function public.wallet_history(integer) from public, anon;
grant execute on function public.wallet_history(integer)
  to authenticated, service_role;
