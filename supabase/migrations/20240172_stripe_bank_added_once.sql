-- A bank connected through Stripe is added as a payout account once.
--
-- Run AFTER 20240171_payout_account_remove.sql. Safe to re-run.
--
-- stripe-connect (status) and stripe-webhook (account.updated) added the
-- Stripe bank as a payout account whenever Stripe allowed payouts and Nata
-- had none, so a traveler who removed it got it back by just opening Add
-- payout account. Now they add it by themselves only the first time (when
-- the traveler finishes Stripe's form); after that the app asks ("Use this
-- bank"), which calls stripe-connect with save.
--
--   * nata.stripe_accounts.bank_added_at: when it was first added.

alter table nata.stripe_accounts
  add column if not exists bank_added_at timestamptz;

-- Banks already added before this file.
update nata.stripe_accounts s
   set bank_added_at = coalesce(s.bank_added_at, now())
 where exists (select 1 from nata.payout_destinations d
                where d.account_bank = 'STRIPE'
                  and d.account_number = s.account_id);
