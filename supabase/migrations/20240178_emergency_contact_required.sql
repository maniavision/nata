-- Being verified needs an emergency contact.
--
-- Run AFTER 20240177_route_alert_weight.sql. Safe to re-run.
--
-- A member is 'verified' (nata.profiles.verification_status) once their ID
-- check has passed AND they have saved an emergency contact
-- (nata.emergency_contacts, 20240119). Whoever marks them verified first
-- (verify-identity after the face match, or support by hand), a member
-- without a contact stays 'pending', waiting for one; saving the contact
-- then makes them 'verified'. Members verified before this file without a
-- contact go back to waiting for one.
--
--   * nata.profiles.awaiting_emergency_contact: the ID check passed and only
--     the emergency contact is missing (read by the app, set here only).
--   * nata.profiles_verified_needs_contact(): holds 'verified' at 'pending'
--     without a contact. Through the API a member may only ever set their own
--     status to 'pending' (submitting an ID); 'verified' and 'rejected' are
--     the server's.
--   * nata.emergency_contact_completes_verification(): saving the contact
--     makes a member awaiting it 'verified'.

alter table nata.profiles
  add column if not exists awaiting_emergency_contact boolean not null default false;

-- -----------------------------------------------------------------------------
-- 1. 'verified' needs a contact
-- -----------------------------------------------------------------------------
create or replace function nata.profiles_verified_needs_contact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- A member's own write; not one made by another trigger in their request
  -- (saving the contact, section 2).
  if coalesce(auth.role(), '') in ('authenticated', 'anon')
     and pg_trigger_depth() = 1 then
    -- Members don't mark themselves verified, or wait for a contact.
    if tg_op = 'INSERT' then
      new.verification_status := 'unverified';
      new.awaiting_emergency_contact := false;
      return new;
    end if;
    new.awaiting_emergency_contact := old.awaiting_emergency_contact;
    if new.verification_status is distinct from old.verification_status then
      if new.verification_status <> 'pending'
         or old.verification_status in ('verified', 'pending') then
        new.verification_status := old.verification_status;
      else
        -- A new ID submitted: its review starts over.
        new.awaiting_emergency_contact := false;
      end if;
    end if;
    return new;
  end if;

  if new.verification_status = 'verified'
     and not exists (select 1 from nata.emergency_contacts c
                      where c.user_id = new.id) then
    new.verification_status := 'pending';
    new.awaiting_emergency_contact := true;
  elsif new.verification_status is distinct from 'pending' then
    new.awaiting_emergency_contact := false;
  end if;
  return new;
end;
$$;

drop trigger if exists verified_needs_contact on nata.profiles;
create trigger verified_needs_contact
  before insert or update of verification_status, awaiting_emergency_contact
  on nata.profiles
  for each row execute function nata.profiles_verified_needs_contact();

-- -----------------------------------------------------------------------------
-- 2. Saving the contact finishes verification
-- -----------------------------------------------------------------------------
create or replace function nata.emergency_contact_completes_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update nata.profiles p
     set verification_status = 'verified',
         awaiting_emergency_contact = false
   where p.id = new.user_id
     and p.awaiting_emergency_contact
     and p.verification_status = 'pending';
  return new;
end;
$$;

revoke all on function nata.emergency_contact_completes_verification()
  from public, anon, authenticated;

drop trigger if exists completes_verification on nata.emergency_contacts;
create trigger completes_verification
  after insert or update on nata.emergency_contacts
  for each row execute function nata.emergency_contact_completes_verification();

-- -----------------------------------------------------------------------------
-- 3. Members verified without a contact wait for one
-- -----------------------------------------------------------------------------
update nata.profiles p
   set verification_status = 'verified'
 where p.verification_status = 'verified'
   and not exists (select 1 from nata.emergency_contacts c
                    where c.user_id = p.id);
