-- Payouts can be claimed again.
--
-- Run AFTER 20240149_payouts_method_optional.sql. Safe to re-run.
--
-- nata.claim_payouts (20240140) returns a column named reference, like the
-- payouts column it updates, so its update failed with "column reference
-- reference is ambiguous" and send-payouts never sent anything. The same
-- function, with the payouts columns qualified.

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
