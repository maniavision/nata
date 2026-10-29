-- Mobile money payouts in whole amounts.
--
-- Run AFTER 20240191_account_deletion_grace.sql. Safe to re-run.
--
-- A payout to mobile money was sent with decimals when it was already in the
-- wallet's currency (7651.87 XAF), and pawaPay refuses decimals on XAF, XOF
-- and most networks. nata.claim_payouts() now always sends a whole amount to
-- mobile money (rounded down; payments in are already rounded up, 20240165),
-- and keeps cents for Stripe transfers. payout_amount records what was sent.
-- Payouts already marked failed for this reason are put back in the queue.

CREATE OR REPLACE FUNCTION nata.claim_payouts(p_traveler uuid DEFAULT NULL::uuid, p_withdraw boolean DEFAULT false)
 RETURNS TABLE(payout_id uuid, reference text, amount numeric, currency text, account_bank text, account_number text, holder_name text, debit_currency text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
       and po.amount > po.spent_amount
       -- Kept in the Nata balance (20240187): refunds to the balance, and
       -- earnings of members who keep them, leave only on Withdraw.
       and (p_withdraw
            or (po.kind = 'earning'
                and not exists (
                  select 1 from nata.payment_preferences pp
                   where pp.user_id = po.traveler_id
                     and pp.payout_schedule = 'manual')))
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

    -- What's left of it (part may have been spent from the balance), in the
    -- account's currency.
    if dest.currency = p.currency then
      sent := p.amount - p.spent_amount;
    else
      sent := (p.amount - p.spent_amount) / nata.recent_rate(p.currency)
              * nata.recent_rate(dest.currency);
    end if;
    if dest.account_bank = 'STRIPE' then
      -- Stripe transfers are in cents: keep them.
      sent := floor(sent * 100) / 100;
    else
      -- Mobile money is paid in whole amounts (20240192): pawaPay refuses
      -- decimals on XAF, XOF and most other networks.
      sent := floor(sent);
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
$function$;

revoke all on function nata.claim_payouts(uuid, boolean)
  from public, anon, authenticated;
grant execute on function nata.claim_payouts(uuid, boolean) to service_role;

-- Payouts pawaPay refused for their decimals go out again with the next run.
update nata.payouts
   set status = 'pending', failure_reason = null, updated_at = now()
 where status = 'failed'
   and failure_reason ilike '%decimal%';
