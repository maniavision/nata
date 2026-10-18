-- Refunds: giving senders their money back through Flutterwave.
--
-- Run AFTER 20240144_handover_photos.sql. Safe to re-run.
--
-- A held payment is refunded when:
--   * its request is cancelled after payment: everything except Nata's 10%
--     cancellation fee (10% of what was paid, rounded up, in the currency it
--     was paid in);
--   * it was flagged needs_refund (paid twice, or paid after the request was
--     cancelled or expired): in full.
--
-- The send-refunds edge function claims the pending refunds
-- (nata.claim_refunds), asks Flutterwave for each one and reports back
-- (nata.refund_sent / nata.refund_failed). A refunded payment's status
-- becomes 'refunded' and the sender is notified.

alter table nata.payments
  add column if not exists refund_amount      numeric,
  add column if not exists refund_status      text
    check (refund_status in ('pending', 'processing', 'refunded', 'failed')),
  add column if not exists refund_provider_id text,
  add column if not exists refund_failure     text,
  add column if not exists refunded_at        timestamptz;

create index if not exists payments_refund_pending_idx
  on nata.payments (refund_status) where refund_status = 'pending';

-- -----------------------------------------------------------------------------
-- 1. Queuing refunds
-- -----------------------------------------------------------------------------
create or replace function nata.queue_refund(p_payment_id uuid, p_keep_fee boolean)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.payments p
     set refund_amount = case
           when p_keep_fee then greatest(0, p.amount - ceil(p.amount * 0.10))
           else p.amount
         end,
         refund_status = 'pending',
         updated_at = now()
   where p.id = p_payment_id
     and p.status = 'held'
     and p.refund_status is null;
$$;

revoke all on function nata.queue_refund(uuid, boolean) from public, anon, authenticated;

-- A paid request is cancelled: refund its held payment, less the fee.
create or replace function nata.refund_on_cancel()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay uuid;
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    for pay in
      select p.id from nata.payments p
       where p.request_id = new.id and p.status = 'held'
    loop
      perform nata.queue_refund(pay, old.status in ('accepted', 'paid'));
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists refund_on_cancel on nata.delivery_requests;
create trigger refund_on_cancel
  after update of status on nata.delivery_requests
  for each row execute function nata.refund_on_cancel();

-- A payment flagged needs_refund: refund it in full.
create or replace function nata.refund_flagged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.needs_refund and new.status = 'held' and new.refund_status is null then
    perform nata.queue_refund(new.id, false);
  end if;
  return new;
end;
$$;

drop trigger if exists refund_flagged on nata.payments;
create trigger refund_flagged
  after insert or update of needs_refund, status on nata.payments
  for each row execute function nata.refund_flagged();

-- Payments that were already waiting for a refund.
select nata.queue_refund(p.id, false)
  from nata.payments p
 where p.needs_refund and p.status = 'held' and p.refund_status is null;

select nata.queue_refund(p.id, true)
  from nata.payments p
  join nata.delivery_requests r on r.id = p.request_id
 where r.status = 'cancelled' and p.status = 'held' and p.refund_status is null;

-- -----------------------------------------------------------------------------
-- 2. Sending them (edge function send-refunds, service role)
-- -----------------------------------------------------------------------------
drop function if exists nata.claim_refunds(uuid);
create function nata.claim_refunds(p_sender uuid default null)
returns table (
  payment_id     uuid,
  transaction_id text,
  amount         numeric,
  currency       text
)
language sql
security definer
set search_path = ''
as $$
  update nata.payments p
     set refund_status = 'processing', updated_at = now()
   where p.refund_status = 'pending'
     and p.provider_payment_id is not null
     and (p_sender is null or p.sender_id = p_sender)
  returning p.id, p.provider_payment_id, p.refund_amount, p.currency::text;
$$;

drop function if exists nata.refund_sent(uuid, text);
create function nata.refund_sent(p_payment_id uuid, p_provider_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pay record;
begin
  update nata.payments
     set status = 'refunded',
         refund_status = 'refunded',
         refund_provider_id = p_provider_id,
         refund_failure = null,
         refunded_at = now(),
         updated_at = now()
   where id = p_payment_id and refund_status = 'processing'
  returning sender_id, request_id, refund_amount, currency into pay;
  if found then
    perform nata.notify(pay.sender_id, 'payment', 'refund_sent',
      'Refund sent',
      'Your refund of ' || pay.currency || ' ' || pay.refund_amount::text
        || ' is on its way.',
      pay.request_id,
      jsonb_build_object('amount', pay.refund_amount,
                         'currency', pay.currency));
  end if;
end;
$$;

-- [p_retry]: it may not have reached Flutterwave, so try again later;
-- otherwise support looks at Flutterwave's reason.
drop function if exists nata.refund_failed(uuid, text, boolean);
create function nata.refund_failed(
  p_payment_id uuid,
  p_reason     text,
  p_retry      boolean default false
)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.payments
     set refund_status = case when p_retry then 'pending' else 'failed' end,
         refund_failure = left(coalesce(p_reason, ''), 300),
         updated_at = now()
   where id = p_payment_id and refund_status = 'processing';
$$;

revoke all on function nata.claim_refunds(uuid) from public, anon, authenticated;
revoke all on function nata.refund_sent(uuid, text) from public, anon, authenticated;
revoke all on function nata.refund_failed(uuid, text, boolean) from public, anon, authenticated;
grant execute on function nata.claim_refunds(uuid) to service_role;
grant execute on function nata.refund_sent(uuid, text) to service_role;
grant execute on function nata.refund_failed(uuid, text, boolean) to service_role;
