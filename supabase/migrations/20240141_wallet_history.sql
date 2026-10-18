-- Wallet history: the signed-in user's payouts (as a traveler) and payments
-- (as a sender), newest first, with the item and route they were for.
--
-- Run AFTER 20240140_payouts.sql. Safe to re-run.
--
-- Payments that never went through (pending or failed) are left out; they
-- never moved any money.

drop function if exists public.wallet_history(integer);
create function public.wallet_history(p_limit integer default 100)
returns table (
  kind            text,      -- 'payout' or 'payment'
  id              uuid,
  amount          numeric,
  currency        text,
  status          text,
  created_at      timestamptz,
  item            text,
  from_city       text,
  to_city         text,
  other_name      text       -- the sender (payout) or traveler (payment)
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from (
    select
      'payout'::text,
      po.id,
      po.amount,
      coalesce(po.currency, pa.currency)::text,
      po.status,
      po.created_at,
      r.item_description,
      dc.name,
      ac.name,
      sp.first_name
    from nata.payouts po
    left join nata.payments pa         on pa.id = po.payment_id
    left join nata.delivery_requests r on r.id = pa.request_id
    left join nata.trips t             on t.id = r.trip_id
    left join nata.cities dc           on dc.id = t.departure_city_id
    left join nata.cities ac           on ac.id = t.arrival_city_id
    left join nata.profiles sp         on sp.id = r.sender_id
    where po.traveler_id = auth.uid()

    union all

    select
      'payment'::text,
      pa.id,
      pa.amount,
      pa.currency::text,
      pa.status,
      coalesce(pa.completed_at, pa.created_at),
      r.item_description,
      dc.name,
      ac.name,
      tp.first_name
    from nata.payments pa
    join nata.delivery_requests r on r.id = pa.request_id
    join nata.trips t             on t.id = r.trip_id
    left join nata.cities dc      on dc.id = t.departure_city_id
    left join nata.cities ac      on ac.id = t.arrival_city_id
    left join nata.profiles tp    on tp.id = t.traveler_id
    where pa.sender_id = auth.uid()
      and pa.status in ('held', 'released', 'refunded')
  ) h
  order by h.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

revoke all on function public.wallet_history(integer) from public, anon;
grant execute on function public.wallet_history(integer) to authenticated;
