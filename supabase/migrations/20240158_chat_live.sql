-- Chat in real time: new messages and read receipts arrive at once, the
-- other person's typing shows, and a new message is notified and pushed.
--
-- Run AFTER 20240157_trip_limit_active_only.sql. Safe to re-run.
--
--   * nata.messages is published to Supabase Realtime. The app listens to its
--     conversation's inserts (new messages) and updates (read receipts);
--     Realtime only passes on rows the listener may read (the messages RLS),
--     so each side only hears its own chats.
--   * Typing goes over a private Realtime broadcast channel named
--     "chat:<conversation id>". Only the conversation's two members may join
--     it, send on it or hear it (policies on realtime.messages below).
--   * Each new message notifies the other member (event message_new), which
--     also pushes it (20240155). To avoid a buzz per line, a member already
--     holding an unread message notification for this chat from the last 10
--     minutes is not notified again.

-- -----------------------------------------------------------------------------
-- 1. New messages and read receipts over Realtime
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'nata' and tablename = 'messages')
  then
    alter publication supabase_realtime add table nata.messages;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Typing, on a private channel per conversation
-- -----------------------------------------------------------------------------
-- "chat:<uuid>" -> is the signed-in user one of its two members?
create or replace function nata.is_chat_topic_member(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_topic like 'chat:%'
     and nata.is_conversation_member(substr(p_topic, 6));
$$;

revoke all on function nata.is_chat_topic_member(text) from public, anon;
grant execute on function nata.is_chat_topic_member(text) to authenticated;

drop policy if exists "Chat members hear their chat channel" on realtime.messages;
create policy "Chat members hear their chat channel"
  on realtime.messages for select
  to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and nata.is_chat_topic_member(realtime.topic())
  );

drop policy if exists "Chat members send on their chat channel" on realtime.messages;
create policy "Chat members send on their chat channel"
  on realtime.messages for insert
  to authenticated
  with check (
    realtime.messages.extension = 'broadcast'
    and nata.is_chat_topic_member(realtime.topic())
  );

-- -----------------------------------------------------------------------------
-- 3. A new message notifies (and pushes to) the other member
-- -----------------------------------------------------------------------------
create or replace function nata.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  sender_id    uuid;
  traveler_id  uuid;
  recipient    uuid;
  author_name  text;
  preview      text;
begin
  select r.sender_id, t.traveler_id
    into sender_id, traveler_id
    from nata.conversations c
    join nata.delivery_requests r on r.id = c.request_id
    join nata.trips t on t.id = r.trip_id
   where c.id = new.conversation_id;

  recipient := case when new.author_id = sender_id then traveler_id
                    else sender_id end;
  if recipient is null or recipient = new.author_id then
    return new;
  end if;

  -- Already told about this chat recently and not opened it yet.
  if exists (
    select 1 from nata.notifications n
     where n.user_id = recipient
       and n.payload ->> 'event' = 'message_new'
       and n.related_id = new.conversation_id
       and not coalesce(n.is_read, false)
       and n.created_at > now() - interval '10 minutes')
  then
    return new;
  end if;

  select nullif(btrim(coalesce(p.first_name, '')), '')
    into author_name
    from nata.profiles p where p.id = new.author_id;

  preview := nullif(btrim(coalesce(new.body, '')), '');
  if preview is not null and char_length(preview) > 120 then
    preview := left(preview, 117) || '...';
  end if;

  perform nata.notify(
    recipient,
    'message',
    'message_new',
    coalesce(author_name, 'New message'),
    coalesce(preview, ''),
    new.conversation_id,
    jsonb_build_object(
      'author', coalesce(author_name, ''),
      'message', coalesce(preview, ''),
      'photo', new.attachment_path is not null,
      'conversation_id', new.conversation_id)
  );
  return new;
end;
$$;

revoke all on function nata.notify_new_message() from public, anon, authenticated;

drop trigger if exists notify_new_message on nata.messages;
create trigger notify_new_message
  after insert on nata.messages
  for each row execute function nata.notify_new_message();

-- Opening the chat marks its message notifications read too.
create or replace function nata.read_message_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.read_at is not null and old.read_at is null then
    update nata.notifications n
       set is_read = true, read_at = coalesce(n.read_at, now())
     where n.related_id = new.conversation_id
       and n.payload ->> 'event' = 'message_new'
       and n.user_id <> new.author_id
       and not coalesce(n.is_read, false);
  end if;
  return new;
end;
$$;

revoke all on function nata.read_message_notifications() from public, anon, authenticated;

drop trigger if exists read_message_notifications on nata.messages;
create trigger read_message_notifications
  after update of read_at on nata.messages
  for each row execute function nata.read_message_notifications();
