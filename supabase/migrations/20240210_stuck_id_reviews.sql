-- Support > ID reviews also lists ID checks that are stuck.
--
-- Until now it only listed IDs whose photo failed the app's check 5 times.
-- An ID that passed that check could still stay "pending" forever with
-- nobody told: the app skips the face scan when it can't make the face
-- image from the ID, a member can leave during the face scan, and a face
-- match can fail (3 tries, or AWS refusing it). Those now show to the team
-- too, once the member has uploaded nothing for 30 minutes (so nobody is
-- listed while still going through the steps).
--
-- Approving one with a selfie verifies the member: staff compare the ID and
-- the selfie themselves. Without a selfie, approving sends the member on to
-- the face scan, as before. Rejecting is unchanged.

-- The activity log refused the ID review actions (20240209 logs
-- 'id_approved' and 'id_rejected' but never allowed them), so approving or
-- rejecting an ID failed and rolled back. Allow them, and 'id_verified'.
alter table nata.support_actions
  drop constraint if exists support_actions_action_check;
alter table nata.support_actions
  add constraint support_actions_action_check
  check (action in ('resolved', 'refunded', 'payout_retried',
                    'refund_retried', 'unlocked', 'report_reviewed',
                    'id_approved', 'id_rejected', 'id_verified'));

-- How long a pending check waits, with no new upload, before it's listed.
create or replace function nata.id_stuck_after()
returns interval
language sql
immutable
as $$ select interval '30 minutes' $$;

-- The member's selfie (from the face scan), if one was uploaded.
create or replace function nata.selfie_uploaded_at(p_user uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(coalesce(o.updated_at, o.created_at))
    from storage.objects o
   where o.bucket_id = 'identity-documents'
     and o.name = p_user::text || '/selfie.jpg';
$$;
revoke all on function nata.selfie_uploaded_at(uuid) from public, anon, authenticated;

-- The member's latest upload of any kind (ID, ID face, selfie).
create or replace function nata.id_last_upload_at(p_user uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(coalesce(o.updated_at, o.created_at))
    from storage.objects o
   where o.bucket_id = 'identity-documents'
     and o.name like p_user::text || '/%';
$$;
revoke all on function nata.id_last_upload_at(uuid) from public, anon, authenticated;

-- Whether this pending check waits for the team:
--  * its photo failed the app's check 5 times (needs_review), or
--  * nothing was uploaded for 30 minutes and no face match verified it,
--    unless the team already approved the ID and the member hasn't done
--    the face scan since (then it's the member's turn).
create or replace function nata.id_waits_for_team(
  v nata.identity_verifications
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select v.status = 'pending' and (
    v.needs_review
    or (
      greatest(v.updated_at, nata.id_last_upload_at(v.user_id))
        < now() - nata.id_stuck_after()
      and (
        v.id_approved_at is null
        or nata.selfie_uploaded_at(v.user_id) > v.id_approved_at
      )
    )
  );
$$;
revoke all on function nata.id_waits_for_team(nata.identity_verifications)
  from public, anon, authenticated;

-- IDs waiting for the team, oldest first. review_reason says why:
-- the failed photo check, or 'face_scan_not_done' (no selfie),
-- 'face_match_failed' (a selfie and failed matches) or 'face_match_not_run'
-- (a selfie, but no match was ever tried).
drop function if exists public.support_id_reviews();
create function public.support_id_reviews()
returns table (
  user_id             uuid,
  first_name          text,
  last_name           text,
  id_document_type    text,
  id_document_path    text,
  review_reason       text,
  failures            integer,
  submitted_at        timestamptz,
  selfie_path         text,
  face_match_attempts integer
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
           v.id_document_path,
           case
             when v.needs_review then v.review_reason
             when s.at is null then 'face_scan_not_done'
             when coalesce(v.face_match_attempts, 0) > 0 then 'face_match_failed'
             else 'face_match_not_run'
           end,
           coalesce(f.failures, 0),
           greatest(v.updated_at, nata.id_last_upload_at(v.user_id)),
           case when s.at is not null then v.user_id::text || '/selfie.jpg' end,
           coalesce(v.face_match_attempts, 0)
      from nata.identity_verifications v
      join nata.profiles p on p.id = v.user_id
      left join nata.id_check_failures f on f.user_id = v.user_id
      cross join lateral (select nata.selfie_uploaded_at(v.user_id) as at) s
     where nata.id_waits_for_team(v)
     order by 8;
end;
$$;
revoke all on function public.support_id_reviews() from public, anon;
grant execute on function public.support_id_reviews() to authenticated;

-- Approve: with a selfie, the member is verified (staff compared the two);
-- without one, the member goes on to the face scan. Reject: the ID is
-- refused, with p_note as the reason, and the member can send a new one.
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
  waiting boolean;
  selfie  boolean;
begin
  if not p_approve and note is null then
    raise exception 'nata:note_required';
  end if;

  select nata.id_waits_for_team(v) into waiting
    from nata.identity_verifications v
   where v.user_id = p_user
   for update;
  if not coalesce(waiting, false) then
    raise exception 'nata:not_waiting';
  end if;
  selfie := nata.selfie_uploaded_at(p_user) is not null;

  perform set_config('nata.staff_review', 'on', true);
  if p_approve and selfie then
    update nata.identity_verifications v
       set needs_review = false,
           status = 'verified',
           verified_at = now(),
           id_approved_at = coalesce(v.id_approved_at, now()),
           reviewed_at = now()
     where v.user_id = p_user;
    -- The profile's own trigger sends "identity verified" (or waits for an
    -- emergency contact first).
    update nata.profiles p set verification_status = 'verified'
     where p.id = p_user;
    delete from nata.id_check_failures f where f.user_id = p_user;
    perform nata.log_support('id_verified', 'ID verified · ' ||
      coalesce(nata.short_name(p_user), ''), null);
  elsif p_approve then
    update nata.identity_verifications v
       set needs_review = false,
           id_approved_at = now(),
           reviewed_at = now()
     where v.user_id = p_user;
    perform nata.notify(p_user, 'verification', 'id_approved',
      'ID approved',
      'Your ID was approved. Finish with a quick face scan to get verified.',
      null, '{}'::jsonb);
    perform nata.log_support('id_approved', 'ID approved · ' ||
      coalesce(nata.short_name(p_user), ''), null);
  else
    update nata.identity_verifications v
       set needs_review = false,
           status = 'rejected',
           rejection_reason = note,
           reviewed_at = now()
     where v.user_id = p_user;
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

-- The dashboard counts the stuck checks too.
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
      where nata.id_waits_for_team(v));
end;
$$;
revoke all on function public.support_summary() from public, anon;
grant execute on function public.support_summary() to authenticated;
