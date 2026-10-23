-- Mobile money through pawaPay.
--
-- Run AFTER 20240164_chat_closed_after_delivery.sql. Safe to re-run.
--
-- Every mobile money payment is now a pawaPay deposit: the sender picks their
-- network, enters their number and approves the prompt on their phone (no
-- payment page). Flutterwave keeps cards, Apple Pay and bank transfer.
--
--   * nata.mobile_money_networks: the networks pawaPay charges in each
--     country, with pawaPay's provider code. Mobile money is offered only in
--     these countries (before, every country whose currency Flutterwave took,
--     so all 12 CFA franc countries, even where it couldn't charge). Left
--     out: Wave (Senegal, Côte d'Ivoire), which sends the payer to its app,
--     and Orange Money Burkina Faso, which needs a code the payer dials
--     first.
--   * nata.mobile_money_charge(): refuses a country without networks.
--   * public.mobile_money_options(): each country also gives its calling
--     code and networks, so the app asks for the number and network.
--   * nata.refund_started(): a pawaPay refund keeps its id while pawaPay
--     processes it; send-refunds and pawapay-callback mark it sent
--     (nata.refund_sent) once pawaPay completes it, or failed.

-- -----------------------------------------------------------------------------
-- 1. The networks
-- -----------------------------------------------------------------------------
create table if not exists nata.mobile_money_networks (
  provider      text primary key,
  country_code  text not null,
  name          text not null,
  position      int not null default 0
);
create index if not exists mobile_money_networks_country_idx
  on nata.mobile_money_networks (country_code);
alter table nata.mobile_money_networks enable row level security;
revoke all on nata.mobile_money_networks from anon, authenticated;

insert into nata.mobile_money_networks (provider, country_code, name, position)
values
  ('MTN_MOMO_BEN',    'BJ', 'MTN Mobile Money', 1),
  ('MOOV_BEN',        'BJ', 'Moov Money',       2),
  ('MOOV_BFA',        'BF', 'Moov Money',       1),
  ('MTN_MOMO_CMR',    'CM', 'MTN Mobile Money', 1),
  ('ORANGE_CMR',      'CM', 'Orange Money',     2),
  ('MTN_MOMO_CIV',    'CI', 'MTN Mobile Money', 1),
  ('ORANGE_CIV',      'CI', 'Orange Money',     2),
  ('VODACOM_MPESA_COD','CD', 'M-Pesa',          1),
  ('AIRTEL_COD',      'CD', 'Airtel Money',     2),
  ('ORANGE_COD',      'CD', 'Orange Money',     3),
  ('AIRTEL_GAB',      'GA', 'Airtel Money',     1),
  ('MTN_MOMO_GHA',    'GH', 'MTN Mobile Money', 1),
  ('VODAFONE_GHA',    'GH', 'Telecel Cash',     2),
  ('AIRTELTIGO_GHA',  'GH', 'AirtelTigo Money', 3),
  ('MPESA_KEN',       'KE', 'M-Pesa',           1),
  ('MTN_MOMO_COG',    'CG', 'MTN Mobile Money', 1),
  ('AIRTEL_COG',      'CG', 'Airtel Money',     2),
  ('AIRTEL_MWI',      'MW', 'Airtel Money',     1),
  ('TNM_MWI',         'MW', 'TNM Mpamba',       2),
  ('VODACOM_MOZ',     'MZ', 'M-Pesa',           1),
  ('MOVITEL_MOZ',     'MZ', 'e-Mola',           2),
  ('MTN_MOMO_NGA',    'NG', 'MoMo PSB',         1),
  ('AIRTEL_NGA',      'NG', 'SmartCash',        2),
  ('MTN_MOMO_RWA',    'RW', 'MTN Mobile Money', 1),
  ('AIRTEL_RWA',      'RW', 'Airtel Money',     2),
  ('ORANGE_SEN',      'SN', 'Orange Money',     1),
  ('FREE_SEN',        'SN', 'Free Money',       2),
  ('VODACOM_TZA',     'TZ', 'M-Pesa',           1),
  ('AIRTEL_TZA',      'TZ', 'Airtel Money',     2),
  ('TIGO_TZA',        'TZ', 'Mixx by Yas',      3),
  ('HALOTEL_TZA',     'TZ', 'HaloPesa',         4),
  ('MTN_MOMO_UGA',    'UG', 'MTN Mobile Money', 1),
  ('AIRTEL_OAPI_UGA', 'UG', 'Airtel Money',     2),
  ('MTN_MOMO_ZMB',    'ZM', 'MTN Mobile Money', 1),
  ('AIRTEL_OAPI_ZMB', 'ZM', 'Airtel Money',     2),
  ('ZAMTEL_ZMB',      'ZM', 'Zamtel Kwacha',    3)
on conflict (provider) do update
  set country_code = excluded.country_code,
      name = excluded.name,
      position = excluded.position;

-- -----------------------------------------------------------------------------
-- 2. The amount to charge: only where a network is listed
-- -----------------------------------------------------------------------------
create or replace function nata.mobile_money_charge(p_request_id uuid, p_country text)
returns table (
  currency       text,
  amount         numeric,
  base_amount    numeric,
  base_currency  text,
  country_code   text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  req       record;
  local_cur text;
  from_rate numeric;
  to_rate   numeric;
begin
  select r.display_total, r.display_currency into req
    from nata.delivery_requests r where r.id = p_request_id;
  if not found or req.display_total is null or req.display_currency is null then
    raise exception 'nata:request_not_payable';
  end if;

  if not exists (select 1 from nata.mobile_money_networks n
                  where n.country_code = upper(btrim(p_country))) then
    raise exception 'nata:mobile_money_unavailable';
  end if;
  select upper(btrim(c.currency_code::text)) into local_cur
    from nata.countries c where c.iso_code = upper(btrim(p_country));
  if local_cur is null or local_cur = '' then
    raise exception 'nata:mobile_money_unavailable';
  end if;

  if local_cur = upper(btrim(req.display_currency::text)) then
    return query select local_cur, req.display_total, req.display_total,
                        upper(btrim(req.display_currency::text)), upper(btrim(p_country));
    return;
  end if;

  from_rate := nata.recent_rate(btrim(req.display_currency::text));
  to_rate := nata.recent_rate(local_cur);
  if from_rate is null or to_rate is null then
    raise exception 'nata:rate_unavailable';
  end if;

  -- A whole amount: most networks take no decimals.
  return query select local_cur,
                      ceil(req.display_total / from_rate * to_rate),
                      req.display_total,
                      upper(btrim(req.display_currency::text)),
                      upper(btrim(p_country));
end;
$$;

revoke all on function nata.mobile_money_charge(uuid, text) from public;
revoke all on function nata.mobile_money_charge(uuid, text) from anon, authenticated;
grant execute on function nata.mobile_money_charge(uuid, text) to service_role;

-- -----------------------------------------------------------------------------
-- 3. The sender's choices at checkout, with calling code and networks
-- -----------------------------------------------------------------------------
drop function if exists public.mobile_money_options(uuid);

create or replace function public.mobile_money_options(p_request_id uuid)
returns table (
  country_code  text,
  country_name  text,
  currency      text,
  amount        numeric,
  suggested     boolean,
  dial_code     text,
  networks      jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid        uuid := auth.uid();
  home       text;
  phone      text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (select 1 from nata.delivery_requests r
                  where r.id = p_request_id and r.sender_id = uid
                    and r.status = 'accepted' and r.display_total is not null) then
    raise exception 'nata:request_not_payable';
  end if;

  -- The country to suggest: the profile's, else the phone number's.
  select upper(btrim(p.country_of_residence::text)) into home
    from nata.profiles p where p.id = uid;
  if home is null or home = '' then
    select regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g') into phone
      from auth.users u where u.id = uid;
    if phone <> '' then
      select c.iso_code::text into home
        from nata.countries c
       where regexp_replace(coalesce(c.phone_code, ''), '[^0-9]', '', 'g') <> ''
         and phone like regexp_replace(c.phone_code, '[^0-9]', '', 'g') || '%'
       order by length(regexp_replace(c.phone_code, '[^0-9]', '', 'g')) desc
       limit 1;
    end if;
  end if;

  -- Countries are filtered first, so one without a rate can't fail the rest.
  return query
    with eligible as materialized (
      select c.iso_code::text as iso, c.name, c.phone_code
        from nata.countries c
       where exists (select 1 from nata.mobile_money_networks n
                      where n.country_code = c.iso_code::text)
         and nata.recent_rate(btrim(c.currency_code::text)) is not null
    )
    select e.iso,
           e.name,
           m.currency,
           m.amount,
           e.iso = coalesce(home, ''),
           '+' || regexp_replace(coalesce(e.phone_code, ''), '[^0-9]', '', 'g'),
           (select jsonb_agg(jsonb_build_object('code', n.provider, 'name', n.name)
                             order by n.position)
              from nata.mobile_money_networks n
             where n.country_code = e.iso)
      from eligible e
      cross join lateral nata.mobile_money_charge(p_request_id, e.iso) m
     order by e.name;
end;
$$;

revoke all on function public.mobile_money_options(uuid) from public;
grant execute on function public.mobile_money_options(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. pawaPay refunds finish later: keep the refund's id meanwhile
-- -----------------------------------------------------------------------------
create or replace function nata.refund_started(p_payment_id uuid, p_provider_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.payments
     set refund_provider_id = p_provider_id,
         updated_at = now()
   where id = p_payment_id and refund_status = 'processing';
$$;

revoke all on function nata.refund_started(uuid, text) from public, anon, authenticated;
grant execute on function nata.refund_started(uuid, text) to service_role;
