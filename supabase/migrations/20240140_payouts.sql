-- Paying travelers: where their payouts go, and sending them with
-- Flutterwave transfers.
--
-- Run AFTER 20240139_delivery_handover.sql. Safe to re-run.
--
--   * nata.payout_destinations: the full account / phone number and the
--     Flutterwave bank code of each payout account. Written by the
--     add-payout-account edge function, read only by the server; the app
--     only ever sees nata.payout_accounts (last 4 digits).
--   * nata.claim_payouts(): the send-payouts edge function takes the pending
--     payouts that have somewhere to go (the account chosen at delivery, else
--     the traveler's default), marks them processing with a reference that
--     Flutterwave refuses twice, and gets the amount in the account's
--     currency.
--   * nata.release_payout() / nata.retry_payout(): what Flutterwave answered.
--     A paid payout releases the escrow payment.
--   * Travelers read their own payouts (the wallet on Profile).

-- -----------------------------------------------------------------------------
-- 1. Where payouts go
-- -----------------------------------------------------------------------------
create table if not exists nata.payout_destinations (
  account_id      uuid primary key references nata.payout_accounts (id) on delete cascade,
  -- Flutterwave's bank code (044, MPS, FMM...).
  account_bank    text not null,
  -- The account number, or the mobile money number with its country code.
  account_number  text not null,
  currency        char(3) not null check (currency ~ '^[A-Z]{3}$'),
  created_at      timestamptz not null default now()
);

alter table nata.payout_destinations enable row level security;
revoke all on nata.payout_destinations from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Payouts
-- -----------------------------------------------------------------------------
alter table nata.payouts
  -- Our reference for the transfer, unique so it is never sent twice.
  add column if not exists reference        text,
  -- What was sent, in the payout account's currency.
  add column if not exists payout_amount    numeric,
  add column if not exists payout_currency  char(3),
  add column if not exists sent_at          timestamptz,
  add column if not exists failure_reason   text;

create unique index if not exists payouts_reference_key on nata.payouts (reference);

drop policy if exists "Travelers read their payouts" on nata.payouts;
create policy "Travelers read their payouts"
  on nata.payouts for select
  to authenticated
  using (traveler_id = auth.uid());

revoke insert, update, delete on nata.payouts from anon, authenticated;

-- Takes the pending payouts that can be sent (of [p_traveler], or everyone's)
-- and marks them processing. Payouts without a payout account, or without a
-- recent exchange rate for the conversion, stay pending.
drop function if exists nata.claim_payouts(uuid);

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
    select d.account_bank, d.account_number, d.currency, a.holder_name, a.id
      into dest
      from nata.payout_accounts a
      join nata.payout_destinations d on d.account_id = a.id
     where a.user_id = p.traveler_id
       and a.id = coalesce(
             p.payout_account_id,
             (select x.id from nata.payout_accounts x
               where x.user_id = p.traveler_id and x.is_default limit 1));
    continue when not found;

    if dest.currency = p.currency then
      sent := p.amount;
    else
      sent := floor(p.amount / nata.recent_rate(p.currency)
                    * nata.recent_rate(dest.currency));
    end if;
    continue when sent is null or sent <= 0;

    update nata.payouts
       set status = 'processing',
           reference = coalesce(reference, 'nata-payout-' || id::text),
           payout_account_id = dest.id,
           payout_amount = sent,
           payout_currency = dest.currency,
           sent_at = now(),
           failure_reason = null,
           updated_at = now()
     where id = p.id;

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

-- Flutterwave accepted the transfer: keep its id.
drop function if exists nata.payout_accepted(text, text);

create or replace function nata.payout_accepted(p_reference text, p_provider_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.payouts
     set provider_payout_id = coalesce(p_provider_id, provider_payout_id),
         updated_at = now()
   where reference = p_reference;
$$;

-- The transfer went through: paid, and the escrow payment released.
drop function if exists nata.release_payout(text, text);

create or replace function nata.release_payout(p_reference text, p_provider_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  po record;
begin
  update nata.payouts
     set status = 'paid',
         paid_at = coalesce(paid_at, now()),
         provider_payout_id = coalesce(p_provider_id, provider_payout_id),
         failure_reason = null,
         updated_at = now()
   where reference = p_reference
  returning payment_id into po;
  if found then
    update nata.payments
       set status = 'released', updated_at = now()
     where id = po.payment_id and status = 'held';
  end if;
end;
$$;

-- The transfer failed. [p_retry]: it may not have reached Flutterwave (a
-- network error), so it goes back to pending and is tried again with the
-- same reference; otherwise it is failed with Flutterwave's reason (a wrong
-- account) for support to look at.
drop function if exists nata.payout_failed(text, text, boolean);

create or replace function nata.payout_failed(
  p_reference text,
  p_reason    text,
  p_retry     boolean default false
)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.payouts
     set status = case when p_retry then 'pending' else 'failed' end,
         failure_reason = left(coalesce(p_reason, ''), 300),
         updated_at = now()
   where reference = p_reference and status <> 'paid';
$$;

revoke all on function nata.payout_accepted(text, text) from public, anon, authenticated;
revoke all on function nata.release_payout(text, text) from public, anon, authenticated;
revoke all on function nata.payout_failed(text, text, boolean) from public, anon, authenticated;
grant execute on function nata.payout_accepted(text, text) to service_role;
grant execute on function nata.release_payout(text, text) to service_role;
grant execute on function nata.payout_failed(text, text, boolean) to service_role;
