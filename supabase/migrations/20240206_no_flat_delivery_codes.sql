-- No delivery code for flat requests.
--
-- Run AFTER 20240205_exact_conversions.sql. Safe to re-run.
--
-- A flat request has no recipient, and the sender confirms the delivery
-- (confirm_delivered), so its code was made and shown for nothing:
--   * nata.complete_payment() makes a code only for distance requests.
--   * public.my_delivery_code() returns nothing for flat requests.
--   * Codes already made for flat requests are deleted.

CREATE OR REPLACE FUNCTION nata.complete_payment(p_tx_ref text, p_transaction_id text, p_amount numeric, p_currency text, p_payment_type text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  -- A traveler's deposit (20240195): held, the request itself unchanged.
  -- One paid after the request closed, or a second one, goes back.
  if pay.purpose = 'deposit' then
    select r.id, r.status, r.sender_id into req
      from nata.delivery_requests r
     where r.id = pay.request_id
     for update;
    if req.status in ('accepted', 'paid')
       and not exists (select 1 from nata.payments o
                        where o.request_id = pay.request_id and o.id <> pay.id
                          and o.purpose = 'deposit' and not o.needs_refund
                          and o.status in ('held', 'released')) then
      update nata.payments
         set status = 'held',
             provider_payment_id = p_transaction_id,
             provider_payment_type = p_payment_type,
             completed_at = now(),
             updated_at = now()
       where id = pay.id;
      perform nata.notify(pay.sender_id, 'payment', 'deposit_held',
        'Deposit received',
        'Your deposit is held by Nata. You can pick up the items now; it is refunded once delivery is confirmed.',
        pay.request_id,
        jsonb_build_object('amount', pay.amount, 'currency', pay.currency,
                           'request_id', pay.request_id));
      perform nata.notify(req.sender_id, 'payment', 'deposit_paid',
        'Your traveler paid a deposit',
        'The traveler paid a refundable deposit for your items before pickup.',
        pay.request_id,
        jsonb_build_object('request_id', pay.request_id));
      return 'paid';
    end if;
    update nata.payments
       set status = 'held',
           needs_refund = true,
           provider_payment_id = p_transaction_id,
           provider_payment_type = p_payment_type,
           completed_at = now(),
           updated_at = now()
     where id = pay.id;
    perform nata.queue_refund(pay.id, false);
    return 'needs_refund';
  end if;

  select id, status, expires_at, pricing into req
    from nata.delivery_requests
   where id = pay.request_id
   for update;

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
    -- Flat requests have no recipient and no code.
    if req.pricing <> 'flat' then
      perform nata.issue_delivery_code(req.id);
    end if;
    return 'paid';
  end if;

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
$function$;

CREATE OR REPLACE FUNCTION public.my_delivery_code(p_request_id uuid)
 RETURNS TABLE(code text, sms_sent_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select c.code, c.sms_sent_at
    from nata.delivery_codes c
    join nata.delivery_requests r on r.id = c.request_id
   where c.request_id = p_request_id
     and r.sender_id = auth.uid()
     and r.status in ('paid', 'handed_off')
     and r.pricing <> 'flat';
$function$;

delete from nata.delivery_codes c
 using nata.delivery_requests r
 where r.id = c.request_id and r.pricing = 'flat';
