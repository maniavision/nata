-- Messaging between a sender and a traveler.
--
-- Built on the two tables that already exist:
--   nata.conversations (id, request_id UNIQUE -> delivery_requests, ...)
--   nata.messages      (id, conversation_id, author_id, body, attachment_path,
--                       read_at, ...)
--
-- A conversation belongs to one delivery request, so its two participants are
-- that request's sender (delivery_requests.sender_id) and the trip's traveler
-- (trips.traveler_id). No separate participants table is needed.
--
-- Run in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql
--
-- Safe to re-run.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Who is in a conversation?
--    SECURITY DEFINER so it can look at requests and trips without being
--    blocked by their own row-level security (and without recursion).
--    Takes text so it can also be used on storage paths; anything that is not a
--    valid uuid is simply "not a member".
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function nata.is_conversation_member(p_conversation text)
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
      and auth.uid() is not null
      and (r.sender_id = auth.uid() or t.traveler_id = auth.uid())
  );
end;
$$;

revoke all on function nata.is_conversation_member(text) from public;
grant execute on function nata.is_conversation_member(text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Row-level security
-- ─────────────────────────────────────────────────────────────────────────────
alter table nata.conversations enable row level security;
alter table nata.messages      enable row level security;

drop policy if exists "Participants can read their conversations"
  on nata.conversations;
create policy "Participants can read their conversations"
  on nata.conversations for select
  to authenticated
  using (nata.is_conversation_member(id::text));

drop policy if exists "Participants can read messages" on nata.messages;
create policy "Participants can read messages"
  on nata.messages for select
  to authenticated
  using (nata.is_conversation_member(conversation_id::text));

-- You can only write as yourself, into a conversation you are part of, and a
-- new message is always unread.
drop policy if exists "Participants can send messages" on nata.messages;
create policy "Participants can send messages"
  on nata.messages for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and read_at is null
    and nata.is_conversation_member(conversation_id::text)
  );

-- No UPDATE / DELETE policy: messages cannot be edited or removed from the
-- app. "Read" is set only through mark_conversation_read() below.
revoke all on nata.conversations from authenticated;
revoke all on nata.messages from authenticated;
grant select on nata.conversations to authenticated;
grant select, insert on nata.messages to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Triggers
-- ─────────────────────────────────────────────────────────────────────────────
drop trigger if exists set_updated_at on nata.conversations;
create trigger set_updated_at before update on nata.conversations
  for each row execute function nata.set_updated_at();

drop trigger if exists set_updated_at on nata.messages;
create trigger set_updated_at before update on nata.messages
  for each row execute function nata.set_updated_at();

-- A new message moves its conversation to the top of the list.
create or replace function nata.bump_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update nata.conversations set updated_at = now() where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists bump_conversation on nata.messages;
create trigger bump_conversation after insert on nata.messages
  for each row execute function nata.bump_conversation();

create index if not exists messages_conversation_created_idx
  on nata.messages (conversation_id, created_at desc);

-- Every delivery request gets its conversation automatically.
create or replace function nata.create_request_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into nata.conversations (request_id) values (new.id)
  on conflict (request_id) do nothing;
  return new;
end;
$$;

drop trigger if exists create_request_conversation on nata.delivery_requests;
create trigger create_request_conversation after insert on nata.delivery_requests
  for each row execute function nata.create_request_conversation();

-- ... and requests that already exist get one now.
insert into nata.conversations (request_id)
select r.id from nata.delivery_requests r
on conflict (request_id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. The Messages list: one row per conversation, already summarised
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.list_conversations()
returns table (
  conversation_id       uuid,
  request_id            uuid,
  created_at            timestamptz,
  updated_at            timestamptz,
  other_user_id         uuid,
  other_first_name      text,
  other_last_name       text,
  other_avatar_path     text,
  other_verified        boolean,
  i_am_traveler         boolean,
  departure_city        text,
  arrival_city          text,
  item_description      text,
  request_status        text,
  last_body             text,
  last_attachment_path  text,
  last_message_at       timestamptz,
  last_author_id        uuid,
  unread_count          integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    c.request_id,
    c.created_at,
    c.updated_at,
    other.id,
    other.first_name,
    other.last_name,
    other.avatar_path,
    (other.verification_status = 'verified'),
    (t.traveler_id = auth.uid()),
    dc.name,
    ac.name,
    r.item_description,
    r.status,
    lm.body,
    lm.attachment_path,
    lm.created_at,
    lm.author_id,
    coalesce(un.n, 0)::integer
  from nata.conversations c
  join nata.delivery_requests r on r.id = c.request_id
  join nata.trips t on t.id = r.trip_id
  join nata.cities dc on dc.id = t.departure_city_id
  join nata.cities ac on ac.id = t.arrival_city_id
  left join nata.profiles other
    on other.id = case when r.sender_id = auth.uid()
                       then t.traveler_id else r.sender_id end
  left join lateral (
    select m.body, m.attachment_path, m.created_at, m.author_id
    from nata.messages m
    where m.conversation_id = c.id
    order by m.created_at desc
    limit 1
  ) lm on true
  left join lateral (
    select count(*) as n
    from nata.messages m
    where m.conversation_id = c.id
      and m.author_id <> auth.uid()
      and m.read_at is null
  ) un on true
  where auth.uid() is not null
    and (r.sender_id = auth.uid() or t.traveler_id = auth.uid())
  order by coalesce(lm.created_at, c.created_at) desc;
$$;

revoke all on function public.list_conversations() from public;
grant execute on function public.list_conversations() to authenticated;

-- Opening a conversation marks what the OTHER person wrote as read.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update nata.messages
     set read_at = now()
   where conversation_id = p_conversation_id
     and author_id <> auth.uid()
     and read_at is null
     and nata.is_conversation_member(p_conversation_id::text);
$$;

revoke all on function public.mark_conversation_read(uuid) from public;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Private bucket for photos sent in a chat
--    Path convention: {conversation_id}/{timestamp}.{ext}
--    Only the two participants can read or add files in their own folder.
-- ─────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', false)
on conflict (id) do update set public = false;

drop policy if exists "Participants read chat attachments" on storage.objects;
create policy "Participants read chat attachments"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'chat-attachments'
    and nata.is_conversation_member((storage.foldername(name))[1])
  );

drop policy if exists "Participants upload chat attachments" on storage.objects;
create policy "Participants upload chat attachments"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and nata.is_conversation_member((storage.foldername(name))[1])
  );
