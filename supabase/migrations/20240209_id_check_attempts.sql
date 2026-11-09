-- =============================================================================
-- ID photos that keep failing the app's check go to Nata's team.
-- Run AFTER 20240207_identity_status_verified.sql. Safe to re-run.
--
-- The app checks an ID photo on the phone before sending it (is it an ID,
-- the right type, the member's name, a face). Until now a member whose photo
-- kept failing was stuck. Now:
--   1. Each failed check is counted on the server
--      (public.record_id_check_failure), so reinstalling the app doesn't
--      reset it. After 2 the app shows tips; after 4 it also suggests
--      asking someone with a better camera.
--   2. On the 5th failure the app sends the ID anyway and calls
--      public.send_id_for_review: the record is flagged needs_review, with
--      the check that failed. The face match is held until staff look.
--   3. Staff see these IDs in Support (public.support_id_reviews, and the ID
--      image itself) and approve or reject them (public.support_review_id).
--      Approving notifies the member (id_approved), who then finishes with
--      the face scan. Rejecting marks the ID rejected (the member is told,
--      by the existing identity_rejected notification) and resets the count,
--      so they can try again.
--
-- Members can't set needs_review, review_reason or id_approved_at
-- themselves: the existing guard on identity_verifications now keeps them.
-- Staff actions get past the guards with a transaction-local setting
-- (nata.staff_review) that only counts for admins.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Columns and the failure count
-- -----------------------------------------------------------------------------
alter table nata.identity_verifications
  add column if not exists needs_review   boolean not null default false,
  add column if not exists review_reason  text,
  add column if not exists id_approved_at timestamptz;

create table if not exists nata.id_check_failures (
  user_id    uuid primary key references nata.profiles(id) on delete cascade,
  failures   integer not null default 0 check (failures >= 0),
  updated_at timestamptz not null default now()
);
alter table nata.id_check_failures enable row level security;
-- No policies: read and written only through the functions below.

-- How many ID photos must fail before the ID goes to the team.
create or replace function nata.id_review_after()
returns integer
language sql
immutable
set search_path = ''
as $$ select 5; $$;

-- True inside a staff action (see support_review_id).
create or replace function nata.staff_review_on()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(current_setting('nata.staff_review', true), '') = 'on'
     and nata.is_admin(auth.uid());
$$;
revoke all on function nata.staff_review_on() from public, anon;
grant execute on function nata.staff_review_on() to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Guards: members can't touch the review fields
-- -----------------------------------------------------------------------------
create or replace function nata.protect_identity_review()
returns trigger
language plpgsql
as $$
begin
  if coalesce(auth.role(), '') not in ('authenticated', 'anon')
     or nata.staff_review_on() then
    return new;
  end if;

  if new.status is distinct from 'pending' then
    raise exception 'identity_verifications.status can only be set to pending'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    new.face_similarity := null;
    new.face_match_attempts := 0;
    new.verified_at := null;
    new.needs_review := false;
    new.review_reason := null;
    new.id_approved_at := null;
  else
    new.face_similarity := old.face_similarity;
    new.face_match_attempts := old.face_match_attempts;
    new.verified_at := old.verified_at;
    new.needs_review := old.needs_review;
    new.review_reason := old.review_reason;
    new.id_approved_at := old.id_approved_at;
  end if;
  return new;
end;
$$;

-- Same as 20240178, but a staff action isn't a member's own write.
create or replace function nata.profiles_verified_needs_contact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- A member's own write; not one made by another trigger in their request
  -- (saving the contact, section 2), nor a staff action.
  if coalesce(auth.role(), '') in ('authenticated', 'anon')
     and pg_trigger_depth() = 1
     and not nata.staff_review_on() then
    -- Members don't mark themselves verified, or wait for a contact.
    if tg_op = 'INSERT' then
      new.verification_status := 'unverified';
      new.awaiting_emergency_contact := false;
      return new;
    end if;
    new.awaiting_emergency_contact := old.awaiting_emergency_contact;
    if new.verification_status is distinct from old.verification_status then
      if new.verification_status <> 'pending'
         or old.verification_status in ('verified', 'pending') then
        new.verification_status := old.verification_status;
      else
        -- A new ID submitted: its review starts over.
        new.awaiting_emergency_contact := false;
      end if;
    end if;
    return new;
  end if;

  if new.verification_status = 'verified'
     and not exists (select 1 from nata.emergency_contacts c
                      where c.user_id = new.id) then
    new.verification_status := 'pending';
    new.awaiting_emergency_contact := true;
  elsif new.verification_status is distinct from 'pending' then
    new.awaiting_emergency_contact := false;
  end if;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. The member's side
-- -----------------------------------------------------------------------------

-- One more failed ID check; returns the new count.
create or replace function public.record_id_check_failure()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  n  integer;
begin
  if me is null then
    raise exception 'nata:not_signed_in';
  end if;
  insert into nata.id_check_failures as f (user_id, failures, updated_at)
  values (me, 1, now())
  on conflict (user_id) do update
    set failures = f.failures + 1, updated_at = now()
  returning f.failures into n;
  return n;
end;
$$;
revoke all on function public.record_id_check_failure() from public, anon;
grant execute on function public.record_id_check_failure() to authenticated;

-- The member's ID, already sent, goes to the team: only after enough failed
-- checks. p_reason is the check that failed (not_an_id, wrong_type,
-- name_mismatch, no_face, unreadable).
create or replace function public.send_id_for_review(p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me      uuid := auth.uid();
  changed integer;
begin
  if me is null then
    raise exception 'nata:not_signed_in';
  end if;
  if coalesce((select f.failures from nata.id_check_failures f
                where f.user_id = me), 0) < nata.id_review_after() then
    raise exception 'nata:too_soon';
  end if;
  perform set_config('nata.staff_review', 'on', true);
  update nata.identity_verifications v
     set needs_review = true,
         review_reason = left(nullif(btrim(coalesce(p_reason, '')), ''), 40),
         id_approved_at = null
   where v.user_id = me and v.status = 'pending';
  get diagnostics changed = row_count;
  perform set_config('nata.staff_review', '', true);
  if changed = 0 then
    raise exception 'nata:no_verification';
  end if;
end;
$$;
revoke all on function public.send_id_for_review(text) from public, anon;
grant execute on function public.send_id_for_review(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Staff
-- -----------------------------------------------------------------------------
drop policy if exists "Staff see ID documents" on storage.objects;
create policy "Staff see ID documents"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'identity-documents' and nata.is_admin(auth.uid()));

-- IDs waiting for the team, oldest first.
create or replace function public.support_id_reviews()
returns table (
  user_id          uuid,
  first_name       text,
  last_name        text,
  id_document_type text,
  id_document_path text,
  review_reason    text,
  failures         integer,
  submitted_at     timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select v.user_id, p.first_name, p.last_name, v.id_document_type,
           v.id_document_path, v.review_reason,
           coalesce(f.failures, 0), v.updated_at
      from nata.identity_verifications v
      join nata.profiles p on p.id = v.user_id
      left join nata.id_check_failures f on f.user_id = v.user_id
     where v.needs_review and v.status = 'pending'
     order by v.updated_at;
end;
$$;
revoke all on function public.support_id_reviews() from public, anon;
grant execute on function public.support_id_reviews() to authenticated;

-- Approve: the member goes on to the face scan. Reject: the ID is refused,
-- with p_note as the reason, and the member can send a new one.
create or replace function public.support_review_id(
  p_user uuid, p_approve boolean, p_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  admin   uuid := nata.require_admin();
  note    text := nullif(btrim(coalesce(p_note, '')), '');
  changed integer;
begin
  if not p_approve and note is null then
    raise exception 'nata:note_required';
  end if;
  perform set_config('nata.staff_review', 'on', true);
  if p_approve then
    update nata.identity_verifications v
       set needs_review = false,
           id_approved_at = now(),
           reviewed_at = now()
     where v.user_id = p_user and v.needs_review and v.status = 'pending';
  else
    update nata.identity_verifications v
       set needs_review = false,
           status = 'rejected',
           rejection_reason = note,
           reviewed_at = now()
     where v.user_id = p_user and v.needs_review and v.status = 'pending';
  end if;
  get diagnostics changed = row_count;
  if changed = 0 then
    perform set_config('nata.staff_review', '', true);
    raise exception 'nata:not_waiting';
  end if;

  if p_approve then
    perform nata.notify(p_user, 'verification', 'id_approved',
      'ID approved',
      'Your ID was approved. Finish with a quick face scan to get verified.',
      null, '{}'::jsonb);
    perform nata.log_support('id_approved', 'ID approved · ' ||
      coalesce(nata.short_name(p_user), ''), null);
  else
    -- The existing notification (identity_rejected) goes out from here.
    update nata.profiles p set verification_status = 'rejected'
     where p.id = p_user;
    delete from nata.id_check_failures f where f.user_id = p_user;
    perform nata.log_support('id_rejected', 'ID rejected · ' ||
      coalesce(nata.short_name(p_user), ''), null);
  end if;
  perform set_config('nata.staff_review', '', true);
end;
$$;
revoke all on function public.support_review_id(uuid, boolean, text) from public, anon;
grant execute on function public.support_review_id(uuid, boolean, text) to authenticated;

-- The dashboard also counts IDs waiting for the team.
drop function if exists public.support_summary();
create or replace function public.support_summary()
returns table (
  open_problems     integer,
  locked_deliveries integer,
  failed_payments   integer,
  open_reports      integer,
  id_reviews        integer
)
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
      + (select count(*)::integer from nata.payments p where p.refund_status = 'failed'),
    (select count(*)::integer from nata.chat_reports cr where cr.status = 'open'),
    (select count(*)::integer from nata.identity_verifications v
      where v.needs_review and v.status = 'pending');
end;
$$;
revoke all on function public.support_summary() from public, anon;
grant execute on function public.support_summary() to authenticated;
