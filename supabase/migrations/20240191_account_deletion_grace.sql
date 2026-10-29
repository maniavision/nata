-- Deleting an account: 7 days to change your mind.
--
-- Run AFTER 20240190_chat_report_block.sql. Safe to re-run. Deploy the
-- delete-account and purge-deleted-accounts edge functions with it.
--
-- Until now Profile > Delete account erased everything at once
-- (20240156_delete_account.sql). Now:
--
--   * public.schedule_account_deletion(): the same checks as before (nothing
--     in escrow, no payout or refund on the way, no delivery in progress, no
--     open problem report, not staff). Then the account closes at once: open
--     requests are cancelled or declined, upcoming trips cancelled, pushes
--     stop, and nata.profiles.deletion_requested_at is set. Returns when the
--     data will be erased (7 days later). The delete-account edge function
--     calls it and signs the member out everywhere.
--   * public.account_deletion_status(): when the signed-in member's data will
--     be erased, or null. The app asks right after a sign-in.
--   * public.restore_my_account(): signing in within the 7 days and choosing
--     Restore keeps the account. What was cancelled stays cancelled.
--   * Every day at 03:00 UTC, nata.run_account_purge() asks the
--     purge-deleted-accounts edge function to erase the accounts whose 7 days
--     are over: nata.purge_account() deletes the personal data and leaves the
--     "Deleted user" profile (as delete_my_account() did), then the function
--     removes the files and the sign-in. An account with money or a delivery
--     in flight by then is skipped and tried again the next day; one whose
--     files or sign-in couldn't be removed stays listed until they are
--     (public.finish_account_purge clears it).
--   * public.delete_my_account() (immediate) keeps working for the
--     delete-account function already deployed, until the new one replaces it.

alter table nata.profiles
  add column if not exists deletion_requested_at timestamptz;

create index if not exists profiles_deletion_requested_idx
  on nata.profiles (deletion_requested_at)
  where deletion_requested_at is not null;

-- -----------------------------------------------------------------------------
-- 1. Shared steps
-- -----------------------------------------------------------------------------
-- The reason [p_user] can't be deleted now (a nata:... code), or null.
create or replace function nata.account_blocker_code(p_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  b jsonb := nata.account_blockers(p_user);
begin
  if (b ->> 'staff')::boolean then
    return 'nata:is_staff';
  elsif (b ->> 'escrow')::integer > 0 then
    return 'nata:account_has_escrow';
  elsif (b ->> 'payments')::integer > 0 then
    return 'nata:account_has_payments_in_flight';
  elsif (b ->> 'deliveries')::integer > 0 then
    return 'nata:account_has_active_deliveries';
  elsif (b ->> 'disputes')::integer > 0 then
    return 'nata:account_has_open_disputes';
  end if;
  return null;
end;
$$;
revoke all on function nata.account_blocker_code(uuid) from public, anon, authenticated;

-- Closes what is still open, so the other person sees it end.
create or replace function nata.close_open_activity(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update nata.delivery_requests r
     set status = 'cancelled'
   where r.sender_id = p_user and r.status = 'pending';
  update nata.delivery_requests r
     set status = 'declined'
    from nata.trips t
   where t.id = r.trip_id and t.traveler_id = p_user and r.status = 'pending';
  update nata.trips t
     set status = 'cancelled'
   where t.traveler_id = p_user and t.status in ('pending_review', 'live');
end;
$$;
revoke all on function nata.close_open_activity(uuid) from public, anon, authenticated;

-- Deletes [p_user]'s personal data and leaves the "Deleted user" profile
-- (what delete_my_account() did, for any member). The caller checks the
-- blockers first; the files and the sign-in are left to the edge functions.
create or replace function nata.purge_account(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  sql text;
begin
  perform nata.close_open_activity(p_user);
  delete from nata.trips t
   where t.traveler_id = p_user
     and not exists (select 1 from nata.delivery_requests r where r.trip_id = t.id);

  -- Personal data.
  delete from nata.messages m where m.author_id = p_user;
  delete from nata.request_recipients rr
   where rr.request_id in (select r.id from nata.delivery_requests r
                            where r.sender_id = p_user);
  delete from nata.push_tokens where user_id = p_user;
  delete from nata.payment_methods where user_id = p_user;
  delete from nata.payment_preferences where user_id = p_user;
  delete from nata.payer_emails where user_id = p_user;
  delete from nata.emergency_contacts where user_id = p_user;
  delete from nata.user_settings where user_id = p_user;
  delete from nata.identity_verifications where user_id = p_user;
  -- Payouts keep their reference and amounts; the account details go.
  update nata.payouts
     set payout_account_id = null, payout_method_id = null
   where traveler_id = p_user;
  delete from nata.payout_accounts where user_id = p_user;
  delete from nata.payout_methods where user_id = p_user;
  delete from nata.device_tokens where user_id = p_user;
  delete from nata.route_alerts where user_id = p_user;
  delete from nata.user_blocks where blocker_id = p_user or blocked_id = p_user;

  -- The profile becomes "Deleted user": every optional text or date column
  -- (phone, bio, birthday, pseudonym...) is cleared, whatever columns it has
  -- today. A pseudonym in use must be switched off before it is cleared.
  update nata.profiles set use_pseudonym = false where id = p_user;
  select string_agg(format('%I = null', c.column_name), ', ')
    into sql
    from information_schema.columns c
   where c.table_schema = 'nata' and c.table_name = 'profiles'
     and c.is_nullable = 'YES'
     and c.data_type in ('text', 'character varying', 'character', 'date')
     and c.column_name not in ('id', 'first_name');
  if sql is not null then
    execute format('update nata.profiles set %s where id = $1', sql) using p_user;
  end if;
  -- Required ones that still hold something personal are emptied.
  select string_agg(format('%I = %L', c.column_name, ''), ', ')
    into sql
    from information_schema.columns c
   where c.table_schema = 'nata' and c.table_name = 'profiles'
     and c.is_nullable = 'NO'
     and c.column_name in ('last_name', 'phone', 'phone_number', 'email', 'bio');
  if sql is not null then
    execute format('update nata.profiles set %s where id = $1', sql) using p_user;
  end if;
  update nata.profiles
     set first_name = 'Deleted user',
         verification_status = 'unverified',
         deleted_at = coalesce(deleted_at, now())
   where id = p_user;

  -- Last, so nothing above leaves a notification behind.
  delete from nata.notifications where user_id = p_user;
end;
$$;
revoke all on function nata.purge_account(uuid) from public, anon, authenticated;

-- The immediate deletion, now built from the shared steps (same behaviour).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  code text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  perform 1 from nata.profiles p where p.id = uid for update;
  code := nata.account_blocker_code(uid);
  if code is not null then
    raise exception '%', code;
  end if;
  perform nata.purge_account(uid);
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Asking to delete, and changing your mind
-- -----------------------------------------------------------------------------
create or replace function public.schedule_account_deletion()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid   uuid := auth.uid();
  code  text;
  asked timestamptz;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Nothing can be accepted or paid for this user while we look.
  perform 1 from nata.profiles p where p.id = uid for update;
  code := nata.account_blocker_code(uid);
  if code is not null then
    raise exception '%', code;
  end if;

  perform nata.close_open_activity(uid);
  -- No more pushes to their phones.
  delete from nata.push_tokens where user_id = uid;
  delete from nata.device_tokens where user_id = uid;

  update nata.profiles p
     set deletion_requested_at = coalesce(p.deletion_requested_at, now())
   where p.id = uid
  returning p.deletion_requested_at into asked;

  return asked + interval '7 days';
end;
$$;
revoke all on function public.schedule_account_deletion() from public, anon;
grant execute on function public.schedule_account_deletion() to authenticated;

-- When the signed-in member's data will be erased, or null.
create or replace function public.account_deletion_status()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select p.deletion_requested_at + interval '7 days'
    from nata.profiles p
   where p.id = auth.uid()
     and p.deletion_requested_at is not null
     and p.deleted_at is null;
$$;
revoke all on function public.account_deletion_status() from public, anon;
grant execute on function public.account_deletion_status() to authenticated;

create or replace function public.restore_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  update nata.profiles p
     set deletion_requested_at = null
   where p.id = auth.uid() and p.deleted_at is null;
end;
$$;
revoke all on function public.restore_my_account() from public, anon;
grant execute on function public.restore_my_account() to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Erasing after 7 days (the purge-deleted-accounts function)
-- -----------------------------------------------------------------------------
-- Includes accounts already erased whose files or sign-in are still left.
create or replace function public.accounts_due_for_purge()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
    from nata.profiles p
   where p.deletion_requested_at is not null
     and p.deletion_requested_at <= now() - interval '7 days'
   order by p.deletion_requested_at
   limit 200;
$$;
revoke all on function public.accounts_due_for_purge() from public, anon, authenticated;
grant execute on function public.accounts_due_for_purge() to service_role;

-- Erases one account whose 7 days are over. Returns 'purged' (also when its
-- data was erased by an earlier run), or the nata:... reason it has to wait
-- (it is tried again the next day), or 'not_due'.
create or replace function public.purge_due_account(p_user uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  code text;
  gone timestamptz;
begin
  select p.deleted_at into gone
    from nata.profiles p
   where p.id = p_user
     and p.deletion_requested_at is not null
     and p.deletion_requested_at <= now() - interval '7 days'
     for update;
  if not found then
    return 'not_due';
  end if;
  if gone is not null then
    return 'purged';
  end if;
  code := nata.account_blocker_code(p_user);
  if code is not null and code <> 'nata:is_staff' then
    return code;
  end if;
  perform nata.purge_account(p_user);
  return 'purged';
end;
$$;
revoke all on function public.purge_due_account(uuid) from public, anon, authenticated;
grant execute on function public.purge_due_account(uuid) to service_role;

-- The account's files and sign-in are gone too: it leaves the daily list.
create or replace function public.finish_account_purge(p_user uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.profiles
     set deletion_requested_at = null
   where id = p_user and deleted_at is not null;
$$;
revoke all on function public.finish_account_purge(uuid) from public, anon, authenticated;
grant execute on function public.finish_account_purge(uuid) to service_role;

-- Asks purge-deleted-accounts to erase the accounts that are due, with the
-- payment-jobs secret (20240147).
create or replace function nata.run_account_purge()
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
  if not exists (
    select 1 from nata.profiles p
     where p.deletion_requested_at is not null
       and p.deletion_requested_at <= now() - interval '7 days') then
    return 'nothing due';
  end if;
  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'payment_jobs_secret';
  select decrypted_secret into anon
    from vault.decrypted_secrets where name = 'payment_jobs_anon_key';
  if secret is null or anon is null then
    return 'purge-deleted-accounts not set up';
  end if;
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '120');
  select * into resp from extensions.http((
    'POST',
    base || 'purge-deleted-accounts',
    array[
      extensions.http_header('Authorization', 'Bearer ' || anon),
      extensions.http_header('x-job-secret', secret)
    ],
    'application/json',
    '{}'
  )::extensions.http_request);
  if resp.status <> 200 then
    raise warning 'run_account_purge: purge-deleted-accounts answered % %',
      resp.status, resp.content;
  end if;
  return 'purge-deleted-accounts ' || resp.status || ' ' || resp.content;
exception when others then
  raise warning 'run_account_purge: purge-deleted-accounts unreachable: %', sqlerrm;
  return 'purge-deleted-accounts unreachable';
end;
$$;
revoke all on function nata.run_account_purge() from public, anon, authenticated;

select cron.unschedule('purge-deleted-accounts')
 where exists (select 1 from cron.job where jobname = 'purge-deleted-accounts');
select cron.schedule(
  'purge-deleted-accounts', '0 3 * * *',
  $job$ select nata.run_account_purge(); $job$
);

-- Check (run after):
--   select nata.run_account_purge();
--   select status, return_message, start_time from cron.job_run_details
--    where jobid = (select jobid from cron.job
--                    where jobname = 'purge-deleted-accounts')
--    order by start_time desc limit 5;
