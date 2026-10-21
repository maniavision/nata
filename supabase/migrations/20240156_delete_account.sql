-- Deleting your account (Profile > Delete account; an App Store requirement).
--
-- Run AFTER 20240155_push_notifications.sql. Safe to re-run.
--
--   * public.account_deletion_blockers(): what stops the signed-in user from
--     deleting their account right now, so the app can show it before asking.
--   * public.delete_my_account(): refuses while money or a delivery is in
--     flight (nata:account_has_escrow, nata:account_has_payments_in_flight,
--     nata:account_has_active_deliveries, nata:account_has_open_disputes;
--     staff get nata:is_staff and are removed by hand). Otherwise it cancels
--     what is still open, deletes the user's personal data and anonymises the
--     profile, which stays behind as a "Deleted user" tombstone.
--   * The delete-account edge function calls delete_my_account() with the
--     user's JWT, then removes their files (identity-documents/<id>/ and
--     user-assets/avatars/<id>/) and the auth user with the service role.
--
-- What is kept, anonymised: payments, refunds, payouts and disputes (Flutterwave
-- reconciliation needs them; they point at the tombstone profile), finished
-- deliveries and trips (the other person's history) and reviews.
--
-- nata.profiles used to be deleted with its auth user by a foreign key, which
-- would also cascade into delivery_requests and fail on their payments. The key
-- is replaced by a trigger that does the same for every profile except
-- tombstones, so other deletes (the seed clean-up) work as before.

alter table nata.profiles
  add column if not exists deleted_at timestamptz;

-- -----------------------------------------------------------------------------
-- 1. Profiles outlive a deleted account
-- -----------------------------------------------------------------------------
do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
     where conrelid = 'nata.profiles'::regclass
       and confrelid = 'auth.users'::regclass
       and contype = 'f'
  loop
    execute format('alter table nata.profiles drop constraint %I', c.conname);
  end loop;
end;
$$;

create or replace function nata.delete_profile_with_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from nata.profiles p where p.id = old.id and p.deleted_at is null;
  return old;
end;
$$;
revoke all on function nata.delete_profile_with_user() from public, anon, authenticated;

drop trigger if exists delete_nata_profile on auth.users;
create trigger delete_nata_profile
  after delete on auth.users
  for each row execute function nata.delete_profile_with_user();

-- -----------------------------------------------------------------------------
-- 2. What stops a deletion
-- -----------------------------------------------------------------------------
create or replace function nata.account_blockers(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select r.id, r.status
      from nata.delivery_requests r
      left join nata.trips t on t.id = r.trip_id
     where r.sender_id = p_user or t.traveler_id = p_user
  )
  select jsonb_build_object(
    -- Money held in escrow: paid by the user, or waiting to be paid to them.
    'escrow', (select count(*)::integer from nata.payments p
                where p.status = 'held'
                  and (p.sender_id = p_user
                       or p.request_id in (select id from mine))),
    -- Payouts to the user and refunds to the user not settled yet.
    'payments', (select count(*)::integer from nata.payouts po
                  where po.traveler_id = p_user
                    and po.status in ('pending', 'processing', 'failed'))
              + (select count(*)::integer from nata.payments p
                  where p.sender_id = p_user
                    and p.refund_status in ('pending', 'processing', 'failed')),
    -- Accepted, paid or picked up, as sender or traveler.
    'deliveries', (select count(*)::integer from mine
                    where status in ('accepted', 'paid', 'handed_off')),
    'disputes', (select count(*)::integer from nata.disputes d
                  where d.status in ('open', 'under_review')
                    and (d.opened_by = p_user
                         or d.request_id in (select id from mine))),
    'staff', nata.is_admin(p_user)
  );
$$;
revoke all on function nata.account_blockers(uuid) from public, anon, authenticated;

create or replace function public.account_deletion_blockers()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  return nata.account_blockers(auth.uid());
end;
$$;
revoke all on function public.account_deletion_blockers() from public, anon;
grant execute on function public.account_deletion_blockers() to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Deleting
-- -----------------------------------------------------------------------------
-- Leaves the auth user and the files to the delete-account edge function.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  b   jsonb;
  sql text;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Nothing can be accepted or paid for this user while we look.
  perform 1 from nata.profiles p where p.id = uid for update;

  b := nata.account_blockers(uid);
  if (b ->> 'staff')::boolean then
    raise exception 'nata:is_staff';
  elsif (b ->> 'escrow')::integer > 0 then
    raise exception 'nata:account_has_escrow';
  elsif (b ->> 'payments')::integer > 0 then
    raise exception 'nata:account_has_payments_in_flight';
  elsif (b ->> 'deliveries')::integer > 0 then
    raise exception 'nata:account_has_active_deliveries';
  elsif (b ->> 'disputes')::integer > 0 then
    raise exception 'nata:account_has_open_disputes';
  end if;

  -- Close what is still open, so the other person sees it end.
  update nata.delivery_requests r
     set status = 'cancelled'
   where r.sender_id = uid and r.status = 'pending';
  update nata.delivery_requests r
     set status = 'declined'
    from nata.trips t
   where t.id = r.trip_id and t.traveler_id = uid and r.status = 'pending';
  update nata.trips t
     set status = 'cancelled'
   where t.traveler_id = uid and t.status in ('pending_review', 'live');
  delete from nata.trips t
   where t.traveler_id = uid
     and not exists (select 1 from nata.delivery_requests r where r.trip_id = t.id);

  -- Personal data.
  delete from nata.messages m where m.author_id = uid;
  delete from nata.request_recipients rr
   where rr.request_id in (select r.id from nata.delivery_requests r
                            where r.sender_id = uid);
  delete from nata.push_tokens where user_id = uid;
  delete from nata.payment_methods where user_id = uid;
  delete from nata.payment_preferences where user_id = uid;
  delete from nata.payer_emails where user_id = uid;
  delete from nata.emergency_contacts where user_id = uid;
  delete from nata.user_settings where user_id = uid;
  delete from nata.identity_verifications where user_id = uid;
  -- Payouts keep their reference and amounts; the account details go.
  update nata.payouts
     set payout_account_id = null, payout_method_id = null
   where traveler_id = uid;
  delete from nata.payout_accounts where user_id = uid;
  delete from nata.payout_methods where user_id = uid;
  delete from nata.device_tokens where user_id = uid;

  -- The profile becomes "Deleted user": every optional text or date column
  -- (phone, bio, birthday...) is cleared, whatever columns it has today.
  select string_agg(format('%I = null', c.column_name), ', ')
    into sql
    from information_schema.columns c
   where c.table_schema = 'nata' and c.table_name = 'profiles'
     and c.is_nullable = 'YES'
     and c.data_type in ('text', 'character varying', 'character', 'date')
     and c.column_name not in ('id', 'first_name');
  if sql is not null then
    execute format('update nata.profiles set %s where id = $1', sql) using uid;
  end if;
  -- Required ones that still hold something personal are emptied.
  select string_agg(format('%I = %L', c.column_name, ''), ', ')
    into sql
    from information_schema.columns c
   where c.table_schema = 'nata' and c.table_name = 'profiles'
     and c.is_nullable = 'NO'
     and c.column_name in ('last_name', 'phone', 'phone_number', 'email', 'bio');
  if sql is not null then
    execute format('update nata.profiles set %s where id = $1', sql) using uid;
  end if;
  update nata.profiles
     set first_name = 'Deleted user',
         verification_status = 'unverified',
         deleted_at = coalesce(deleted_at, now())
   where id = uid;

  -- Last, so nothing above leaves a notification behind.
  delete from nata.notifications where user_id = uid;
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
