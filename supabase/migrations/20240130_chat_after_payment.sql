-- Chat between a sender and a traveler opens once the delivery is paid.
--
-- Run AFTER 20240129_fixed_price_on_accept.sql. Safe to re-run.
--
-- The sender journey: request -> traveler accepts -> sender pays (the money
-- is held in escrow) -> chat unlocks to arrange pickup and handover.
--
--   * nata.chat_unlocked(conversation): the conversation's request is paid,
--     handed off or delivered.
--   * Sending messages and uploading chat photos need an unlocked chat
--     (reading what was already said is still allowed).
--   * A conversation is created automatically when a request becomes paid,
--     so it appears in Messages for both people.
-- The app shows the same rule: before payment the chat has no input, only a
-- note saying it unlocks once the delivery is paid.

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Who is in a conversation?
--    The same as in 20240113_messaging.sql, repeated here so this file also
--    works on a database where that one was never run. A conversation's two
--    participants are its request's sender and the trip's traveler.
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
-- 1. Is the chat open?
-- ─────────────────────────────────────────────────────────────────────────────
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
     where c.id = cid
       and r.status in ('paid', 'handed_off', 'delivered')
  );
end;
$$;

revoke all on function nata.chat_unlocked(text) from public;
grant execute on function nata.chat_unlocked(text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Writing needs an open chat
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "Participants can send messages" on nata.messages;
create policy "Participants can send messages"
  on nata.messages for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and read_at is null
    and nata.is_conversation_member(conversation_id::text)
    and nata.chat_unlocked(conversation_id::text)
  );

drop policy if exists "Participants upload chat attachments" on storage.objects;
create policy "Participants upload chat attachments"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and nata.is_conversation_member((storage.foldername(name))[1])
    and nata.chat_unlocked((storage.foldername(name))[1])
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Paying opens the conversation
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function nata.open_conversation_on_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    insert into nata.conversations (request_id)
    values (new.id)
    on conflict (request_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists open_conversation_on_payment on nata.delivery_requests;
create trigger open_conversation_on_payment
  after update of status on nata.delivery_requests
  for each row execute function nata.open_conversation_on_payment();

-- Requests already paid before this file was run get their conversation too.
insert into nata.conversations (request_id)
select r.id
  from nata.delivery_requests r
 where r.status in ('paid', 'handed_off', 'delivered')
on conflict (request_id) do nothing;
