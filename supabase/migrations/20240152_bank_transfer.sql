-- Paying by bank transfer.
--
-- Run AFTER 20240151_payouts_from_database.sql. Safe to re-run.
--
-- Flutterwave's bank transfer gives the sender a temporary Nigerian bank
-- account to pay into, in naira. As with mobile money, the request's fixed
-- price is converted into NGN at the latest rate (nata.local_charge); the
-- fixed price is kept as base_amount. Checkout shows the NGN amount first
-- (public.bank_transfer_quote) and create-payment charges it.

alter table nata.payments drop constraint if exists payments_method_check;
alter table nata.payments add constraint payments_method_check
  check (method in ('card', 'apple_pay', 'google_pay', 'mobile_money',
                    'bank_transfer'));

-- The request's fixed price in [p_currency], converted at the latest rate.
-- Raises nata:rate_unavailable without a recent rate, nata:request_not_payable
-- when there is no fixed price.
create or replace function nata.local_charge(p_request_id uuid, p_currency text)
returns table (
  currency       text,
  amount         numeric,
  base_amount    numeric,
  base_currency  text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  req       record;
  to_cur    text := upper(btrim(p_currency));
  from_cur  text;
  from_rate numeric;
  to_rate   numeric;
begin
  select r.display_total, r.display_currency into req
    from nata.delivery_requests r where r.id = p_request_id;
  if not found or req.display_total is null or req.display_currency is null then
    raise exception 'nata:request_not_payable';
  end if;
  from_cur := upper(btrim(req.display_currency::text));

  if to_cur = from_cur then
    return query select to_cur, req.display_total, req.display_total, from_cur;
    return;
  end if;

  from_rate := nata.recent_rate(from_cur);
  to_rate := nata.recent_rate(to_cur);
  if from_rate is null or to_rate is null then
    raise exception 'nata:rate_unavailable';
  end if;

  return query select to_cur,
                      ceil(req.display_total / from_rate * to_rate),
                      req.display_total,
                      from_cur;
end;
$$;

revoke all on function nata.local_charge(uuid, text) from public, anon, authenticated;
grant execute on function nata.local_charge(uuid, text) to service_role;

-- What the sender pays by bank transfer: the amount in naira.
create or replace function public.bank_transfer_quote(p_request_id uuid)
returns table (currency text, amount numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (select 1 from nata.delivery_requests r
                  where r.id = p_request_id and r.sender_id = auth.uid()
                    and r.status = 'accepted' and r.display_total is not null) then
    raise exception 'nata:request_not_payable';
  end if;

  return query
    select c.currency, c.amount
      from nata.local_charge(p_request_id, 'NGN') c;
end;
$$;

revoke all on function public.bank_transfer_quote(uuid) from public, anon;
grant execute on function public.bank_transfer_quote(uuid) to authenticated;
