-- No more carrying limits or deposits.
--
-- Run AFTER 20240201_delivery_checkins.sql. Safe to re-run.
--
-- Travelers had a carrying limit (20240194, 20240197) and paid a refundable
-- deposit before picking up items worth more (20240195). Both are gone, along
-- with the sealed box policy (which was only text in the app).
--
--   * nata.deposit_due(): never due. So public.mark_picked_up no longer waits
--     for a deposit, create-payment refuses to start one ("not_payable"), and
--     public.request_deposit answers "required: false" to older app builds.
--   * public.my_carry_limit() stays for older app builds; nothing reads it.
--
-- No deposit was ever paid, so nothing is refunded here. Items keep their
-- estimated values and receipts.

drop function if exists nata.deposit_due(uuid);

create function nata.deposit_due(p_request_id uuid)
returns table (required boolean, amount numeric, currency text,
               declared_usd numeric, limit_usd numeric,
               limit_amount numeric, limit_currency text)
language sql
stable
security definer
set search_path = ''
as $$
  select false, null::numeric, null::text, null::numeric, null::numeric,
         null::numeric, null::text;
$$;

revoke all on function nata.deposit_due(uuid) from public, anon, authenticated;
grant execute on function nata.deposit_due(uuid) to service_role;
