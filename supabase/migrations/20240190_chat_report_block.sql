-- Reporting and blocking in chat (App Store guideline 1.2).
--
-- Run AFTER 20240189_app_feedback.sql. Safe to re-run.
--
-- In a chat a member can report the other person (or one of their
-- messages) to Nata's team, and block them:
--
--   * nata.user_blocks: who blocked whom. While either of two members has
--     blocked the other, neither can write to (or send photos in) a chat
--     they share: nata.chat_unlocked() is now also false then. The messages
--     already sent stay readable. Blocking doesn't cancel a delivery.
--   * public.block_user(p_user) / public.unblock_user(p_user): only someone
--     the member shares a chat with can be blocked.
--   * public.chat_block_state(p_conversation): whether the signed-in member
--     blocked the other person, and whether they were blocked.
--   * nata.chat_reports: a report about the other person in a chat, with a
--     reason, an optional note and the message it is about. The reported
--     member isn't told.
--   * public.report_chat(...): adds one (and blocks too, if asked). Nata's
--     staff are notified.
--   * Support: public.support_chat_reports(p_open), the conversation's
--     messages (public.support_report_messages) and
--     public.support_review_report() to close one with a note (logged as
--     'report_reviewed'); support_summary() also counts open reports.

-- -----------------------------------------------------------------------------
-- 1. Blocks
-- -----------------------------------------------------------------------------
create table if not exists nata.user_blocks (
  blocker_id  uuid not null references auth.users (id) on delete cascade,
  blocked_id  uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists user_blocks_blocked_idx
  on nata.user_blocks (blocked_id);

alter table nata.user_blocks enable row level security;
revoke all on nata.user_blocks from public, anon, authenticated;

-- Whether either of [a] and [b] has blocked the other.
create or replace function nata.blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from nata.user_blocks k
     where (k.blocker_id = a and k.blocked_id = b)
        or (k.blocker_id = b and k.blocked_id = a));
$$;
revoke all on function nata.blocked_between(uuid, uuid)
  from public, anon, authenticated;

-- The two members of a conversation: the request's sender and the trip's
-- traveler.
create or replace function nata.conversation_members(p_conversation uuid)
returns table (sender_id uuid, traveler_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select r.sender_id, t.traveler_id
    from nata.conversations c
    join nata.delivery_requests r on r.id = c.request_id
    join nata.trips t on t.id = r.trip_id
   where c.id = p_conversation;
$$;
revoke all on function nata.conversation_members(uuid)
  from public, anon, authenticated;

-- The other member of [p_conversation] for [p_me]; null if [p_me] isn't in it.
create or replace function nata.conversation_other(p_conversation uuid, p_me uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case when m.sender_id = p_me then m.traveler_id
              when m.traveler_id = p_me then m.sender_id end
    from nata.conversation_members(p_conversation) m;
$$;
revoke all on function nata.conversation_other(uuid, uuid)
  from public, anon, authenticated;

-- Writing needs an open chat (20240164) and no block between the two.
create or replace function nata.chat_unlocked(p_conversation text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cid uuid;
begin
  begin
    cid := p_conversation::uuid;
  exception when others then
    return false;
  end;

  return exists (
    select 1
      from nata.conversations c
      join nata.delivery_requests r on r.id = c.request_id
      join nata.trips t on t.id = r.trip_id
     where c.id = cid
       and r.status in ('paid', 'handed_off')
       and not nata.blocked_between(r.sender_id, t.traveler_id)
  );
end;
$$;

revoke all on function nata.chat_unlocked(text) from public;
grant execute on function nata.chat_unlocked(text) to authenticated;

create or replace function public.block_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  -- Only someone the member shares a chat with.
  if p_user is null or p_user = uid or not exists (
       select 1
         from nata.conversations c
         join nata.delivery_requests r on r.id = c.request_id
         join nata.trips t on t.id = r.trip_id
        where (r.sender_id = uid and t.traveler_id = p_user)
           or (t.traveler_id = uid and r.sender_id = p_user)) then
    raise exception 'nata:cannot_block';
  end if;
  insert into nata.user_blocks (blocker_id, blocked_id)
  values (uid, p_user)
  on conflict do nothing;
end;
$$;
revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

create or replace function public.unblock_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'nata:not_signed_in';
  end if;
  delete from nata.user_blocks
   where blocker_id = auth.uid() and blocked_id = p_user;
end;
$$;
revoke all on function public.unblock_user(uuid) from public, anon;
grant execute on function public.unblock_user(uuid) to authenticated;

create or replace function public.chat_block_state(p_conversation uuid)
returns table (i_blocked boolean, blocked_me boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid   uuid := auth.uid();
  other uuid;
begin
  other := nata.conversation_other(p_conversation, uid);
  if uid is null or other is null then
    return query select false, false;
    return;
  end if;
  return query select
    exists (select 1 from nata.user_blocks k
             where k.blocker_id = uid and k.blocked_id = other),
    exists (select 1 from nata.user_blocks k
             where k.blocker_id = other and k.blocked_id = uid);
end;
$$;
revoke all on function public.chat_block_state(uuid) from public, anon;
grant execute on function public.chat_block_state(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Reports
-- -----------------------------------------------------------------------------
create table if not exists nata.chat_reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid references auth.users (id) on delete set null,
  reported_id      uuid references auth.users (id) on delete set null,
  conversation_id  uuid references nata.conversations (id) on delete set null,
  message_id       uuid references nata.messages (id) on delete set null,
  reason           text not null
                   check (reason in ('harassment', 'scam', 'spam',
                                     'inappropriate', 'unsafe', 'other')),
  note             text check (note is null or char_length(note) <= 1000),
  -- What the message said when it was reported.
  message_body     text,
  status           text not null default 'open'
                   check (status in ('open', 'reviewed')),
  review_note      text,
  reviewed_by      uuid references auth.users (id) on delete set null,
  reviewed_at      timestamptz,
  created_at       timestamptz not null default now()
);
create index if not exists chat_reports_open_idx
  on nata.chat_reports (status, created_at desc);

alter table nata.chat_reports enable row level security;
revoke all on nata.chat_reports from public, anon, authenticated;

create or replace function public.report_chat(
  p_conversation uuid,
  p_reason       text,
  p_note         text default null,
  p_message      uuid default null,
  p_block        boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid   uuid := auth.uid();
  other uuid;
  note  text := nullif(btrim(coalesce(p_note, '')), '');
  body  text;
  msg   uuid;
  a     record;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  other := nata.conversation_other(p_conversation, uid);
  if other is null then
    raise exception 'nata:not_member';
  end if;
  if p_reason not in ('harassment', 'scam', 'spam', 'inappropriate',
                      'unsafe', 'other')
     or char_length(coalesce(note, '')) > 1000 then
    raise exception 'nata:report_invalid';
  end if;
  if (select count(*) from nata.chat_reports r
       where r.reporter_id = uid
         and r.created_at > now() - interval '1 day') >= 20 then
    raise exception 'nata:too_many';
  end if;

  -- Only a message the other person wrote in this chat.
  select m.id, coalesce(m.body, case when m.attachment_path is not null
                                     then '[photo]' end)
    into msg, body
    from nata.messages m
   where m.id = p_message
     and m.conversation_id = p_conversation
     and m.author_id = other;

  insert into nata.chat_reports
    (reporter_id, reported_id, conversation_id, message_id, reason, note,
     message_body)
  values (uid, other, p_conversation, msg, p_reason, note, body);

  if coalesce(p_block, false) then
    insert into nata.user_blocks (blocker_id, blocked_id)
    values (uid, other)
    on conflict do nothing;
  end if;

  -- Tell Nata's staff.
  for a in select ad.user_id from nata.admins ad loop
    perform nata.notify(
      a.user_id, 'system', 'chat_reported',
      'New chat report',
      coalesce(nata.short_name(other), 'A member') || ' was reported: '
        || p_reason,
      p_conversation,
      jsonb_build_object('conversation_id', p_conversation));
  end loop;
end;
$$;
revoke all on function public.report_chat(uuid, text, text, uuid, boolean)
  from public, anon;
grant execute on function public.report_chat(uuid, text, text, uuid, boolean)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Support
-- -----------------------------------------------------------------------------
alter table nata.support_actions
  drop constraint if exists support_actions_action_check;
alter table nata.support_actions
  add constraint support_actions_action_check
  check (action in ('resolved', 'refunded', 'payout_retried',
                    'refund_retried', 'unlocked', 'report_reviewed'));

create or replace function public.support_chat_reports(p_open boolean default true)
returns table (
  id              uuid,
  reason          text,
  note            text,
  message_body    text,
  status          text,
  review_note     text,
  created_at      timestamptz,
  reviewed_at     timestamptz,
  conversation_id uuid,
  request_id      uuid,
  reporter_id     uuid,
  reporter_name   text,
  reporter_avatar text,
  reported_id     uuid,
  reported_name   text,
  reported_avatar text,
  reported_count  integer,
  blocked         boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select r.id, r.reason, r.note, r.message_body, r.status, r.review_note,
           r.created_at, r.reviewed_at, r.conversation_id, c.request_id,
           r.reporter_id,
           btrim(coalesce(rp.first_name, '') || ' ' || coalesce(rp.last_name, '')),
           rp.avatar_path,
           r.reported_id,
           btrim(coalesce(dp.first_name, '') || ' ' || coalesce(dp.last_name, '')),
           dp.avatar_path,
           (select count(*)::integer from nata.chat_reports x
             where x.reported_id = r.reported_id),
           exists (select 1 from nata.user_blocks k
                    where k.blocker_id = r.reporter_id
                      and k.blocked_id = r.reported_id)
      from nata.chat_reports r
      left join nata.conversations c on c.id = r.conversation_id
      left join nata.profiles rp on rp.id = r.reporter_id
      left join nata.profiles dp on dp.id = r.reported_id
     where (r.status = 'open') = coalesce(p_open, true)
     order by r.created_at desc
     limit 200;
end;
$$;
revoke all on function public.support_chat_reports(boolean) from public, anon;
grant execute on function public.support_chat_reports(boolean) to authenticated;

-- The reported conversation's latest messages, oldest first.
create or replace function public.support_report_messages(p_report uuid)
returns table (
  id          uuid,
  author_id   uuid,
  body        text,
  has_photo   boolean,
  created_at  timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform nata.require_admin();
  return query
    select x.id, x.author_id, x.body, x.has_photo, x.created_at
      from (
        select m.id, m.author_id, m.body,
               m.attachment_path is not null as has_photo, m.created_at
          from nata.messages m
          join nata.chat_reports r on r.conversation_id = m.conversation_id
         where r.id = p_report
         order by m.created_at desc
         limit 100
      ) x
     order by x.created_at;
end;
$$;
revoke all on function public.support_report_messages(uuid) from public, anon;
grant execute on function public.support_report_messages(uuid) to authenticated;

create or replace function public.support_review_report(p_report uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  admin   uuid := nata.require_admin();
  who     uuid;
  req     uuid;
begin
  update nata.chat_reports r
     set status = 'reviewed',
         review_note = nullif(btrim(coalesce(p_note, '')), ''),
         reviewed_by = admin,
         reviewed_at = now()
   where r.id = p_report and r.status = 'open'
  returning r.reported_id,
            (select c.request_id from nata.conversations c
              where c.id = r.conversation_id)
    into who, req;
  if not found then
    raise exception 'nata:not_open';
  end if;
  perform nata.log_support('report_reviewed', 'Report reviewed · ' ||
    coalesce(nata.short_name(who), ''), req);
end;
$$;
revoke all on function public.support_review_report(uuid, text) from public, anon;
grant execute on function public.support_review_report(uuid, text) to authenticated;

-- The dashboard also counts open chat reports.
drop function if exists public.support_summary();
create or replace function public.support_summary()
returns table (
  open_problems     integer,
  locked_deliveries integer,
  failed_payments   integer,
  open_reports      integer
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
    (select count(*)::integer from nata.chat_reports cr where cr.status = 'open');
end;
$$;
revoke all on function public.support_summary() from public, anon;
grant execute on function public.support_summary() to authenticated;
