-- How a request is paid depends on where the sender and the traveler live.
--
-- Run AFTER 20240172_stripe_bank_added_once.sql. Safe to re-run.
--
-- When both live (nata.profiles.country_of_residence) in a country where
-- pawaPay takes mobile money (nata.mobile_money_networks), the request is
-- paid by mobile money only: the money then stays with pawaPay, which also
-- pays the traveler. Otherwise it is paid by card or Apple Pay through
-- Stripe, with no mobile money. A member without a country of residence
-- counts as not living in such a country.
--
--   * nata.checkout_kind(p_request_id): 'mobile_money' or 'card', for
--     create-payment (service role), which refuses the other methods.
--   * public.checkout_kind(p_request_id): the same, for the request's sender
--     (checkout shows only those methods).

create or replace function nata.checkout_kind(p_request_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when exists (select 1 from nata.mobile_money_networks n
                         where n.country_code = upper(btrim(sp.country_of_residence::text)))
            and exists (select 1 from nata.mobile_money_networks n
                         where n.country_code = upper(btrim(tp.country_of_residence::text)))
           then 'mobile_money'
           else 'card'
         end
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
    left join nata.profiles sp on sp.id = r.sender_id
    left join nata.profiles tp on tp.id = t.traveler_id
   where r.id = p_request_id;
$$;

revoke all on function nata.checkout_kind(uuid) from public, anon, authenticated;
grant execute on function nata.checkout_kind(uuid) to service_role;

create or replace function public.checkout_kind(p_request_id uuid)
returns text
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
                  where r.id = p_request_id and r.sender_id = auth.uid()) then
    raise exception 'nata:request_not_found';
  end if;
  return nata.checkout_kind(p_request_id);
end;
$$;

revoke all on function public.checkout_kind(uuid) from public, anon;
grant execute on function public.checkout_kind(uuid) to authenticated;
