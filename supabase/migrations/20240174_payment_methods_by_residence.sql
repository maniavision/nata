-- Saved payment methods follow where the member lives, like checkout.
--
-- Run AFTER 20240173_checkout_by_residence.sql. Safe to re-run.
--
-- A member who lives (nata.profiles.country_of_residence) in a country where
-- pawaPay takes mobile money (nata.mobile_money_networks) saves only mobile
-- money wallets, on one of their country's networks; everyone else saves
-- only cards and Apple Pay. Checkout fills in the saved wallet.
--
--   * nata.payment_methods.mobile_network: the wallet's pawaPay network
--     (its provider code), saved by the app; mobile_provider keeps the
--     network's name, and is no longer limited to the four names of 20240124.
--   * nata.payment_methods_by_residence(): refuses a method that doesn't fit
--     (nata:method_not_offered, nata:network_not_offered).
--   * public.my_payment_options(): the member's country, its calling code,
--     whether they pay by mobile money, and its networks.

alter table nata.payment_methods
  drop constraint if exists payment_methods_mobile_provider_check;
alter table nata.payment_methods
  add column if not exists mobile_network text
    references nata.mobile_money_networks (provider) on delete set null;
-- The app saves it with the wallet (20240124 grants insert column by column).
grant insert (mobile_network) on nata.payment_methods to authenticated;

-- -----------------------------------------------------------------------------
-- 1. Only what fits where the member lives
-- -----------------------------------------------------------------------------
create or replace function nata.payment_methods_by_residence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  home   text;
  lives  boolean;
  net    record;
begin
  select upper(btrim(p.country_of_residence::text)) into home
    from nata.profiles p where p.id = new.user_id;
  lives := exists (select 1 from nata.mobile_money_networks n
                    where n.country_code = coalesce(home, ''));

  if (new.kind = 'mobile_money') <> lives then
    raise exception 'nata:method_not_offered';
  end if;

  if new.kind = 'mobile_money' then
    select n.provider, n.name into net
      from nata.mobile_money_networks n
     where n.provider = new.mobile_network and n.country_code = home;
    if not found then
      raise exception 'nata:network_not_offered';
    end if;
    new.mobile_provider := net.name;
  end if;
  return new;
end;
$$;

drop trigger if exists payment_methods_by_residence on nata.payment_methods;
create trigger payment_methods_by_residence
  before insert or update of kind, mobile_network on nata.payment_methods
  for each row execute function nata.payment_methods_by_residence();

-- -----------------------------------------------------------------------------
-- 2. What the member can save
-- -----------------------------------------------------------------------------
create or replace function public.my_payment_options()
returns table (
  country_code  text,
  country_name  text,
  dial_code     text,
  mobile_money  boolean,
  networks      jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select home.iso,
         coalesce(c.name, ''),
         '+' || regexp_replace(coalesce(c.phone_code, ''), '[^0-9]', '', 'g'),
         exists (select 1 from nata.mobile_money_networks n
                  where n.country_code = home.iso),
         coalesce((select jsonb_agg(jsonb_build_object('code', n.provider, 'name', n.name)
                                    order by n.position)
                     from nata.mobile_money_networks n
                    where n.country_code = home.iso), '[]'::jsonb)
    from (select upper(btrim(p.country_of_residence::text)) as iso
            from nata.profiles p where p.id = auth.uid()) home
    left join nata.countries c on c.iso_code::text = home.iso;
$$;

revoke all on function public.my_payment_options() from public, anon;
grant execute on function public.my_payment_options() to authenticated;
