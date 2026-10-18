-- Support tools: a Support section in the app for Nata staff.
--
-- Run AFTER 20240153_verified_users_and_trip_limit.sql. Safe to re-run.
--
-- Staff are listed in nata.admins (added by hand, see the end). Every
-- public.support_* function checks the caller is one (nata:not_admin).
-- Staff can:
--   * see reported problems, resolve them with a note, or refund the
--     sender in full while the money is still held;
--   * see failed payouts and refunds and retry them (payouts are sent at
--     once from the database, refunds go out with the next payment job);
--   * see deliveries locked after 5 wrong codes and unlock them.
-- Each action is logged in nata.support_actions (the dashboard's recent
-- activity), and staff can see the delivery photos of any request.

-- -----------------------------------------------------------------------------
-- 1. Who is staff
-- -----------------------------------------------------------------------------
create table if not exists nata.admins (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);
alter table nata.admins enable row level security;
revoke all on nata.admins from anon, authenticated;

create or replace function nata.is_admin(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from nata.admins a where a.user_id = p_user);
$$;
revoke all on function nata.is_admin(uuid) from public, anon, authenticated;

create or replace function nata.require_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not nata.is_admin(auth.uid()) then
    raise exception 'nata:not_admin';
  end if;
  return auth.uid();
end;
$$;
revoke all on function nata.require_admin() from public, anon, authenticated;

-- Whether the signed-in user is staff (Profile shows the Support row).
create or replace function public.am_i_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and nata.is_admin(auth.uid());
$$;
revoke all on function public.am_i_admin() from public, anon;
grant execute on function public.am_i_admin() to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Activity log
-- -----------------------------------------------------------------------------
create table if not exists nata.support_actions (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid not null references auth.users (id),
  action      text not null
                check (action in ('resolved', 'refunded', 'payout_retried',
                                  'refund_retried', 'unlocked')),
  subject     text not null default '',
  request_id  uuid,
  created_at  timestamptz not null default now()
);
alter table nata.support_actions enable row level security;
revoke all on nata.support_actions from anon, authenticated;

create or replace function nata.log_support(
  p_action text, p_subject text, p_request uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into nata.support_actions (admin_id, action, subject, request_id)
  values (auth.uid(), p_action, coalesce(p_subject, ''), p_request);
$$;
revoke all on function nata.log_support(text, text, uuid) from public, anon, authenticated;

-- "Amara K."
create or replace function nata.short_name(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select btrim(coalesce(p.first_name, '') || ' ' ||
               coalesce(left(p.last_name, 1) || '.', ''))
    from nata.profiles p where p.id = p_user;
$$;
revoke all on function nata.short_name(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Dashboard
-- -----------------------------------------------------------------------------
create or replace function public.support_summary()
returns table (open_problems integer, locked_deliveries integer, failed_payments integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query select
    (select count(*)::integer from nata.disputes d
      where d.status in ('open', 'under_review')),
    (select count(*)::integer from nata.delivery_requests r
      where r.status = 'handed_off' and coalesce(r.delivery_code_attempts, 0) >= 5),
    (select count(*)::integer from nata.payouts po where po.status = 'failed')
      + (select count(*)::integer from nata.payments p where p.refund_status = 'failed');
end;
$$;
revoke all on function public.support_summary() from public, anon;
grant execute on function public.support_summary() to authenticated;

create or replace function public.support_recent_activity(p_limit integer default 10)
returns table (action text, subject text, admin_name text, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select a.action, a.subject, nata.short_name(a.admin_id), a.created_at
      from nata.support_actions a
     order by a.created_at desc
     limit least(greatest(coalesce(p_limit, 10), 1), 50);
end;
$$;
revoke all on function public.support_recent_activity(integer) from public, anon;
grant execute on function public.support_recent_activity(integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Reported problems
-- -----------------------------------------------------------------------------
-- [p_open]: open and under review, else resolved and rejected. Newest first.
create or replace function public.support_problems(p_open boolean default true)
returns table (
  dispute_id     uuid,
  request_id     uuid,
  reason         text,
  details        text,
  status         text,
  resolution     text,
  reported_by    text,     -- 'sender' or 'traveler'
  reporter_id    uuid,
  reporter_name  text,
  reporter_avatar text,
  sender_id      uuid,
  sender_name    text,
  sender_phone   text,
  traveler_id    uuid,
  traveler_name  text,
  traveler_phone text,
  route          text,
  item_name      text,
  amount         numeric,
  currency       text,
  payment_status text,
  payout_status  text,
  paid_at        timestamptz,
  picked_up_at   timestamptz,
  delivered_at   timestamptz,
  created_at     timestamptz,
  resolved_at    timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select d.id, r.id, d.reason, d.details, d.status, d.resolution,
           case when d.opened_by = r.sender_id then 'sender' else 'traveler' end,
           d.opened_by, nata.short_name(d.opened_by), rp.avatar_path,
           r.sender_id, nata.short_name(r.sender_id), su.phone::text,
           t.traveler_id, nata.short_name(t.traveler_id), tu.phone::text,
           dc.name || ' → ' || ac.name,
           r.item_name,
           pay.amount, pay.currency::text, pay.status, po.status,
           r.paid_at, r.picked_up_at, r.delivered_at,
           d.created_at, d.resolved_at
      from nata.disputes d
      join nata.delivery_requests r on r.id = d.request_id
      join nata.trips t on t.id = r.trip_id
      join nata.cities dc on dc.id = t.departure_city_id
      join nata.cities ac on ac.id = t.arrival_city_id
      left join nata.profiles rp on rp.id = d.opened_by
      left join auth.users su on su.id = r.sender_id
      left join auth.users tu on tu.id = t.traveler_id
      left join lateral (
        select p.* from nata.payments p
         where p.request_id = r.id and p.status in ('held', 'released', 'refunded')
         order by p.created_at desc limit 1) pay on true
      left join nata.payouts po on po.payment_id = pay.id
     where (p_open and d.status in ('open', 'under_review'))
        or (not p_open and d.status in ('resolved', 'rejected'))
     order by d.created_at desc;
end;
$$;
revoke all on function public.support_problems(boolean) from public, anon;
grant execute on function public.support_problems(boolean) to authenticated;

create or replace function public.support_resolve(p_dispute uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d record;
begin
  perform nata.require_admin();
  update nata.disputes
     set status = 'resolved',
         resolution = nullif(btrim(coalesce(p_note, '')), ''),
         resolved_at = now(),
         updated_at = now()
   where id = p_dispute and status in ('open', 'under_review')
  returning request_id, opened_by into d;
  if not found then
    raise exception 'nata:not_open';
  end if;
  perform nata.log_support('resolved', 'Problem resolved · ' ||
    coalesce(nata.short_name(d.opened_by), ''), d.request_id);
end;
$$;
revoke all on function public.support_resolve(uuid, text) from public, anon;
grant execute on function public.support_resolve(uuid, text) to authenticated;

-- Refunds the sender in full while the money is still held (not yet paid
-- out), and resolves the problem. The refund goes out with the next
-- payment job (within 15 minutes).
create or replace function public.support_refund_sender(p_dispute uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d    record;
  pay  record;
begin
  perform nata.require_admin();
  select dd.request_id, dd.status into d
    from nata.disputes dd where dd.id = p_dispute for update;
  if not found or d.status not in ('open', 'under_review') then
    raise exception 'nata:not_open';
  end if;

  select p.id, p.sender_id into pay
    from nata.payments p
   where p.request_id = d.request_id and p.status = 'held'
     and p.refund_status is null
   order by p.created_at desc limit 1
   for update;
  if not found then
    raise exception 'nata:not_refundable';
  end if;
  if exists (select 1 from nata.payouts po
              where po.payment_id = pay.id and po.status in ('processing', 'paid')) then
    raise exception 'nata:already_paid_out';
  end if;

  -- The traveler isn't paid for this delivery.
  delete from nata.payouts po where po.payment_id = pay.id and po.status in ('pending', 'failed');
  perform nata.queue_refund(pay.id, false);

  update nata.disputes
     set status = 'resolved',
         resolution = nullif(btrim(coalesce(p_note, '')), ''),
         refund_amount = (select p.refund_amount from nata.payments p where p.id = pay.id),
         resolved_at = now(),
         updated_at = now()
   where id = p_dispute;
  perform nata.log_support('refunded', 'Sender refunded · ' ||
    coalesce(nata.short_name(pay.sender_id), ''), d.request_id);
end;
$$;
revoke all on function public.support_refund_sender(uuid, text) from public, anon;
grant execute on function public.support_refund_sender(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Failed payments
-- -----------------------------------------------------------------------------
create or replace function public.support_failed_payments()
returns table (
  kind        text,      -- 'payout' or 'refund'
  id          uuid,      -- payout id or payment id
  request_id  uuid,
  person_name text,
  amount      numeric,
  currency    text,
  reason      text,
  updated_at  timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select 'payout'::text, po.id, p.request_id, nata.short_name(po.traveler_id),
           coalesce(po.payout_amount, po.amount),
           coalesce(po.payout_currency, po.currency)::text,
           coalesce(po.failure_reason, ''), po.updated_at
      from nata.payouts po
      join nata.payments p on p.id = po.payment_id
     where po.status = 'failed'
    union all
    select 'refund'::text, p.id, p.request_id, nata.short_name(p.sender_id),
           p.refund_amount, p.currency::text,
           coalesce(p.refund_failure, ''), p.updated_at
      from nata.payments p
     where p.refund_status = 'failed'
     order by 8 desc;
end;
$$;
revoke all on function public.support_failed_payments() from public, anon;
grant execute on function public.support_failed_payments() to authenticated;

-- Tries a failed payout again now, or puts a failed refund back for the next
-- payment job. Returns the payout's new status ('processing' when
-- Flutterwave took it, 'failed' with a new reason otherwise), or 'pending'
-- for a refund.
create or replace function public.support_retry(p_kind text, p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  traveler uuid;
  req      uuid;
  person   uuid;
  result   text;
begin
  perform nata.require_admin();
  if p_kind = 'payout' then
    update nata.payouts po
       set status = 'pending', failure_reason = null, updated_at = now()
     where po.id = p_id and po.status = 'failed'
    returning po.traveler_id, (select p.request_id from nata.payments p
                                where p.id = po.payment_id)
      into traveler, req;
    if not found then
      raise exception 'nata:not_failed';
    end if;
    perform nata.send_payouts(traveler);
    select po.status into result from nata.payouts po where po.id = p_id;
    perform nata.log_support('payout_retried', 'Payout retried · ' ||
      coalesce(nata.short_name(traveler), ''), req);
    return result;
  elsif p_kind = 'refund' then
    update nata.payments p
       set refund_status = 'pending', refund_failure = null, updated_at = now()
     where p.id = p_id and p.refund_status = 'failed'
    returning p.sender_id, p.request_id into person, req;
    if not found then
      raise exception 'nata:not_failed';
    end if;
    perform nata.log_support('refund_retried', 'Refund retried · ' ||
      coalesce(nata.short_name(person), ''), req);
    return 'pending';
  end if;
  raise exception 'nata:bad_kind';
end;
$$;
revoke all on function public.support_retry(text, uuid) from public, anon;
grant execute on function public.support_retry(text, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Locked deliveries
-- -----------------------------------------------------------------------------
create or replace function public.support_locked_deliveries()
returns table (
  request_id    uuid,
  traveler_name text,
  sender_name   text,
  route         text,
  item_name     text,
  attempts      integer,
  picked_up_at  timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select r.id, nata.short_name(t.traveler_id), nata.short_name(r.sender_id),
           dc.name || ' → ' || ac.name, r.item_name,
           coalesce(r.delivery_code_attempts, 0), r.picked_up_at
      from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
      join nata.cities dc on dc.id = t.departure_city_id
      join nata.cities ac on ac.id = t.arrival_city_id
     where r.status = 'handed_off' and coalesce(r.delivery_code_attempts, 0) >= 5
     order by r.updated_at desc;
end;
$$;
revoke all on function public.support_locked_deliveries() from public, anon;
grant execute on function public.support_locked_deliveries() to authenticated;

create or replace function public.support_unlock(p_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  traveler uuid;
begin
  perform nata.require_admin();
  update nata.delivery_requests r
     set delivery_code_attempts = 0, updated_at = now()
   where r.id = p_request and r.status = 'handed_off'
     and coalesce(r.delivery_code_attempts, 0) >= 5
  returning (select t.traveler_id from nata.trips t where t.id = r.trip_id)
    into traveler;
  if not found then
    raise exception 'nata:not_locked';
  end if;
  perform nata.notify(traveler, 'request', 'delivery_unlocked',
    'Delivery unlocked',
    'Support unlocked the delivery code. You have 5 more tries.',
    p_request, '{}'::jsonb);
  perform nata.log_support('unlocked', 'Delivery unlocked · ' ||
    coalesce(nata.short_name(traveler), ''), p_request);
end;
$$;
revoke all on function public.support_unlock(uuid) from public, anon;
grant execute on function public.support_unlock(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 7. Staff see delivery photos
-- -----------------------------------------------------------------------------
drop policy if exists "Staff see delivery photos" on storage.objects;
create policy "Staff see delivery photos"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'handover-photos' and nata.is_admin(auth.uid()));
grant execute on function nata.is_admin(uuid) to authenticated;

create or replace function public.support_delivery_photos(p_request uuid)
returns table (pickup_photo_path text, handover_photo_path text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select r.pickup_photo_path, r.handover_photo_path
      from nata.delivery_requests r where r.id = p_request;
end;
$$;
revoke all on function public.support_delivery_photos(uuid) from public, anon;
grant execute on function public.support_delivery_photos(uuid) to authenticated;

-- Adding a staff member (run by hand, with their user id):
--   insert into nata.admins (user_id) values ('<auth user id>');
