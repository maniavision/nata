-- Suggestions to improve the app.
--
-- Run AFTER 20240188_blur_traveler_photos.sql. Safe to re-run.
--
-- After a sender reviews a traveler, or a traveler reviews a sender, the app
-- asks (optionally) how Nata could be better. The answer goes only to the
-- Nata team:
--
--   * nata.app_feedback: who sent it, from where ('review_traveler' when a
--     sender reviewed a traveler, 'review_sender' the other way), the
--     request it followed, and the text (1 to 2000 characters).
--   * public.send_app_feedback(p_message, p_source, p_request_id): the
--     signed-in member adds one. Members can't read any back.
--   * public.support_app_feedback(p_limit): the newest, for admins.

create table if not exists nata.app_feedback (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  source      text not null
              check (source in ('review_traveler', 'review_sender')),
  request_id  uuid references nata.delivery_requests (id) on delete set null,
  message     text not null
              check (char_length(btrim(message)) between 1 and 2000),
  created_at  timestamptz not null default now()
);

create index if not exists app_feedback_created_idx
  on nata.app_feedback (created_at desc);

alter table nata.app_feedback enable row level security;
revoke all on nata.app_feedback from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. Sending one
-- -----------------------------------------------------------------------------
create or replace function public.send_app_feedback(
  p_message    text,
  p_source     text,
  p_request_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  msg text := btrim(coalesce(p_message, ''));
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if char_length(msg) not between 1 and 2000
     or p_source not in ('review_traveler', 'review_sender') then
    raise exception 'nata:feedback_invalid';
  end if;
  -- A few a day at most.
  if (select count(*) from nata.app_feedback f
       where f.user_id = uid
         and f.created_at > now() - interval '1 day') >= 10 then
    raise exception 'nata:too_many';
  end if;

  insert into nata.app_feedback (user_id, source, request_id, message)
  values (
    uid,
    p_source,
    -- Only a request the member took part in.
    (select r.id
       from nata.delivery_requests r
       join nata.trips t on t.id = r.trip_id
      where r.id = p_request_id
        and uid in (r.sender_id, t.traveler_id)),
    msg
  );
end;
$$;

revoke all on function public.send_app_feedback(text, text, uuid)
  from public, anon;
grant execute on function public.send_app_feedback(text, text, uuid)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Reading them (support)
-- -----------------------------------------------------------------------------
create or replace function public.support_app_feedback(p_limit int default 100)
returns table (
  id         uuid,
  user_id    uuid,
  first_name text,
  last_name  text,
  source     text,
  request_id uuid,
  message    text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select f.id, f.user_id, p.first_name, p.last_name, f.source,
           f.request_id, f.message, f.created_at
      from nata.app_feedback f
      left join nata.profiles p on p.id = f.user_id
     order by f.created_at desc
     limit least(greatest(coalesce(p_limit, 100), 1), 500);
end;
$$;

revoke all on function public.support_app_feedback(int) from public, anon;
grant execute on function public.support_app_feedback(int) to authenticated;
