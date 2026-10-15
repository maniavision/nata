-- Payment settings: how a user pays (payment methods), where their earnings
-- go (payout accounts) and when (payment preferences). The default currency
-- is nata.user_settings.currency_code and is not repeated here.
--
-- Card data: only what is safe to show is kept (brand, last 4 digits,
-- expiry, holder name). A full card number or CVV must never reach this
-- database; once payments are connected, the payment provider stores them
-- and `provider_ref` holds its token.
--
-- Safe to re-run.

-- ── Payment methods ─────────────────────────────────────────────────────────

create table if not exists nata.payment_methods (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references auth.users (id) on delete cascade,
  kind                    text not null check (kind in ('card', 'mobile_money', 'apple_pay')),
  is_default              boolean not null default false,

  -- kind = 'card'
  card_brand              text check (card_brand in ('Visa', 'Mastercard', 'American Express', 'Card')),
  card_last4              text check (card_last4 ~ '^[0-9]{4}$'),
  card_exp_month          smallint check (card_exp_month between 1 and 12),
  card_exp_year           smallint check (card_exp_year between 2000 and 2100),
  card_holder_name        text check (char_length(btrim(card_holder_name)) between 2 and 80),

  -- kind = 'mobile_money'
  mobile_provider         text check (mobile_provider in ('M-Pesa', 'MTN Mobile Money', 'Airtel Money', 'Orange Money')),
  mobile_number           text check (mobile_number ~ '^\+[1-9][0-9]{7,14}$'),
  mobile_registered_name  text check (char_length(btrim(mobile_registered_name)) between 2 and 80),

  -- kind = 'apple_pay'
  wallet_device_label     text check (char_length(wallet_device_label) <= 80),

  -- The payment provider's token for this method, once payments are live.
  provider_ref            text,
  created_at              timestamptz not null default now(),

  constraint payment_methods_card_fields check (
    kind <> 'card' or (
      card_brand is not null and card_last4 is not null
      and card_exp_month is not null and card_exp_year is not null
      and card_holder_name is not null
    )
  ),
  constraint payment_methods_mobile_fields check (
    kind <> 'mobile_money' or (
      mobile_provider is not null and mobile_number is not null
      and mobile_registered_name is not null
    )
  )
);

create index if not exists payment_methods_user_idx
  on nata.payment_methods (user_id, created_at);

-- At most one default per user.
create unique index if not exists payment_methods_one_default
  on nata.payment_methods (user_id) where is_default;

-- ── Payout accounts ─────────────────────────────────────────────────────────

create table if not exists nata.payout_accounts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  kind             text not null check (kind in ('bank', 'mobile_money')),
  is_default       boolean not null default false,
  -- Bank or mobile money provider name, e.g. "Barclays Bank", "M-Pesa".
  institution_name text not null check (char_length(btrim(institution_name)) between 2 and 80),
  country_code     char(2) references nata.countries (iso_code) on update cascade,
  -- Last digits of the account / IBAN / phone number, for display only.
  account_last4    text not null check (account_last4 ~ '^[0-9A-Z]{4}$'),
  holder_name      text not null check (char_length(btrim(holder_name)) between 2 and 80),
  provider_ref     text,
  created_at       timestamptz not null default now()
);

create index if not exists payout_accounts_user_idx
  on nata.payout_accounts (user_id, created_at);

create unique index if not exists payout_accounts_one_default
  on nata.payout_accounts (user_id) where is_default;

-- ── Payment preferences ─────────────────────────────────────────────────────

create table if not exists nata.payment_preferences (
  user_id          uuid primary key references auth.users (id) on delete cascade,
  -- When earnings are paid out: as soon as a delivery is confirmed (and the
  -- dispute window has passed), once a week, or only when asked.
  payout_schedule  text not null default 'automatic'
    check (payout_schedule in ('automatic', 'weekly', 'manual')),
  updated_at       timestamptz not null default now()
);

-- ── One default per user, kept automatically ────────────────────────────────
-- A user's first method / account becomes the default; setting a new default
-- clears the old one; deleting the default promotes the most recent one left.

create or replace function nata.keep_single_default()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and not new.is_default then
    execute format(
      'select not exists (select 1 from %I.%I where user_id = $1)',
      tg_table_schema, tg_table_name
    ) into new.is_default using new.user_id;
  end if;

  if new.is_default then
    execute format(
      'update %I.%I set is_default = false
         where user_id = $1 and id <> $2 and is_default',
      tg_table_schema, tg_table_name
    ) using new.user_id, new.id;
  end if;
  return new;
end;
$$;

create or replace function nata.promote_next_default()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.is_default then
    execute format(
      'update %I.%I set is_default = true
         where id = (select id from %I.%I where user_id = $1
                     order by created_at desc limit 1)',
      tg_table_schema, tg_table_name, tg_table_schema, tg_table_name
    ) using old.user_id;
  end if;
  return null;
end;
$$;

drop trigger if exists keep_single_default on nata.payment_methods;
create trigger keep_single_default
  before insert or update of is_default on nata.payment_methods
  for each row execute function nata.keep_single_default();

drop trigger if exists promote_next_default on nata.payment_methods;
create trigger promote_next_default
  after delete on nata.payment_methods
  for each row execute function nata.promote_next_default();

drop trigger if exists keep_single_default on nata.payout_accounts;
create trigger keep_single_default
  before insert or update of is_default on nata.payout_accounts
  for each row execute function nata.keep_single_default();

drop trigger if exists promote_next_default on nata.payout_accounts;
create trigger promote_next_default
  after delete on nata.payout_accounts
  for each row execute function nata.promote_next_default();

create or replace function nata.touch_payment_preferences()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists touch_payment_preferences on nata.payment_preferences;
create trigger touch_payment_preferences
  before update on nata.payment_preferences
  for each row execute function nata.touch_payment_preferences();

-- ── Row level security: users only see and change their own rows ───────────

alter table nata.payment_methods     enable row level security;
alter table nata.payout_accounts     enable row level security;
alter table nata.payment_preferences enable row level security;

drop policy if exists "users manage own payment methods" on nata.payment_methods;
create policy "users manage own payment methods"
  on nata.payment_methods for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "users manage own payout accounts" on nata.payout_accounts;
create policy "users manage own payout accounts"
  on nata.payout_accounts for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "users manage own payment preferences" on nata.payment_preferences;
create policy "users manage own payment preferences"
  on nata.payment_preferences for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on nata.payment_methods, nata.payout_accounts, nata.payment_preferences
  from anon, authenticated;
-- provider_ref is set by the server once payments are connected, never by the
-- app: users may insert, delete and change only which method is the default.
grant select, delete on nata.payment_methods, nata.payout_accounts to authenticated;
grant insert (
  user_id, kind, is_default,
  card_brand, card_last4, card_exp_month, card_exp_year, card_holder_name,
  mobile_provider, mobile_number, mobile_registered_name, wallet_device_label
) on nata.payment_methods to authenticated;
grant update (is_default) on nata.payment_methods to authenticated;
grant insert (
  user_id, kind, is_default, institution_name, country_code, account_last4,
  holder_name
) on nata.payout_accounts to authenticated;
grant update (is_default) on nata.payout_accounts to authenticated;
grant select, insert, update on nata.payment_preferences to authenticated;
