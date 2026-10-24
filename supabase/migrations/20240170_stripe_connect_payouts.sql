-- Bank payouts through Stripe Connect.
--
-- Run AFTER 20240169_payouts_pawapay.sql. Safe to re-run.
--
-- A traveler who lives where Stripe can pay out to a bank from Nata's US
-- account (the US, the UK, the EEA, Canada and Switzerland: Stripe Connect's
-- cross-border payouts) connects their bank through Stripe: an Express
-- connected account, set up on Stripe's own pages (the stripe-connect
-- function). Stripe checks their identity and bank account; once it allows
-- payouts, the account becomes one of the traveler's payout accounts (kind
-- bank). Each payout is then a Stripe transfer, in US dollars, to that
-- account, and Stripe pays it out to the bank. Travelers living elsewhere
-- keep mobile money (pawaPay).
--
--   * nata.stripe_accounts: the traveler's Stripe account and whether Stripe
--     allows payouts on it (kept in step by stripe-connect and
--     stripe-webhook).
--   * nata.payout_destinations: a Stripe account is account_bank 'STRIPE',
--     account_number its id (acct_...), currency USD.
--   * nata.claim_payouts(): also claims payouts to a Stripe account that
--     Stripe allows payouts on; send-payouts sends them as transfers. A
--     payout goes to the account picked at delivery while Nata can still
--     pay it, else to the traveler's default account: an account saved for
--     Flutterwave (no longer used) no longer holds a payout back once the
--     traveler connects their bank through Stripe or adds mobile money.
--   * Payouts Flutterwave refused ("merchant is not enabled to make
--     transfers") are queued again, to go out once the traveler has an
--     account Nata can pay.

-- -----------------------------------------------------------------------------
-- 1. Travelers' Stripe accounts
-- -----------------------------------------------------------------------------
create table if not exists nata.stripe_accounts (
  user_id            uuid primary key references auth.users (id) on delete cascade,
  account_id         text not null unique check (account_id ~ '^acct_[A-Za-z0-9]+$'),
  country            char(2) not null,
  -- The traveler finished Stripe's form (Stripe may still be checking it).
  details_submitted  boolean not null default false,
  -- Stripe pays out to the traveler's bank.
  payouts_enabled    boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

alter table nata.stripe_accounts enable row level security;
-- No policies: read and written by the payment functions only.
revoke all on nata.stripe_accounts from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Claiming payouts: pawaPay networks, and Stripe accounts that can be paid
-- -----------------------------------------------------------------------------
create or replace function nata.claim_payouts(p_traveler uuid default null)
returns table (
  payout_id       uuid,
  reference       text,
  amount          numeric,
  currency        text,
  account_bank    text,
  account_number  text,
  holder_name     text,
  debit_currency  text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  p          record;
  dest       record;
  sent       numeric;
begin
  for p in
    select po.*
      from nata.payouts po
     where po.status = 'pending'
       and (p_traveler is null or po.traveler_id = p_traveler)
     order by po.created_at
     for update skip locked
  loop
    -- The account picked at delivery, else the default; only one Nata can
    -- send to: a pawaPay network, or a Stripe account Stripe allows payouts
    -- on. Other accounts (a bank saved for Flutterwave) are passed over, and
    -- with nothing to send to the payout waits.
    select d.account_bank, d.account_number, d.currency, a.holder_name, a.id
      into dest
      from nata.payout_accounts a
      join nata.payout_destinations d on d.account_id = a.id
     where a.user_id = p.traveler_id
       and (a.id = p.payout_account_id or a.is_default)
       and (
         exists (select 1 from nata.mobile_money_networks n
                  where n.provider = d.account_bank)
         or (d.account_bank = 'STRIPE' and exists (
               select 1 from nata.stripe_accounts s
                where s.account_id = d.account_number
                  and s.user_id = p.traveler_id
                  and s.payouts_enabled)))
     order by (a.id is not distinct from p.payout_account_id) desc
     limit 1;
    continue when not found;

    if dest.currency = p.currency then
      sent := p.amount;
    elsif dest.currency = 'USD' then
      -- Stripe transfers are in cents: keep them.
      sent := floor(p.amount / nata.recent_rate(p.currency)
                    * nata.recent_rate(dest.currency) * 100) / 100;
    else
      sent := floor(p.amount / nata.recent_rate(p.currency)
                    * nata.recent_rate(dest.currency));
    end if;
    continue when sent is null or sent <= 0;

    update nata.payouts po
       set status = 'processing',
           reference = coalesce(po.reference, 'nata-payout-' || po.id::text),
           payout_account_id = dest.id,
           payout_amount = sent,
           payout_currency = dest.currency,
           sent_at = now(),
           failure_reason = null,
           updated_at = now()
     where po.id = p.id;

    return query
      select p.id, coalesce(p.reference, 'nata-payout-' || p.id::text), sent,
             dest.currency::text, dest.account_bank, dest.account_number,
             dest.holder_name, p.currency::text;
  end loop;
end;
$$;

revoke all on function nata.claim_payouts(uuid) from public;
revoke all on function nata.claim_payouts(uuid) from anon, authenticated;
grant execute on function nata.claim_payouts(uuid) to service_role;

-- -----------------------------------------------------------------------------
-- 3. Payouts Flutterwave refused: queued again
-- -----------------------------------------------------------------------------
update nata.payouts
   set status = 'pending',
       failure_reason = null,
       updated_at = now()
 where status = 'failed'
   and failure_reason ilike '%merchant is not enabled to make transfers%';
