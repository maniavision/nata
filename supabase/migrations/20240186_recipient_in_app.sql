-- Recipients on Nata chat with the traveler in the app.
--
-- Run AFTER 20240185_recipient_link_ends_at_delivery.sql. Safe to re-run.
--
-- The recipient's link (20240181) now opens the app when it's installed
-- (universal links / app links on nata-app-a03de.web.app/r/...). A signed-in
-- member who opens it takes the link: from then on the conversation with
-- the traveler is in their Messages, and the traveler's messages reach
-- them as a notification and a push (not an SMS). The page keeps working
-- for anyone with the link.
--
--   * recipient_links.recipient_user_id: the member who took the link.
--   * public.claim_recipient_link(token): the signed-in member takes it
--     (not the traveler; one member per link).
--   * public.my_recipient_chat(request_id) / send_as_recipient(...): the
--     page's view and send, for that member.
--   * public.list_recipient_chats(): these chats in Messages, for the
--     traveler (once there's a message) and for the member recipient.
--   * nata.notify_recipient_member(...): the member's notification (one per
--     chat while unread), event recipient_message_in.
--   * public.send_recipient_message(): notifies the member instead of
--     texting (the live function with only that changed).

alter table nata.recipient_links
  add column if not exists recipient_user_id uuid
    references nata.profiles (id) on delete set null;
create index if not exists recipient_links_member
  on nata.recipient_links (recipient_user_id);

-- -----------------------------------------------------------------------------
-- 1. Taking the link
-- -----------------------------------------------------------------------------
create or replace function public.claim_recipient_link(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid  uuid := auth.uid();
  rid  uuid := nata.recipient_request(p_token);
  who  uuid;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if rid is null then
    raise exception 'nata:link_invalid';
  end if;
  if exists (select 1 from nata.delivery_requests r
               join nata.trips t on t.id = r.trip_id
              where r.id = rid and t.traveler_id = uid) then
    raise exception 'nata:not_recipient';
  end if;
  select l.recipient_user_id into who
    from nata.recipient_links l where l.request_id = rid for update;
  if who is not null and who <> uid then
    raise exception 'nata:link_taken';
  end if;
  update nata.recipient_links
     set recipient_user_id = uid, last_seen_at = now()
   where request_id = rid;
  return rid;
end;
$$;
revoke all on function public.claim_recipient_link(text) from public, anon;
grant execute on function public.claim_recipient_link(text) to authenticated;

-- The token of a link the signed-in member took.
create or replace function nata.my_recipient_token(p_request_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select l.token from nata.recipient_links l
   where l.request_id = p_request_id
     and l.recipient_user_id = auth.uid()
     and auth.uid() is not null;
$$;
revoke all on function nata.my_recipient_token(uuid)
  from public, anon, authenticated;

create or replace function public.my_recipient_chat(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      text := nata.my_recipient_token(p_request_id);
  result jsonb;
begin
  if t is null then
    raise exception 'nata:request_not_found';
  end if;
  result := public.recipient_view(t);
  if result is null then
    raise exception 'nata:link_invalid';
  end if;
  -- Reading the chat reads its notification too.
  update nata.notifications
     set is_read = true, read_at = coalesce(read_at, now())
   where user_id = auth.uid() and related_id = p_request_id
     and payload ->> 'event' = 'recipient_message_in'
     and not coalesce(is_read, false);
  return result || jsonb_build_object('request_id', p_request_id);
end;
$$;
revoke all on function public.my_recipient_chat(uuid) from public, anon;
grant execute on function public.my_recipient_chat(uuid) to authenticated;

create or replace function public.send_as_recipient(
  p_request_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t text := nata.my_recipient_token(p_request_id);
begin
  if t is null then
    raise exception 'nata:request_not_found';
  end if;
  return public.recipient_send(t, p_body);
end;
$$;
revoke all on function public.send_as_recipient(uuid, text) from public, anon;
grant execute on function public.send_as_recipient(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. In Messages
-- -----------------------------------------------------------------------------
create or replace function public.list_recipient_chats()
returns table (
  request_id    uuid,
  role          text,     -- 'traveler' or 'recipient': the caller's side
  other_name    text,
  other_avatar  text,
  sender_name   text,
  item          text,
  last_body     text,
  last_mine     boolean,
  last_at       timestamptz,
  unread        integer,
  chat_open     boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    -- The traveler's: requests on their trips with at least one message.
    select r.id, 'traveler'::text as role
      from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where t.traveler_id = auth.uid()
       and exists (select 1 from nata.recipient_messages m
                    where m.request_id = r.id)
    union
    -- The member recipient's: links they took.
    select l.request_id, 'recipient'
      from nata.recipient_links l
     where l.recipient_user_id = auth.uid()
  )
  select r.id,
         mine.role,
         case when mine.role = 'traveler'
              then coalesce(rr.name, '')
              else coalesce(tp.first_name, '')
                   || coalesce(' ' || left(nullif(tp.last_name, ''), 1) || '.', '')
         end,
         case when mine.role = 'traveler' then null else tp.avatar_path end,
         coalesce(sp.first_name, ''),
         coalesce((select i.name from nata.request_items i
                    where i.request_id = r.id order by i.position limit 1),
                  r.item_name, ''),
         lm.body,
         lm.author = mine.role,
         coalesce(lm.created_at, l.created_at),
         (select count(*)::integer from nata.recipient_messages m
           where m.request_id = r.id and m.read_at is null
             and m.author <> mine.role),
         nata.recipient_chat_open(r.id)
    from mine
    join nata.delivery_requests r on r.id = mine.id
    join nata.trips t on t.id = r.trip_id
    left join nata.profiles tp on tp.id = t.traveler_id
    left join nata.profiles sp on sp.id = r.sender_id
    left join nata.request_recipients rr on rr.request_id = r.id
    left join nata.recipient_links l on l.request_id = r.id
    left join lateral (
      select m.body, m.author, m.created_at
        from nata.recipient_messages m
       where m.request_id = r.id
       order by m.created_at desc limit 1) lm on true
   where auth.uid() is not null
     -- Closed chats stay a week after the delivery, then leave the list.
     and (r.status in ('paid', 'handed_off')
          or coalesce(r.delivered_at, r.cancelled_at, r.updated_at)
             > now() - interval '7 days')
   order by coalesce(lm.created_at, l.created_at) desc;
$$;
revoke all on function public.list_recipient_chats() from public, anon;
grant execute on function public.list_recipient_chats() to authenticated;

-- -----------------------------------------------------------------------------
-- 3. The member recipient is notified
-- -----------------------------------------------------------------------------
create or replace function nata.notify_recipient_member(
  p_request_id uuid,
  p_member uuid,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  author   text;
  sender   text;
  preview  text := case when char_length(p_body) > 120
                        then left(p_body, 117) || '...' else p_body end;
  info     jsonb;
  pending  uuid;
begin
  select tp.first_name, sp.first_name into author, sender
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
    left join nata.profiles tp on tp.id = t.traveler_id
    left join nata.profiles sp on sp.id = r.sender_id
   where r.id = p_request_id;
  info := jsonb_build_object(
    'author', coalesce(author, ''),
    'sender', coalesce(sender, ''),
    'message', preview,
    'request_id', p_request_id,
    'event', 'recipient_message_in');

  select n.id into pending
    from nata.notifications n
   where n.user_id = p_member
     and n.payload ->> 'event' = 'recipient_message_in'
     and n.related_id = p_request_id
     and not coalesce(n.is_read, false)
   order by n.created_at desc
   limit 1;
  if pending is not null then
    update nata.notifications
       set title = coalesce(author, 'Traveler'), body = preview,
           payload = info, created_at = now(), pushed_at = null
     where id = pending;
    if exists (select 1 from nata.push_tokens p where p.user_id = p_member) then
      perform nata.request_push(array[pending]);
    end if;
  else
    perform nata.notify(p_member, 'message', 'recipient_message_in',
      coalesce(author, 'Traveler'), preview, p_request_id, info);
  end if;
exception when others then
  raise warning 'notify_recipient_member failed: %', sqlerrm;
end;
$$;
revoke all on function nata.notify_recipient_member(uuid, uuid, text)
  from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.send_recipient_message(p_request_id uuid, p_body text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid     uuid := auth.uid();
  v_body  text := btrim(coalesce(p_body, ''));
  seen    timestamptz;
  nudged  timestamptz;
  new_id  uuid;
  member  uuid;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (
    select 1 from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.id = p_request_id and t.traveler_id = uid) then
    raise exception 'nata:request_not_found';
  end if;
  if not nata.recipient_chat_open(p_request_id) then
    raise exception 'nata:chat_closed';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 then
    raise exception 'nata:message_invalid';
  end if;

  perform nata.recipient_token(p_request_id);
  insert into nata.recipient_messages (request_id, author, body)
  values (p_request_id, 'traveler', v_body)
  returning id into new_id;

  -- A recipient on Nata (they opened the link in the app) gets a
  -- notification and a push (20240186).
  select l.recipient_user_id into member
    from nata.recipient_links l where l.request_id = p_request_id;
  if member is not null then
    perform nata.notify_recipient_member(p_request_id, member, v_body);
    return new_id;
  end if;

  -- Otherwise, when they aren't on the page: a text, at most every 30
  -- minutes.
  select l.last_seen_at into seen
    from nata.recipient_links l where l.request_id = p_request_id;
  select s.sent_at into nudged
    from nata.recipient_sms s
   where s.request_id = p_request_id and s.event = 'message';
  if (seen is null or seen < now() - interval '10 minutes')
     and (nudged is null or nudged < now() - interval '30 minutes') then
    perform nata.request_recipient_sms(p_request_id, 'message');
  end if;

  return new_id;
end;
$function$;
