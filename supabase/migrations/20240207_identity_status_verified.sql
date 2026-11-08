-- Identity checks that pass now say so on their own record.
--
-- verify-identity writes status 'verified' when the selfie matches the ID,
-- and the support stats count 'verified', but the table's check only allowed
-- 'pending', 'approved' and 'rejected'. Postgres refused that update, so the
-- record stayed 'pending' with no verified_at or face_similarity, while the
-- profile was still marked verified. This allows 'verified' (in place of the
-- unused 'approved') and fixes the records already affected.

alter table nata.identity_verifications
  drop constraint if exists identity_verifications_status_check;

update nata.identity_verifications
   set status = 'verified'
 where status = 'approved';

alter table nata.identity_verifications
  add constraint identity_verifications_status_check
  check (status in ('pending', 'verified', 'rejected'));

-- Members whose profile is verified but whose record was left pending. The
-- exact moment of the match wasn't saved, so verified_at takes the review
-- time if there is one, otherwise the record's last update (the upload or
-- the last face match attempt, within minutes of it).
update nata.identity_verifications iv
   set status = 'verified',
       verified_at = coalesce(iv.verified_at, iv.reviewed_at, iv.updated_at)
  from nata.profiles p
 where p.id = iv.user_id
   and p.verification_status = 'verified'
   and iv.status = 'pending';
