-- A member's name is locked once their identity check has started.
--
-- Run AFTER 20240159_route_alerts.sql. Safe to re-run.
--
-- The name is part of the trust checks: the traveler's ticket must show it,
-- and senders see the verified name next to the ID photo before paying. So
-- a member may change their own first and last name only while their
-- identity is 'unverified' or 'rejected'. Once it is 'pending' (under
-- review) or 'verified', the app's own requests are refused with
-- nata:name_locked; support (service role, SQL editor) and the server's own
-- functions can still change it.
--
-- Names are also kept tidy: trimmed, 1 to 50 characters each.

create or replace function nata.profiles_guard_name()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.first_name is not distinct from old.first_name
     and new.last_name is not distinct from old.last_name then
    return new;
  end if;

  -- Only the member's own requests are limited; security-definer functions
  -- and support run as other roles.
  if current_user = 'authenticated'
     and old.verification_status in ('pending', 'verified') then
    raise exception 'nata:name_locked';
  end if;

  if current_user = 'authenticated' then
    new.first_name := btrim(coalesce(new.first_name, ''));
    new.last_name := btrim(coalesce(new.last_name, ''));
    if char_length(new.first_name) not between 1 and 50
       or char_length(new.last_name) not between 1 and 50 then
      raise exception 'nata:name_invalid';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_name on nata.profiles;
create trigger guard_name
  before update of first_name, last_name on nata.profiles
  for each row execute function nata.profiles_guard_name();
