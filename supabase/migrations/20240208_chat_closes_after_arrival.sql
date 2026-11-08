-- A chat closes 5 days after the trip's arrival date.
--
-- Run AFTER 20240190_chat_report_block.sql. Safe to re-run.
--
-- Chats already close once the item is delivered (20240164) or when either
-- member blocks the other (20240190). Now they also close on the trip's
-- arrival date + 5 days (UTC), even if the delivery was never marked
-- delivered: from then on neither member can send a message or upload a
-- chat photo. What was said stays readable.
--
-- nata.chat_closes_on() is the one place the 5 days are set. The app reads
-- the same date from list_conversations().chat_closes_on to show the chat
-- as closed.

create or replace function nata.chat_closes_on(p_arrival date)
returns date
language sql
immutable
set search_path = ''
as $$
  select p_arrival + 5;
$$;

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
       and (now() at time zone 'utc')::date < nata.chat_closes_on(t.arrival_date)
  );
end;
$$;
revoke all on function nata.chat_unlocked(text) from public;
grant execute on function nata.chat_unlocked(text) to authenticated;

-- list_conversations gains chat_closes_on. Adding a column changes the
-- return type, so the function is dropped and created again.
drop function if exists public.list_conversations();

create function public.list_conversations()
returns table (
  conversation_id uuid,
  request_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  other_user_id uuid,
  other_first_name text,
  other_last_name text,
  other_avatar_path text,
  other_verified boolean,
  i_am_traveler boolean,
  departure_city text,
  arrival_city text,
  item_description text,
  request_status text,
  last_body text,
  last_attachment_path text,
  last_message_at timestamptz,
  last_author_id uuid,
  unread_count integer,
  chat_closes_on date
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
    coalesce(un.n, 0)::integer,
    nata.chat_closes_on(t.arrival_date)
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
grant execute on function public.list_conversations() to authenticated, anon;
