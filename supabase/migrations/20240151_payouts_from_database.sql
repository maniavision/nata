-- Payout transfers are sent by the database.
--
-- Run AFTER 20240150_claim_payouts_fix.sql. Safe to re-run.
--
-- Flutterwave only takes transfer requests from whitelisted IP addresses,
-- and edge functions have no fixed one. The database calls out from its own
-- address (35.182.188.199 when this was written; check with
--   select content from extensions.http_get('https://api.ipify.org');
-- after Supabase maintenance, and update the whitelist in Flutterwave >
-- Settings > Whitelisted IP addresses if it changed).
--
-- nata.send_payouts([p_traveler]) claims the pending payouts (of one
-- traveler, or everyone's), asks Flutterwave for each transfer and records
-- the answer, as the send-payouts edge function did. Each transfer carries
-- the payout's own reference, which Flutterwave refuses twice, so a payout
-- is never paid twice. send-payouts and nata.run_payment_jobs now call it.
--
-- The Flutterwave secret key is kept in Vault as flw_secret_key, set by
-- scripts/setup_payout_transfers.sh. Until then nothing is sent.

create or replace function nata.send_payouts(p_traveler uuid default null)
returns table (sent integer, failed integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  key      text;
  p        record;
  resp     record;
  body     jsonb;
  message  text;
  n_sent   integer := 0;
  n_failed integer := 0;
begin
  select decrypted_secret into key
    from vault.decrypted_secrets where name = 'flw_secret_key';
  if coalesce(key, '') = '' then
    raise warning 'send_payouts: flw_secret_key is not set';
    return query select 0, 0;
    return;
  end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '30');

  for p in select * from nata.claim_payouts(p_traveler) loop
    begin
      select * into resp from extensions.http((
        'POST',
        'https://api.flutterwave.com/v3/transfers',
        array[extensions.http_header('Authorization', 'Bearer ' || key)],
        'application/json',
        jsonb_build_object(
          'account_bank', p.account_bank,
          'account_number', p.account_number,
          'amount', p.amount,
          'currency', p.currency,
          'debit_currency', p.debit_currency,
          'beneficiary_name', p.holder_name,
          'narration', 'Nata delivery payout',
          'reference', p.reference
        )::text
      )::extensions.http_request);

      begin
        body := resp.content::jsonb;
      exception when others then
        body := '{}'::jsonb;
      end;
      message := coalesce(body ->> 'message', '');

      if (resp.status between 200 and 299 and body ->> 'status' = 'success')
         or message ~* 'duplicate|already exist' then
        perform nata.payout_accepted(p.reference, body -> 'data' ->> 'id');
        n_sent := n_sent + 1;
      else
        -- Refused (a wrong account, not enough balance...): support looks.
        perform nata.payout_failed(
          p.reference,
          coalesce(nullif(message, ''), 'HTTP ' || resp.status),
          resp.status >= 500);
        n_failed := n_failed + 1;
      end if;
    exception when others then
      -- It may not have reached Flutterwave: try again later, same reference.
      perform nata.payout_failed(p.reference, sqlerrm, true);
      n_failed := n_failed + 1;
    end;
  end loop;

  return query select n_sent, n_failed;
end;
$$;

revoke all on function nata.send_payouts(uuid) from public, anon, authenticated;
grant execute on function nata.send_payouts(uuid) to service_role;

-- The schedule sends payouts itself, and still calls send-refunds.
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
  outcome  record;
begin
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
  then
    select * into outcome from nata.send_payouts();
    result := 'payouts sent ' || outcome.sent || ', failed ' || outcome.failed
      || '; ';
  end if;

  if exists (
    select 1 from nata.payments
     where refund_status = 'pending' and provider_payment_id is not null)
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
