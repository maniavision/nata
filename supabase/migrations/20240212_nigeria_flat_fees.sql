-- Flat Nata fees in naira for senders living in Nigeria.
--
-- Run AFTER 20240211_sender_handover_photo.sql. Safe to re-run.
--
-- Senders living in Nigeria paid the "rest of Africa" fee in dollars
-- ($2.08 local, $3.12 international). They now pay in naira:
--
--   lives in                         local       international
--   Nigeria                          ₦3,000      ₦4,200
--   XAF / XOF countries              1,976       5,200   (their own franc)
--   rest of Africa                   $2.08       $3.12
--   USA / Canada                     $2.36       $3.39
--   Europe                           €2.36       €3.39
--   UK                               £2.36       £3.39
--   anywhere else / unknown          $2.99       $4.99
--
-- Only the Nigeria row changes (20240203 otherwise). Local still means the
-- trip stays in one country. Requests already sent keep the fee they were
-- sent with. Flutterwave charges a naira fee as it is (nata.naira_amount).

create or replace function nata.flat_fee(p_sender uuid, p_trip uuid)
returns table (amount numeric, currency text, is_local boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with place as (
    select upper(btrim(coalesce(p.country_of_residence::text, ''))) as res,
           c.continent::text as continent,
           upper(btrim(c.currency_code::text)) as cur
      from nata.profiles p
      left join nata.countries c
        on c.iso_code = upper(btrim(p.country_of_residence::text))
     where p.id = p_sender
  ), route as (
    select dc.country_code = ac.country_code as is_local
      from nata.trips t
      join nata.cities dc on dc.id = t.departure_city_id
      join nata.cities ac on ac.id = t.arrival_city_id
     where t.id = p_trip
  ), region as (
    select case
             when pl.cur in ('XAF', 'XOF')           then 'cfa'
             when pl.res = 'NG'                      then 'ng'
             when pl.continent = 'AF'                then 'af'
             when pl.res in ('US', 'CA')             then 'na'
             when pl.res in ('GB', 'GG', 'JE', 'IM') then 'uk'
             when pl.continent = 'EU'                then 'eu'
             else 'other'
           end as r,
           pl.cur
      from (select 1) one left join place pl on true
  )
  select case rg.r
           when 'cfa' then case when ro.is_local then 1976 else 5200 end
           when 'ng'  then case when ro.is_local then 3000 else 4200 end
           when 'af'  then case when ro.is_local then 2.08 else 3.12 end
           when 'other' then case when ro.is_local then 2.99 else 4.99 end
           else case when ro.is_local then 2.36 else 3.39 end
         end::numeric,
         case rg.r
           when 'cfa' then rg.cur
           when 'ng'  then 'NGN'
           when 'eu'  then 'EUR'
           when 'uk'  then 'GBP'
           else 'USD'
         end,
         ro.is_local
    from route ro, region rg;
$$;

revoke all on function nata.flat_fee(uuid, uuid) from public;
