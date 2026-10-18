-- Payouts no longer need the old payout method.
--
-- Run AFTER 20240148_payer_email.sql. Safe to re-run.
--
-- nata.payouts was created before the migrations with a required
-- payout_method_id (nata.payout_methods). Payouts now go to a payout account
-- (payout_account_id, 20240140), and confirm_delivery leaves the old column
-- empty, so confirming a delivery failed with a not-null error and no payout
-- was recorded. The column stays for old rows but is optional.

alter table nata.payouts alter column payout_method_id drop not null;
