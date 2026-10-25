-- A traveler has at most two payout accounts.
--
-- Run AFTER 20240174_payment_methods_by_residence.sql. Safe to re-run.
--
-- Add payout account (add-payout-account, and stripe-connect /
-- stripe-webhook for a bank connected through Stripe) adds a third one no
-- more: the traveler removes one first. With two, they choose which one is
-- the default (the app sets is_default; keep_single_default, 20240124,
-- clears the other).
--
--   * nata.payout_accounts_limit(): refuses a third account
--     (nata:payout_account_limit). Accounts made before this file are kept.

create or replace function nata.payout_accounts_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- One insert at a time per traveler, so two at once can't both pass.
  perform pg_advisory_xact_lock(hashtext('nata.payout_accounts:' || new.user_id::text));
  if (select count(*) from nata.payout_accounts a
       where a.user_id = new.user_id) >= 2 then
    raise exception 'nata:payout_account_limit';
  end if;
  return new;
end;
$$;

drop trigger if exists payout_accounts_limit on nata.payout_accounts;
create trigger payout_accounts_limit
  before insert on nata.payout_accounts
  for each row execute function nata.payout_accounts_limit();
