-- Emergency contact, collected at the end of identity verification.
--
-- One contact per user. Only the user can read or change their own contact:
-- it is never shown to senders or travelers. (Support reads it with the
-- service role, which bypasses RLS.)
--
-- Safe to re-run.

create table if not exists nata.emergency_contacts (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  full_name     text not null check (char_length(btrim(full_name)) between 2 and 80),
  phone         text not null check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  relationship  text not null check (relationship in ('friend', 'relative', 'partner', 'colleague')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table nata.emergency_contacts enable row level security;

drop policy if exists "users can read own emergency contact"   on nata.emergency_contacts;
drop policy if exists "users can insert own emergency contact" on nata.emergency_contacts;
drop policy if exists "users can update own emergency contact" on nata.emergency_contacts;

create policy "users can read own emergency contact"
  on nata.emergency_contacts for select
  to authenticated
  using (auth.uid() = user_id);

create policy "users can insert own emergency contact"
  on nata.emergency_contacts for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "users can update own emergency contact"
  on nata.emergency_contacts for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- No delete from the app, and nothing for anonymous callers.
revoke all on nata.emergency_contacts from anon, authenticated;
grant select, insert, update on nata.emergency_contacts to authenticated;

-- Keep updated_at current.
create or replace function nata.touch_emergency_contact()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists touch_emergency_contact on nata.emergency_contacts;
create trigger touch_emergency_contact
  before update on nata.emergency_contacts
  for each row execute function nata.touch_emergency_contact();
