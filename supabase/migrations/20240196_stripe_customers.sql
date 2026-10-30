-- Cards saved with Stripe, for paying without typing them again.
--
-- Run AFTER 20240195_item_deposits.sql. Safe to re-run.
--
-- Each member who pays by card gets a Stripe Customer, kept here. Their cards
-- are saved on it by Stripe (the stripe-cards function and Stripe's own
-- payment sheet), so Nata never holds a card number: the app lists them
-- through stripe-cards, and create-payment hands the sheet the customer so
-- the default card is offered first. Only the service role reads this
-- table.
--
-- Cards typed into Nata's own form before (nata.payment_methods rows of kind
-- 'card': a brand and last 4 digits only, never usable to pay) are no longer
-- shown; they are removed here.

create table if not exists nata.stripe_customers (
  user_id     uuid primary key references nata.profiles(id) on delete cascade,
  customer_id text not null unique,
  created_at  timestamptz not null default now()
);

alter table nata.stripe_customers enable row level security;
revoke all on nata.stripe_customers from anon, authenticated;
grant select, insert, update, delete on nata.stripe_customers to service_role;

delete from nata.payment_methods where kind = 'card';
