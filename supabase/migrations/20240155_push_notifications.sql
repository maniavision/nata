-- Push notifications to the phone.
--
-- Run AFTER 20240154_support_tools.sql. Safe to re-run.
--
--   * The app registers its Firebase Cloud Messaging token after sign-in
--     (public.register_push_token) and removes it on sign-out
--     (public.unregister_push_token). One user can have several devices.
--   * Every new row in nata.notifications asks the send-push edge function
--     to push it (pg_net, so the insert never waits). send-push writes it in
--     the user's language (nata.user_settings.language), sends it to each
--     device and stamps pushed_at; dead tokens are removed.
--   * nata.run_push_jobs(), every 5 minutes, sends again anything from the
--     last day that wasn't pushed (send-push was down, say).
--
-- send-push is called with the payment-jobs secret and anon key in Vault
-- (scripts/setup_payment_jobs.sh), and needs FCM_SERVICE_ACCOUNT, set by
-- scripts/setup_push.sh. Until then nothing is pushed and nothing breaks.

create extension if not exists pg_net;

create table if not exists nata.push_tokens (
  token       text primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  platform    text not null check (platform in ('ios', 'android')),
  updated_at  timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on nata.push_tokens (user_id);
alter table nata.push_tokens enable row level security;
revoke all on nata.push_tokens from anon, authenticated;

alter table nata.notifications
  add column if not exists pushed_at timestamptz;

-- A token moves to whoever signed in last on that device.
create or replace function public.register_push_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  if coalesce(btrim(p_token), '') = '' or p_platform not in ('ios', 'android') then
    raise exception 'nata:token_invalid';
  end if;
  insert into nata.push_tokens (token, user_id, platform, updated_at)
  values (btrim(p_token), auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;
revoke all on function public.register_push_token(text, text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;

create or replace function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from nata.push_tokens
   where token = btrim(p_token) and user_id = auth.uid();
$$;
revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function public.unregister_push_token(text) to authenticated;

-- Asks send-push to push [p_ids] (or nothing, if not set up yet).
create or replace function nata.request_push(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  secret text;
  anon   text;
begin
  if p_ids is null or cardinality(p_ids) = 0 then
    return;
  end if;
  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'payment_jobs_secret';
  select decrypted_secret into anon
    from vault.decrypted_secrets where name = 'payment_jobs_anon_key';
  if secret is null or anon is null then
    return;
  end if;
  perform net.http_post(
    url := 'https://xnzredskhxfgywggetzw.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || anon,
      'x-job-secret', secret),
    body := jsonb_build_object('ids', to_jsonb(p_ids))
  );
exception when others then
  -- A push must never stop the notification itself.
  raise warning 'request_push failed: %', sqlerrm;
end;
$$;
revoke all on function nata.request_push(uuid[]) from public, anon, authenticated;

create or replace function nata.push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from nata.push_tokens t where t.user_id = new.user_id) then
    perform nata.request_push(array[new.id]);
  end if;
  return new;
end;
$$;

drop trigger if exists push_on_insert on nata.notifications;
create trigger push_on_insert
  after insert on nata.notifications
  for each row execute function nata.push_on_notification();

create or replace function nata.run_push_jobs()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  ids uuid[];
begin
  select array_agg(n.id) into ids
    from (select n.id
            from nata.notifications n
           where n.pushed_at is null
             and n.created_at > now() - interval '1 day'
             and n.created_at < now() - interval '2 minutes'
             and exists (select 1 from nata.push_tokens t
                          where t.user_id = n.user_id)
           order by n.created_at
           limit 200) n;
  perform nata.request_push(ids);
  return coalesce(cardinality(ids), 0);
end;
$$;
revoke all on function nata.run_push_jobs() from public, anon, authenticated;

select cron.schedule(
  'send-waiting-pushes', '*/5 * * * *',
  $job$ select nata.run_push_jobs(); $job$
);
