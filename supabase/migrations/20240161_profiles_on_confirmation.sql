-- Profiles are created when a sign-up is confirmed, not when the code is
-- asked for; abandoned sign-ups are cleaned up.
--
-- Run AFTER 20240160_name_locked_after_verification.sql. Safe to re-run.
--
-- Asking for a sign-up code creates the sign-in account (auth.users) at
-- once, and nata.handle_new_user used to create its nata.profiles row right
-- then, without a name. Someone who never entered the code left an empty
-- profile behind.
--
--   * The profile is now created when the phone (or email) is confirmed, or
--     straight away for an account that is confirmed from the start (Apple,
--     Google). Its name comes from the sign-up request (the app sends
--     first_name and last_name with it) when there is one.
--   * Every day, sign-ups never confirmed within 24 hours (and never signed
--     in) are deleted, with their empty profile (20240156 removes the
--     profile with the user).

create or replace function nata.create_profile_for(u auth.users)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  full_name text := coalesce(u.raw_user_meta_data ->> 'full_name',
                             u.raw_user_meta_data ->> 'name', '');
begin
  insert into nata.profiles (id, first_name, last_name)
  values (
    u.id,
    btrim(coalesce(nullif(u.raw_user_meta_data ->> 'first_name', ''),
                   split_part(full_name, ' ', 1))),
    btrim(coalesce(nullif(u.raw_user_meta_data ->> 'last_name', ''),
                   nullif(substr(full_name, strpos(full_name, ' ') + 1), ''),
                   ''))
  )
  on conflict (id) do nothing;
end;
$$;

revoke all on function nata.create_profile_for(auth.users) from public, anon, authenticated;

-- New sign-in account: a profile only if it is already confirmed.
create or replace function nata.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.phone_confirmed_at is not null or new.email_confirmed_at is not null then
    perform nata.create_profile_for(new);
  end if;
  return new;
end;
$$;

-- The code was entered (phone or email confirmed): now the profile.
create or replace function nata.handle_user_confirmed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (old.phone_confirmed_at is null and new.phone_confirmed_at is not null)
     or (old.email_confirmed_at is null and new.email_confirmed_at is not null) then
    perform nata.create_profile_for(new);
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update of phone_confirmed_at, email_confirmed_at on auth.users
  for each row execute function nata.handle_user_confirmed();

-- Sign-ups never confirmed within a day, and never signed in.
create or replace function nata.delete_abandoned_signups()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with gone as (
    delete from auth.users u
     where u.phone_confirmed_at is null
       and u.email_confirmed_at is null
       and u.last_sign_in_at is null
       and u.created_at < now() - interval '24 hours'
    returning 1
  )
  select count(*) into n from gone;
  return n;
end;
$$;

revoke all on function nata.delete_abandoned_signups() from public, anon, authenticated;

select cron.schedule(
  'delete-abandoned-signups', '17 3 * * *',
  $job$ select nata.delete_abandoned_signups(); $job$
);
