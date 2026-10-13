-- "A new version is available" (and "this version is no longer supported").
--
-- One row per platform says which version of the app is the newest, and the
-- oldest one still allowed. The app asks for its own row when it opens (and
-- when it comes back from the background), before anyone is signed in, so the
-- function is open to anonymous callers.
--
-- Safe to re-run: existing rows are NOT overwritten (so re-running never rolls
-- a release back).
--
-- ── Publishing a new release ─────────────────────────────────────────────────
-- After the new build is live in the store, run (use the version from
-- pubspec.yaml, without the +build number):
--
--   update nata.app_versions
--      set latest_version = '1.1.0',
--          release_notes  = 'Several items per request. Emergency contact.',
--          updated_at     = now()
--    where platform in ('ios', 'android');
--
-- To make an update compulsory (older versions cannot be used any more):
--
--   update nata.app_versions
--      set min_supported_version = '1.1.0', updated_at = now()
--    where platform in ('ios', 'android');
--
-- Store links: set store_url once the app is listed. Android falls back to
-- the Play Store page of the app's package name when it is empty; iOS needs
-- the link (https://apps.apple.com/app/id<your app id>).
--   update nata.app_versions
--      set store_url = 'https://apps.apple.com/app/id0000000000'
--    where platform = 'ios';

create table if not exists nata.app_versions (
  platform               text primary key check (platform in ('ios', 'android')),
  latest_version         text not null check (latest_version ~ '^[0-9]+(\.[0-9]+){0,2}$'),
  min_supported_version  text not null default '1.0.0'
                           check (min_supported_version ~ '^[0-9]+(\.[0-9]+){0,2}$'),
  store_url              text check (store_url is null or store_url ~ '^https://'),
  release_notes          text,
  updated_at             timestamptz not null default now()
);

alter table nata.app_versions enable row level security;

-- Nobody reads the table directly; the function below is the only way in.
revoke all on nata.app_versions from anon, authenticated;

insert into nata.app_versions (platform, latest_version, min_supported_version)
values ('ios', '1.0.0', '1.0.0'), ('android', '1.0.0', '1.0.0')
on conflict (platform) do nothing;

create or replace function public.get_app_version(p_platform text)
returns table (
  latest_version         text,
  min_supported_version  text,
  store_url              text,
  release_notes          text
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.latest_version, v.min_supported_version, v.store_url, v.release_notes
    from nata.app_versions v
   where v.platform = lower(btrim(p_platform));
$$;

revoke all on function public.get_app_version(text) from public;
grant execute on function public.get_app_version(text) to anon, authenticated;

-- Check (run after): both platforms listed.
--   select * from public.get_app_version('android');
--   select * from public.get_app_version('ios');
