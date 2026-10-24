-- Removing a payout account.
--
-- Run AFTER 20240170_stripe_connect_payouts.sql. Safe to re-run.
--
-- Travelers remove a payout account from Payment settings (they already
-- could delete their own rows, 20240124). A payout keeps the account it was
-- picked for at delivery (20240139), which blocked removing that account.
-- Now the link is cleared instead, and the payout goes to the traveler's
-- default account (nata.claim_payouts, 20240170); removing the default makes
-- the most recent other account the default (nata.promote_next_default).

alter table nata.payouts
  drop constraint if exists payouts_payout_account_id_fkey;
alter table nata.payouts
  add constraint payouts_payout_account_id_fkey
  foreign key (payout_account_id) references nata.payout_accounts (id)
  on delete set null;
