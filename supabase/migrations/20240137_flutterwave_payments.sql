-- Paying into escrow with Flutterwave.
--
-- Run AFTER 20240136_ticket_shared_copy.sql. Safe to re-run.
--
-- The sender pays on Flutterwave's own page (card, mobile money, Apple Pay):
-- card numbers and wallet PINs never reach the app or this database.
--
--   1. The app asks the create-payment edge function for a payment link. It
--      checks the request can be paid and records a pending nata.payments row
--      with the amount and currency fixed when the traveler accepted.
--   2. The sender pays on that link.
--   3. Flutterwave tells the flutterwave-webhook edge function, and the app
--      asks verify-payment. Both confirm the transaction with Flutterwave
--      before calling nata.complete_payment: the payment is then 'held' (in
--      escrow) and the request 'paid' (chat opens, see 20240130). It is
--      'released' to the traveler on delivery (nata.payouts), or 'refunded'.
--
-- nata.payments already existed (empty) with that life cycle; this adds what
-- Flutterwave needs. Only the edge functions (service role) write payments,
-- and a request only becomes 'paid' through nata.complete_payment.

-- -----------------------------------------------------------------------------
-- 1. Payments
-- -----------------------------------------------------------------------------
create table if not exists nata.payments (
  id                   uuid primary key default gen_random_uuid(),
  request_id           uuid not null references nata.delivery_requests (id) on delete restrict,
  sender_id            uuid not null references nata.profiles (id),
  amount               numeric not null check (amount >= 0),
  service_fee          numeric not null default 0 check (service_fee >= 0),
  currency             char(3) not null,
  method               text not null
                         check (method in ('card', 'apple_pay', 'google_pay', 'mobile_money')),
  provider             text not null,
  provider_payment_id  text unique,
  status               text not null default 'pending'
                         check (status in ('pending', 'held', 'released', 'refunded', 'failed')),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

alter table nata.payments
  -- Our reference, sent to Flutterwave and echoed back.
  add column if not exists tx_ref                 text,
  -- How it was paid (card, mobilemoneyfranco...).
  add column if not exists provider_payment_type  text,
  -- Paid, but the request could no longer take it (cancelled meanwhile, or
  -- paid twice): the money has to be refunded.
  add column if not exists needs_refund           boolean not null default false,
  add column if not exists completed_at           timestamptz;

create unique index if not exists payments_tx_ref_key on nata.payments (tx_ref);

-- A sender may try again after a failed or abandoned payment, so a request
-- can have several payment rows; only one of them holds its money.
alter table nata.payments drop constraint if exists payments_request_id_key;
create unique index if not exists payments_one_held_per_request
  on nata.payments (request_id)
  where status in ('held', 'released') and not needs_refund;

create index if not exists payments_request_idx on nata.payments (request_id);
create index if not exists payments_sender_idx on nata.payments (sender_id, created_at desc);

alter table nata.payments enable row level security;

drop policy if exists "Senders read their payments" on nata.payments;
create policy "Senders read their payments"
  on nata.payments for select
  to authenticated
  using (sender_id = auth.uid());

revoke insert, update, delete on nata.payments from anon, authenticated;

alter table nata.delivery_requests
  add column if not exists paid_at timestamptz;

-- -----------------------------------------------------------------------------
-- 2. Only a confirmed payment marks a request paid
-- -----------------------------------------------------------------------------
create or replace function nata.guard_paid_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid'
     and coalesce(current_setting('nata.completing_payment', true), '') <> 'on' then
    raise exception 'nata:payment_required';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_paid_status on nata.delivery_requests;
create trigger guard_paid_status
  before update of status on nata.delivery_requests
  for each row execute function nata.guard_paid_status();

-- -----------------------------------------------------------------------------
-- 3. Completing a payment (edge functions only)
-- -----------------------------------------------------------------------------
-- Called once Flutterwave confirmed the transaction. Returns:
--   'paid'          held in escrow; the request is now paid
--   'already_paid'  this payment was already recorded
--   'mismatch'      wrong amount or currency: not accepted, payment failed
--   'needs_refund'  held, but the request was already paid or was cancelled
--   'not_found'     no such payment
drop function if exists nata.complete_payment(text, text, numeric, text, text);

create or replace function nata.complete_payment(
  p_tx_ref          text,
  p_transaction_id  text,
  p_amount          numeric,
  p_currency        text,
  p_payment_type    text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay  record;
  req  record;
begin
  select * into pay from nata.payments where tx_ref = p_tx_ref for update;
  if not found then
    return 'not_found';
  end if;
  if pay.status <> 'pending' and pay.status <> 'failed' then
    return 'already_paid';
  end if;

  if upper(coalesce(p_currency, '')) <> pay.currency
     or coalesce(p_amount, 0) < pay.amount then
    update nata.payments
       set status = 'failed',
           provider_payment_id = p_transaction_id,
           provider_payment_type = p_payment_type,
           completed_at = now(),
           updated_at = now()
     where id = pay.id;
    return 'mismatch';
  end if;

  select id, status, expires_at into req
    from nata.delivery_requests
   where id = pay.request_id
   for update;

  -- Accepted, or expired while the sender was paying (started in time).
  if req.status = 'accepted'
     or (req.status = 'expired' and req.expires_at is not null
         and pay.created_at <= req.expires_at) then
    update nata.payments
       set status = 'held',
           provider_payment_id = p_transaction_id,
           provider_payment_type = p_payment_type,
           completed_at = now(),
           updated_at = now()
     where id = pay.id;
    perform set_config('nata.completing_payment', 'on', true);
    update nata.delivery_requests
       set status = 'paid', paid_at = now()
     where id = req.id;
    perform set_config('nata.completing_payment', 'off', true);
    return 'paid';
  end if;

  -- Already paid (paid twice, from two tabs), or cancelled meanwhile.
  update nata.payments
     set status = 'held',
         needs_refund = true,
         provider_payment_id = p_transaction_id,
         provider_payment_type = p_payment_type,
         completed_at = now(),
         updated_at = now()
   where id = pay.id;
  return 'needs_refund';
end;
$$;

revoke all on function nata.complete_payment(text, text, numeric, text, text) from public;
revoke all on function nata.complete_payment(text, text, numeric, text, text) from anon, authenticated;
grant execute on function nata.complete_payment(text, text, numeric, text, text) to service_role;

-- A payment Flutterwave reported as failed or cancelled.
drop function if exists nata.fail_payment(text, text);

create or replace function nata.fail_payment(p_tx_ref text, p_transaction_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.payments
     set status = 'failed',
         provider_payment_id = coalesce(p_transaction_id, provider_payment_id),
         completed_at = now(),
         updated_at = now()
   where tx_ref = p_tx_ref and status = 'pending';
$$;

revoke all on function nata.fail_payment(text, text) from public;
revoke all on function nata.fail_payment(text, text) from anon, authenticated;
grant execute on function nata.fail_payment(text, text) to service_role;
