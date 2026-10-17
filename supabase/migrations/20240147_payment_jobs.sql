-- Payouts and refunds left waiting are sent by a schedule.
--
-- Run AFTER 20240146_visitor_search.sql. Safe to re-run.
--
-- The app sends payouts (after delivery, adding a payout account, Withdraw)
-- and refunds (after a cancellation) itself, but one can be left waiting: a
-- traveler who never comes back, a transfer Flutterwave couldn't take yet
-- (put back to pending), or the app closed at the wrong moment. Every 15
-- minutes nata.run_payment_jobs():
--   * puts back payouts stuck in 'processing' for 30 minutes with no
--     Flutterwave id (the function stopped before hearing back). Sending
--     again is safe: Flutterwave refuses the same reference twice. Refunds
--     stuck that way are left for support, since a second partial refund
--     could go through;
--   * calls send-payouts when a pending payout has a payout account to go
--     to, and send-refunds when a refund is pending.
--
-- The functions know the call is the schedule's from the x-job-secret
-- header, which matches their PAYMENT_JOBS_SECRET. The secret and the
-- project's anon key (the functions gateway needs one) are kept in Vault as
-- payment_jobs_secret and payment_jobs_anon_key, set by
-- scripts/setup_payment_jobs.sh. Until then the job does nothing.

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
  fn       text;
  resp     record;
  result   text := '';
begin
  update nata.payouts
     set status = 'pending', updated_at = now()
   where status = 'processing'
     and provider_payout_id is null
     and updated_at < now() - interval '30 minutes';

  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'payment_jobs_secret';
  select decrypted_secret into anon
    from vault.decrypted_secrets where name = 'payment_jobs_anon_key';
  if secret is null or anon is null then
    return 'not set up';
  end if;

  foreach fn in array array['send-payouts', 'send-refunds'] loop
    continue when fn = 'send-payouts' and not exists (
      select 1
        from nata.payouts po
        join nata.payout_accounts a on a.user_id = po.traveler_id
       where po.status = 'pending');
    continue when fn = 'send-refunds' and not exists (
      select 1 from nata.payments
       where refund_status = 'pending' and provider_payment_id is not null);

    begin
      select * into resp from extensions.http((
        'POST',
        base || fn,
        array[
          extensions.http_header('Authorization', 'Bearer ' || anon),
          extensions.http_header('x-job-secret', secret)
        ],
        'application/json',
        '{}'
      )::extensions.http_request);
      result := result || fn || ' ' || resp.status || ' ' || resp.content || '; ';
      if resp.status <> 200 then
        raise warning 'run_payment_jobs: % answered % %',
          fn, resp.status, resp.content;
      end if;
    exception when others then
      raise warning 'run_payment_jobs: % unreachable: %', fn, sqlerrm;
      result := result || fn || ' unreachable; ';
    end;
  end loop;

  return coalesce(nullif(result, ''), 'nothing waiting');
end;
$$;

-- Only the scheduler (and the dashboard) runs it, never the app.
revoke all on function nata.run_payment_jobs() from public, anon, authenticated;

select cron.schedule(
  'send-waiting-payments', '*/15 * * * *',
  $job$ select nata.run_payment_jobs(); $job$
);

-- Check (run after):
--   select nata.run_payment_jobs();
--   select status, return_message, start_time from cron.job_run_details
--    where jobid = (select jobid from cron.job
--                    where jobname = 'send-waiting-payments')
--    order by start_time desc limit 5;
