-- An email for paying, for accounts made with a phone number.
--
-- Run AFTER 20240147_payment_jobs.sql. Safe to re-run.
--
-- Flutterwave needs the payer's email, and accounts made with a phone number
-- have none. Checkout asks those senders for one; create-payment keeps it in
-- nata.payer_emails, so they are asked only once. It is never shown to
-- anyone else: only the owner reads it (public.my_payer_email) and only
-- create-payment writes it.

create table if not exists nata.payer_emails (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  email      text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  updated_at timestamptz not null default now()
);

alter table nata.payer_emails enable row level security;
-- No policies: read through public.my_payer_email, written by create-payment.
revoke all on nata.payer_emails from anon, authenticated;

-- The email the signed-in user pays with: their account's, else the one they
-- gave at checkout, else null (checkout then asks for it).
create or replace function public.my_payer_email()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    nullif(trim(u.email), ''),
    (select p.email from nata.payer_emails p where p.user_id = u.id)
  )
    from auth.users u
   where u.id = auth.uid();
$$;

revoke all on function public.my_payer_email() from public, anon;
grant execute on function public.my_payer_email() to authenticated;
