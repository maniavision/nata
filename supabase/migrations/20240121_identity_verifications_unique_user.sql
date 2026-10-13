-- One identity verification per user.
--
-- The app upserts on user_id (ON CONFLICT (user_id)), which needs a unique
-- constraint. Older rows may hold several verifications per user: keep each
-- user's most recent one and delete the rest before adding the constraint.
--
-- Safe to re-run.

delete from nata.identity_verifications v
using (
  select id,
         row_number() over (
           partition by user_id
           order by created_at desc, id desc
         ) as rn
  from nata.identity_verifications
) ranked
where v.id = ranked.id
  and ranked.rn > 1;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'identity_verifications_user_id_key'
      and conrelid = 'nata.identity_verifications'::regclass
  ) then
    alter table nata.identity_verifications
      add constraint identity_verifications_user_id_key unique (user_id);
  end if;
end $$;
