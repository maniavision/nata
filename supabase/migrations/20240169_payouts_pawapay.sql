-- Payouts through pawaPay; Flutterwave is no longer used.
--
-- Run AFTER 20240168_route_alert_limit.sql. Safe to re-run.
--
-- Travelers are paid to mobile money by pawaPay payouts, sent by the
-- send-payouts edge function (pawaPay needs no whitelisted IP address, so
-- the database no longer calls out itself). Bank payouts wait (pending)
-- until they can be sent through Stripe.
--
--   * nata.payout_destinations: a mobile money account's account_bank is now
--     pawaPay's provider code (nata.mobile_money_networks, 20240165).
--     Accounts saved with Flutterwave's codes are moved over by their
--     country and network name; any that don't match keep their old code
--     and wait, like bank accounts, until the traveler adds the account
--     again.
--   * nata.claim_payouts(): only payouts to a pawaPay network are claimed.
--     send-payouts gives each attempt its own pawaPay payoutId (kept in
--     provider_payout_id before it is sent), which pawaPay never pays twice.
--   * nata.send_payouts() (Flutterwave, from the database) is dropped.
--     nata.call_send_payouts() asks the send-payouts function instead, from
--     nata.run_payment_jobs() (the 15-minute schedule).
--   * public.support_retry() puts a failed payout back in the queue for the
--     next run (send-payouts can't see a change this transaction hasn't
--     committed yet, so it isn't asked straight away).
--   * public.bank_transfer_quote() and nata.local_charge() are dropped: bank
--     transfer at checkout went with Flutterwave.

-- -----------------------------------------------------------------------------
-- 1. Mobile money accounts: pawaPay's provider codes
-- -----------------------------------------------------------------------------
update nata.payout_destinations d
   set account_bank = n.provider
  from nata.payout_accounts a, nata.mobile_money_networks n
 where a.id = d.account_id
   and a.kind = 'mobile_money'
   and n.country_code = a.country_code
   and lower(n.name) = lower(a.institution_name)
   and d.account_bank <> n.provider;

-- -----------------------------------------------------------------------------
-- 2. Claiming payouts: only to a pawaPay network
-- -----------------------------------------------------------------------------
create or replace function nata.claim_payouts(p_traveler uuid default null)
returns table (
  payout_id       uuid,
  reference       text,
  amount          numeric,
  currency        text,
  account_bank    text,
  account_number  text,
  holder_name     text,
  debit_currency  text
)
language plpgsql
security definer
set search_path = ''
as $$
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
     order by po.created_at
     for update skip locked
  loop
    select d.account_bank, d.account_number, d.currency, a.holder_name, a.id
      into dest
      from nata.payout_accounts a
      join nata.payout_destinations d on d.account_id = a.id
     where a.user_id = p.traveler_id
       and a.id = coalesce(
             p.payout_account_id,
             (select x.id from nata.payout_accounts x
               where x.user_id = p.traveler_id and x.is_default limit 1));
    continue when not found;
    -- Bank accounts (and mobile money saved with an old code) wait.
    continue when not exists (
      select 1 from nata.mobile_money_networks n
       where n.provider = dest.account_bank);

    if dest.currency = p.currency then
      sent := p.amount;
    else
      sent := floor(p.amount / nata.recent_rate(p.currency)
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
$$;

revoke all on function nata.claim_payouts(uuid) from public;
revoke all on function nata.claim_payouts(uuid) from anon, authenticated;
grant execute on function nata.claim_payouts(uuid) to service_role;

-- -----------------------------------------------------------------------------
-- 3. Sending: the send-payouts function, no longer the database
-- -----------------------------------------------------------------------------
drop function if exists nata.send_payouts(uuid);

-- Asks send-payouts to send the pending payouts ([p_traveler]'s, or
-- everyone's), with the payment-jobs secret (20240147). Returns its answer,
-- or why it couldn't be asked.
create or replace function nata.call_send_payouts(p_traveler uuid default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  base    constant text := 'https://xnzredskhxfgywggetzw.supabase.co/functions/v1/';
  secret  text;
  anon    text;
  resp    record;
begin
  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'payment_jobs_secret';
  select decrypted_secret into anon
    from vault.decrypted_secrets where name = 'payment_jobs_anon_key';
  if secret is null or anon is null then
    return 'send-payouts not set up';
  end if;
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '60');
  select * into resp from extensions.http((
    'POST',
    base || 'send-payouts',
    array[
      extensions.http_header('Authorization', 'Bearer ' || anon),
      extensions.http_header('x-job-secret', secret)
    ],
    'application/json',
    jsonb_build_object('traveler', p_traveler)::text
  )::extensions.http_request);
  if resp.status <> 200 then
    raise warning 'call_send_payouts: send-payouts answered % %',
      resp.status, resp.content;
  end if;
  return 'send-payouts ' || resp.status || ' ' || resp.content;
exception when others then
  raise warning 'call_send_payouts: send-payouts unreachable: %', sqlerrm;
  return 'send-payouts unreachable';
end;
$$;

revoke all on function nata.call_send_payouts(uuid) from public, anon, authenticated;
grant execute on function nata.call_send_payouts(uuid) to service_role;

-- The schedule: payouts (also pawaPay payouts still in progress, which
-- send-payouts looks at again), then refunds.
create or replace function nata.run_payment_jobs()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  base     constant text := 'https://xnzredskhxfgywggetzw.supabase.co/functions/v1/';
  secret   text;
  anon     text;
  resp     record;
  result   text := '';
begin
  -- Claimed but never handed to pawaPay: claim them again.
  update nata.payouts
     set status = 'pending', updated_at = now()
   where status = 'processing'
     and provider_payout_id is null
     and updated_at < now() - interval '30 minutes';

  if exists (
    select 1
      from nata.payouts po
      join nata.payout_accounts a on a.user_id = po.traveler_id
     where po.status = 'pending')
     or exists (
    select 1 from nata.payouts
     where status = 'processing' and provider_payout_id is not null)
  then
    result := nata.call_send_payouts(null) || '; ';
  end if;

  if exists (
    select 1 from nata.payments
     where refund_status in ('pending', 'processing')
       and provider_payment_id is not null)
  then
    select decrypted_secret into secret
      from vault.decrypted_secrets where name = 'payment_jobs_secret';
    select decrypted_secret into anon
      from vault.decrypted_secrets where name = 'payment_jobs_anon_key';
    if secret is null or anon is null then
      result := result || 'send-refunds not set up; ';
    else
      begin
        select * into resp from extensions.http((
          'POST',
          base || 'send-refunds',
          array[
            extensions.http_header('Authorization', 'Bearer ' || anon),
            extensions.http_header('x-job-secret', secret)
          ],
          'application/json',
          '{}'
        )::extensions.http_request);
        result := result || 'send-refunds ' || resp.status || ' '
          || resp.content || '; ';
        if resp.status <> 200 then
          raise warning 'run_payment_jobs: send-refunds answered % %',
            resp.status, resp.content;
        end if;
      exception when others then
        raise warning 'run_payment_jobs: send-refunds unreachable: %', sqlerrm;
        result := result || 'send-refunds unreachable; ';
      end;
    end if;
  end if;

  return coalesce(nullif(result, ''), 'nothing waiting');
end;
$$;

revoke all on function nata.run_payment_jobs() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Support: a retried payout is sent by the next payment job
-- -----------------------------------------------------------------------------
-- Returns 'pending' for both: the next payment job (within 15 minutes)
-- sends them.
create or replace function public.support_retry(p_kind text, p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  traveler uuid;
  req      uuid;
  person   uuid;
begin
  perform nata.require_admin();
  if p_kind = 'payout' then
    update nata.payouts po
       set status = 'pending', failure_reason = null, updated_at = now()
     where po.id = p_id and po.status = 'failed'
    returning po.traveler_id, (select p.request_id from nata.payments p
                                where p.id = po.payment_id)
      into traveler, req;
    if not found then
      raise exception 'nata:not_failed';
    end if;
    perform nata.log_support('payout_retried', 'Payout retried · ' ||
      coalesce(nata.short_name(traveler), ''), req);
    return 'pending';
  elsif p_kind = 'refund' then
    update nata.payments p
       set refund_status = 'pending', refund_failure = null, updated_at = now()
     where p.id = p_id and p.refund_status = 'failed'
    returning p.sender_id, p.request_id into person, req;
    if not found then
      raise exception 'nata:not_failed';
    end if;
    perform nata.log_support('refund_retried', 'Refund retried · ' ||
      coalesce(nata.short_name(person), ''), req);
    return 'pending';
  end if;
  raise exception 'nata:bad_kind';
end;
$$;
revoke all on function public.support_retry(text, uuid) from public, anon;
grant execute on function public.support_retry(text, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. No more bank transfer at checkout
-- -----------------------------------------------------------------------------
drop function if exists public.bank_transfer_quote(uuid);
drop function if exists nata.local_charge(uuid, text);
