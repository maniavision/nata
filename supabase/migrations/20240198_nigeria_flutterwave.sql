-- Members living in Nigeria pay and are paid through Flutterwave.
--
-- Run AFTER 20240197_carry_limit_by_residence.sql. Safe to re-run.
--
-- Whoever pays (the sender for a delivery, the traveler for a deposit) and
-- lives in Nigeria pays by card on Flutterwave's payment page, in naira at
-- today's rate. A traveler living in Nigeria is paid to their Nigerian bank
-- account by a Flutterwave transfer. Nobody else changes: mobile money stays
-- on pawaPay and cards on Stripe.
--
-- Flutterwave only takes transfers from whitelisted IP addresses and edge
-- functions have none, so transfers are sent by the database itself, as
-- before 20240169 (the key is in Vault as flw_secret_key; the database's
-- address must be whitelisted in Flutterwave > Settings > Whitelisted IP
-- addresses, check it with
--   select content from extensions.http_get('https://api.ipify.org');
-- ). send-payouts asks for each transfer (nata.flutterwave_transfer), and the
-- schedule and flutterwave-webhook look up the result
-- (nata.check_flutterwave_transfer).

-- -----------------------------------------------------------------------------
-- 1. Nigeria leaves mobile money
-- -----------------------------------------------------------------------------
delete from nata.payment_methods
 where mobile_network in (select provider from nata.mobile_money_networks
                           where country_code = 'NG');
delete from nata.mobile_money_networks where country_code = 'NG';

-- -----------------------------------------------------------------------------
-- 2. Who pays through Flutterwave
-- -----------------------------------------------------------------------------
create or replace function nata.pays_with_flutterwave(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from nata.profiles p
     where p.id = p_user
       and upper(btrim(p.country_of_residence::text)) = 'NG');
$$;
revoke all on function nata.pays_with_flutterwave(uuid) from public, anon, authenticated;
grant execute on function nata.pays_with_flutterwave(uuid) to service_role;

-- How [p_payer] pays for the request: 'flutterwave' (a card on Flutterwave's
-- page, in naira) when they live in Nigeria, else the request's own rule
-- (nata.checkout_kind, 20240173: mobile_money or card).
create or replace function nata.payer_checkout_kind(p_request_id uuid, p_payer uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when nata.pays_with_flutterwave(p_payer) then 'flutterwave'
           else nata.checkout_kind(p_request_id)
         end;
$$;
revoke all on function nata.payer_checkout_kind(uuid, uuid) from public, anon, authenticated;
grant execute on function nata.payer_checkout_kind(uuid, uuid) to service_role;

-- The sender's way to pay.
create or replace function public.checkout_kind(p_request_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (select 1 from nata.delivery_requests r
                  where r.id = p_request_id and r.sender_id = auth.uid()) then
    raise exception 'nata:request_not_found';
  end if;
  return nata.payer_checkout_kind(p_request_id, auth.uid());
end;
$$;

-- The deposit is paid the traveler's way.
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
    -- How the traveler pays it: mobile money, card, or Flutterwave when
    -- they live in Nigeria (20240198).
    'kind', nata.payer_checkout_kind(p_request_id, req.traveler_id),
    'tx_ref', case when uid = req.traveler_id then pay.tx_ref end);
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. The amount in naira
-- -----------------------------------------------------------------------------
-- [p_amount] of [p_currency] in naira at today's rate, rounded up to a whole
-- naira.
create or replace function nata.naira_amount(p_amount numeric, p_currency text)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  from_rate numeric;
  to_rate   numeric;
begin
  if upper(btrim(p_currency)) = 'NGN' then
    return ceil(p_amount);
  end if;
  from_rate := nata.recent_rate(upper(btrim(p_currency)));
  to_rate := nata.recent_rate('NGN');
  if from_rate is null or to_rate is null or from_rate <= 0 then
    raise exception 'nata:rate_unavailable';
  end if;
  return ceil(p_amount / from_rate * to_rate);
end;
$$;
revoke all on function nata.naira_amount(numeric, text) from public, anon, authenticated;
grant execute on function nata.naira_amount(numeric, text) to service_role;

-- -----------------------------------------------------------------------------
-- 4. Payouts to a Nigerian bank
-- -----------------------------------------------------------------------------
-- claim_payouts also takes payouts to a Nigerian bank account (a bank saved
-- with a Flutterwave bank code), and says who sends each one.
drop function if exists nata.claim_payouts(uuid, boolean);
create function nata.claim_payouts(p_traveler uuid default null, p_withdraw boolean default false)
returns table (payout_id uuid, reference text, amount numeric, currency text,
               account_bank text, account_number text, holder_name text,
               debit_currency text, provider text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  p          record;
  dest       record;
  sent       numeric;
  via        text;
begin
  -- Withdraw (20240193): the member's failed payouts go back in the queue,
  -- to their current default payout account rather than the one picked at
  -- delivery (it may be the network pawaPay couldn't pay).
  if p_withdraw and p_traveler is not null then
    update nata.payouts po
       set status = 'pending',
           payout_account_id = null,
           provider_payout_id = null,
           failure_reason = null,
           updated_at = now()
     where po.traveler_id = p_traveler
       and po.status = 'failed';
  end if;

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
    -- send to: a pawaPay network, a Stripe account Stripe allows payouts
    -- on, or a Nigerian bank (Flutterwave, 20240198). With nothing to send
    -- to, the payout waits.
    select d.account_bank, d.account_number, d.currency, a.holder_name, a.id,
           (a.kind = 'bank' and a.country_code = 'NG') as flutterwave
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
                  and s.payouts_enabled))
         or (a.kind = 'bank' and a.country_code = 'NG' and d.currency = 'NGN'))
     order by (a.id is not distinct from p.payout_account_id) desc
     limit 1;
    continue when not found;

    via := case
             when dest.account_bank = 'STRIPE' then 'stripe'
             when dest.flutterwave then 'flutterwave'
             else 'pawapay'
           end;

    -- What's left of it (part may have been spent from the balance), in the
    -- account's currency.
    if dest.currency = p.currency then
      sent := p.amount - p.spent_amount;
    else
      sent := (p.amount - p.spent_amount) / nata.recent_rate(p.currency)
              * nata.recent_rate(dest.currency);
    end if;
    if via = 'pawapay' then
      -- Mobile money is paid in whole amounts (20240192): pawaPay refuses
      -- decimals on XAF, XOF and most other networks.
      sent := floor(sent);
    else
      -- Stripe and Flutterwave take cents (kobo): keep them.
      sent := floor(sent * 100) / 100;
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
             dest.holder_name, p.currency::text, via;
  end loop;
end;
$$;
revoke all on function nata.claim_payouts(uuid, boolean) from public, anon, authenticated;
grant execute on function nata.claim_payouts(uuid, boolean) to service_role;

-- Sends the claimed payout [p_reference] to its Nigerian bank as a
-- Flutterwave transfer, from the database's whitelisted address, and records
-- the answer: 'sent' (Flutterwave took it; the result comes later),
-- 'failed', or 'skipped' (not a claimed payout to a Nigerian bank). The
-- transfer carries the payout's reference, which Flutterwave refuses twice,
-- so a payout is never paid twice.
create or replace function nata.flutterwave_transfer(p_reference text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  key      text;
  pay      record;
  resp     record;
  body     jsonb;
  message  text;
begin
  select po.reference, po.payout_amount, po.payout_currency,
         d.account_bank, d.account_number, a.holder_name
    into pay
    from nata.payouts po
    join nata.payout_accounts a on a.id = po.payout_account_id
    join nata.payout_destinations d on d.account_id = a.id
   where po.reference = p_reference
     and po.status = 'processing'
     and po.provider_payout_id is null
     and a.kind = 'bank' and a.country_code = 'NG';
  if not found then
    return 'skipped';
  end if;

  select decrypted_secret into key
    from vault.decrypted_secrets where name = 'flw_secret_key';
  if coalesce(key, '') = '' then
    perform nata.payout_failed(p_reference, 'Flutterwave isn''t set up', true);
    return 'failed';
  end if;

  begin
    perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '30');
    select * into resp from extensions.http((
      'POST',
      'https://api.flutterwave.com/v3/transfers',
      array[extensions.http_header('Authorization', 'Bearer ' || key)],
      'application/json',
      jsonb_build_object(
        'account_bank', pay.account_bank,
        'account_number', pay.account_number,
        'amount', po.payout_amount,
        'currency', po.payout_currency,
        'beneficiary_name', pay.holder_name,
        'narration', 'Nata payout',
        'reference', pay.reference
      )::text
    )::extensions.http_request);
  exception when others then
    -- It may not have reached Flutterwave: try again later, same reference.
    perform nata.payout_failed(p_reference, left(sqlerrm, 200), true);
    return 'failed';
  end;

  begin
    body := resp.content::jsonb;
  exception when others then
    body := '{}'::jsonb;
  end;
  message := coalesce(body ->> 'message', '');

  if resp.status between 200 and 299 and body ->> 'status' = 'success'
     and coalesce(body -> 'data' ->> 'id', '') <> '' then
    perform nata.payout_accepted(p_reference, body -> 'data' ->> 'id');
    return 'sent';
  end if;
  -- Refused (a wrong account, not enough balance, a reference already
  -- used...): support looks; a Flutterwave outage is tried again.
  perform nata.payout_failed(
    p_reference,
    'Flutterwave: ' || coalesce(nullif(message, ''), 'HTTP ' || resp.status),
    resp.status >= 500);
  return 'failed';
end;
$$;
revoke all on function nata.flutterwave_transfer(text) from public, anon, authenticated;
grant execute on function nata.flutterwave_transfer(text) to service_role;

-- Looks the Flutterwave transfer of payout [p_reference] up (its own id, or
-- [p_transfer_id] from a webhook notice, which must carry the same
-- reference) and records it: 'paid' (the escrow payment is released),
-- 'failed', 'pending', or 'skipped' (not one of ours).
create or replace function nata.check_flutterwave_transfer(
  p_reference text,
  p_transfer_id text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  key      text;
  id       text;
  resp     record;
  body     jsonb;
  t        jsonb;
  status   text;
begin
  select coalesce(po.provider_payout_id, p_transfer_id) into id
    from nata.payouts po
   where po.reference = p_reference and po.status = 'processing';
  if coalesce(id, '') !~ '^[0-9]+$' then
    return 'skipped';
  end if;

  select decrypted_secret into key
    from vault.decrypted_secrets where name = 'flw_secret_key';
  if coalesce(key, '') = '' then
    return 'pending';
  end if;

  begin
    perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '30');
    select * into resp from extensions.http((
      'GET',
      'https://api.flutterwave.com/v3/transfers/' || id,
      array[extensions.http_header('Authorization', 'Bearer ' || key)],
      null,
      null
    )::extensions.http_request);
    body := resp.content::jsonb;
  exception when others then
    return 'pending';
  end;
  t := body -> 'data';
  if resp.status <> 200 or body ->> 'status' <> 'success'
     or coalesce(t ->> 'reference', '') <> p_reference then
    return 'pending';
  end if;

  status := upper(coalesce(t ->> 'status', ''));
  if status = 'SUCCESSFUL' then
    perform nata.release_payout(p_reference, id);
    return 'paid';
  end if;
  if status = 'FAILED' then
    perform nata.payout_accepted(p_reference, id);
    perform nata.payout_failed(
      p_reference,
      'Flutterwave: ' || coalesce(nullif(t ->> 'complete_message', ''), 'transfer failed'),
      false);
    return 'failed';
  end if;
  perform nata.payout_accepted(p_reference, id);
  return 'pending';
end;
$$;
revoke all on function nata.check_flutterwave_transfer(text, text) from public, anon, authenticated;
grant execute on function nata.check_flutterwave_transfer(text, text) to service_role;
