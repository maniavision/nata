-- Face match for identity verification.
--
-- After the ID upload the app runs a liveness check, uploads a selfie and
-- calls the `verify-identity` edge function, which compares the selfie with
-- the ID photo (AWS Rekognition). These columns record the outcome; only the
-- edge function (service role) may write them.
--
-- Images live in the private `identity-documents` bucket, in the user's
-- folder: {user_id}/id_face.jpg (the ID page showing the face) and
-- {user_id}/selfie.jpg. The existing storage policies already limit users to
-- their own folder.
--
-- Safe to re-run.

alter table nata.identity_verifications
  add column if not exists face_similarity     numeric(5, 2)
    check (face_similarity between 0 and 100),
  add column if not exists face_match_attempts integer not null default 0
    check (face_match_attempts >= 0),
  add column if not exists verified_at         timestamptz;

-- Users can insert and update their own row (to submit an ID), but the
-- review outcome is the server's: through the API a user may only ever set
-- status 'pending', and can't touch the face match columns (so they can't
-- mark themselves verified or reset their attempts). The service role and
-- the SQL editor (no JWT) are not restricted.
create or replace function nata.protect_identity_review()
returns trigger
language plpgsql
as $$
begin
  if coalesce(auth.role(), '') not in ('authenticated', 'anon') then
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
  else
    new.face_similarity := old.face_similarity;
    new.face_match_attempts := old.face_match_attempts;
    new.verified_at := old.verified_at;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_identity_review on nata.identity_verifications;
create trigger protect_identity_review
  before insert or update on nata.identity_verifications
  for each row execute function nata.protect_identity_review();
