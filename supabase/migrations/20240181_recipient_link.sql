-- The recipient follows the parcel and chats with the traveler from a link.
--
-- Run AFTER 20240180_sender_reviews_visible.sql. Safe to re-run.
--
-- The recipient isn't on Nata. Once a request is paid it gets a private
-- link (nata.recipient_links.token, 16 random characters), sent in the
-- delivery-code SMS. The page behind it (web/r, Firebase Hosting) shows
-- where the parcel is, who carries it, the handover code and a chat with
-- the traveler, through the two functions below that anyone holding the
-- token may call. The traveler chats from the app.
--
--   * nata.recipient_links: one per request, made when it is paid.
--   * nata.recipient_messages: the traveler <-> recipient chat.
--   * nata.recipient_sms: which update texts the recipient was sent.
--   * public.recipient_view(token): everything the page shows, chat
--     included (the traveler's messages are then read). Works until 7 days
--     after the delivery or cancellation.
--   * public.recipient_send(token, body): the recipient writes (at most 20
--     messages in 10 minutes); the traveler gets a notification and a push.
--   * public.recipient_chat(request_id) / public.send_recipient_message(...):
--     the traveler's side, from the app.
--   * Update texts (recipient-sms edge function), each sent once: picked up,
--     arriving today (daily job), delivered (with the invitation to Nata),
--     and, when the traveler writes and the recipient hasn't opened the page
--     in the last 10 minutes, a "new message" text at most every 30 minutes.

create table if not exists nata.recipient_links (
  request_id    uuid primary key
                references nata.delivery_requests (id) on delete cascade,
  token         text not null unique,
  last_seen_at  timestamptz,
  created_at    timestamptz not null default now()
);
alter table nata.recipient_links enable row level security;

create table if not exists nata.recipient_messages (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null
              references nata.delivery_requests (id) on delete cascade,
  author      text not null check (author in ('traveler', 'recipient')),
  body        text not null
              check (char_length(btrim(body)) between 1 and 1000),
  created_at  timestamptz not null default now(),
  read_at     timestamptz
);
create index if not exists recipient_messages_request
  on nata.recipient_messages (request_id, created_at);
alter table nata.recipient_messages enable row level security;

create table if not exists nata.recipient_sms (
  request_id  uuid not null
              references nata.delivery_requests (id) on delete cascade,
  event       text not null,
  sent_at     timestamptz not null default now(),
  primary key (request_id, event)
);
alter table nata.recipient_sms enable row level security;

-- -----------------------------------------------------------------------------
-- 1. The link
-- -----------------------------------------------------------------------------
-- The request's token, made the first time it is asked for.
create or replace function nata.recipient_token(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  t text;
begin
  select l.token into t from nata.recipient_links l
   where l.request_id = p_request_id;
  if t is not null then
    return t;
  end if;
  loop
    t := translate(encode(extensions.gen_random_bytes(12), 'base64'),
                   '+/', '-_');
    begin
      insert into nata.recipient_links (request_id, token)
      values (p_request_id, t)
      on conflict (request_id) do nothing;
      exit;
    exception when unique_violation then
      -- The same token twice: try another.
    end;
  end loop;
  select l.token into t from nata.recipient_links l
   where l.request_id = p_request_id;
  return t;
end;
$$;
revoke all on function nata.recipient_token(uuid)
  from public, anon, authenticated;
-- send-delivery-code puts the link in its text.
grant execute on function nata.recipient_token(uuid) to service_role;

-- The request behind a token, while the page may show it.
create or replace function nata.recipient_request(p_token text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select r.id
    from nata.recipient_links l
    join nata.delivery_requests r on r.id = l.request_id
   where l.token = btrim(coalesce(p_token, ''))
     and r.status in ('paid', 'handed_off', 'delivered', 'cancelled')
     and (r.status in ('paid', 'handed_off')
          or coalesce(r.delivered_at, r.cancelled_at, r.updated_at)
             > now() - interval '7 days');
$$;
revoke all on function nata.recipient_request(text)
  from public, anon, authenticated;

-- Whether the chat is open: until a day after the delivery.
create or replace function nata.recipient_chat_open(p_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from nata.delivery_requests r
     where r.id = p_request_id
       and (r.status in ('paid', 'handed_off')
            or (r.status = 'delivered'
                and coalesce(r.delivered_at, r.updated_at)
                    > now() - interval '1 day')));
$$;
revoke all on function nata.recipient_chat_open(uuid)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Update texts (recipient-sms edge function)
-- -----------------------------------------------------------------------------
-- Asks recipient-sms to text [p_event] for [p_request_id] (or nothing, if
-- not set up yet). The function sends each update once.
create or replace function nata.request_recipient_sms(
  p_request_id uuid,
  p_event text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  secret text;
  anon   text;
begin
  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'payment_jobs_secret';
  select decrypted_secret into anon
    from vault.decrypted_secrets where name = 'payment_jobs_anon_key';
  if secret is null or anon is null then
    return;
  end if;
  perform net.http_post(
    url := 'https://xnzredskhxfgywggetzw.supabase.co/functions/v1/recipient-sms',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || anon,
      'x-job-secret', secret),
    body := jsonb_build_object('request_id', p_request_id, 'event', p_event)
  );
exception when others then
  -- A text must never stop the change that caused it.
  raise warning 'request_recipient_sms failed: %', sqlerrm;
end;
$$;
revoke all on function nata.request_recipient_sms(uuid, text)
  from public, anon, authenticated;

-- Paid: the link is made (the delivery-code SMS carries it). Picked up and
-- delivered: the recipient is texted.
create or replace function nata.recipient_on_request_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  if new.status in ('paid', 'handed_off') then
    perform nata.recipient_token(new.id);
  end if;
  if new.status = 'handed_off' then
    perform nata.request_recipient_sms(new.id, 'picked_up');
  elsif new.status = 'delivered' then
    perform nata.request_recipient_sms(new.id, 'delivered');
  end if;
  return new;
exception when others then
  raise warning 'recipient_on_request_change failed: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists recipient_on_request_change on nata.delivery_requests;
create trigger recipient_on_request_change
  after update of status on nata.delivery_requests
  for each row execute function nata.recipient_on_request_change();

-- Every morning: the recipients whose parcel lands today.
create or replace function nata.run_recipient_arrivals()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select dr.id
      from nata.delivery_requests dr
      join nata.trips t on t.id = dr.trip_id
     where dr.status in ('paid', 'handed_off')
       and t.arrival_date = current_date
       and not exists (select 1 from nata.recipient_sms s
                        where s.request_id = dr.id and s.event = 'arriving')
  loop
    perform nata.request_recipient_sms(r.id, 'arriving');
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function nata.run_recipient_arrivals()
  from public, anon, authenticated;

select cron.unschedule('recipient-arrivals')
 where exists (select 1 from cron.job where jobname = 'recipient-arrivals');
select cron.schedule(
  'recipient-arrivals', '0 8 * * *',
  $job$ select nata.run_recipient_arrivals(); $job$
);

-- Links for the requests already paid.
select nata.recipient_token(r.id)
  from nata.delivery_requests r
 where r.status in ('paid', 'handed_off');

-- -----------------------------------------------------------------------------
-- 3. The recipient's page (anyone with the link)
-- -----------------------------------------------------------------------------
create or replace function public.recipient_view(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid    uuid := nata.recipient_request(p_token);
  result jsonb;
begin
  if rid is null then
    return null;
  end if;

  update nata.recipient_links set last_seen_at = now() where request_id = rid;
  update nata.recipient_messages
     set read_at = now()
   where request_id = rid and author = 'traveler' and read_at is null;

  select jsonb_build_object(
    'status', r.status,
    'paid_at', r.paid_at,
    'picked_up_at', r.picked_up_at,
    'delivered_at', r.delivered_at,
    'sender', coalesce(sp.first_name, ''),
    'recipient', coalesce(rr.name, ''),
    'items', coalesce(
      (select jsonb_agg(i.name order by i.position)
         from nata.request_items i where i.request_id = r.id),
      to_jsonb(array_remove(array[r.item_name], null))),
    'traveler', jsonb_build_object(
      'first_name', coalesce(tp.first_name, ''),
      'initial', left(coalesce(tp.last_name, ''), 1),
      'avatar_path', tp.avatar_path,
      'verified', coalesce(tp.verification_status = 'verified', false),
      'rating', tp.avg_rating,
      'deliveries', (select count(*) from nata.delivery_requests d
                       join nata.trips dt on dt.id = d.trip_id
                      where dt.traveler_id = t.traveler_id
                        and d.status = 'delivered')),
    'from_city', dc.name,
    'from_code', dc.country_code,
    'to_city', ac.name,
    'to_code', ac.country_code,
    'departure_date', t.departure_date,
    'arrival_date', t.arrival_date,
    -- The handover code until the parcel is handed over.
    'code', case when r.status in ('paid', 'handed_off')
                 then (select c.code from nata.delivery_codes c
                        where c.request_id = r.id) end,
    'chat_open', nata.recipient_chat_open(r.id),
    'messages', coalesce(
      (select jsonb_agg(jsonb_build_object(
                'id', m.id, 'author', m.author, 'body', m.body,
                'at', m.created_at, 'read', m.read_at is not null)
                order by m.created_at)
         from nata.recipient_messages m where m.request_id = r.id),
      '[]'::jsonb))
    into result
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
    left join nata.profiles sp on sp.id = r.sender_id
    left join nata.profiles tp on tp.id = t.traveler_id
    left join nata.cities dc on dc.id = t.departure_city_id
    left join nata.cities ac on ac.id = t.arrival_city_id
    left join nata.request_recipients rr on rr.request_id = r.id
   where r.id = rid;
  return result;
end;
$$;
revoke all on function public.recipient_view(text) from public;
grant execute on function public.recipient_view(text) to anon, authenticated;

create or replace function public.recipient_send(p_token text, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid       uuid := nata.recipient_request(p_token);
  v_body    text := btrim(coalesce(p_body, ''));
  traveler  uuid;
  who       text;
  sender    text;
  preview   text;
  info      jsonb;
  pending   uuid;
  new_id    uuid;
begin
  if rid is null then
    raise exception 'nata:link_invalid';
  end if;
  if not nata.recipient_chat_open(rid) then
    raise exception 'nata:chat_closed';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 then
    raise exception 'nata:message_invalid';
  end if;
  if (select count(*) from nata.recipient_messages m
       where m.request_id = rid and m.author = 'recipient'
         and m.created_at > now() - interval '10 minutes') >= 20 then
    raise exception 'nata:too_many_messages';
  end if;

  insert into nata.recipient_messages (request_id, author, body)
  values (rid, 'recipient', v_body)
  returning id into new_id;
  update nata.recipient_links set last_seen_at = now() where request_id = rid;

  -- The traveler is told (one notification per chat while unread).
  select t.traveler_id, nullif(btrim(coalesce(rr.name, '')), ''),
         sp.first_name
    into traveler, who, sender
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
    left join nata.request_recipients rr on rr.request_id = r.id
    left join nata.profiles sp on sp.id = r.sender_id
   where r.id = rid;

  preview := case when char_length(v_body) > 120
                  then left(v_body, 117) || '...' else v_body end;
  info := jsonb_build_object(
    'recipient', coalesce(who, ''),
    'sender', coalesce(sender, ''),
    'message', preview,
    'request_id', rid,
    'event', 'recipient_message');

  select n.id into pending
    from nata.notifications n
   where n.user_id = traveler
     and n.payload ->> 'event' = 'recipient_message'
     and n.related_id = rid
     and not coalesce(n.is_read, false)
   order by n.created_at desc
   limit 1;
  if pending is not null then
    update nata.notifications
       set title = coalesce(who, 'Recipient'), body = preview,
           payload = info, created_at = now(), pushed_at = null
     where id = pending;
    if exists (select 1 from nata.push_tokens p where p.user_id = traveler) then
      perform nata.request_push(array[pending]);
    end if;
  else
    perform nata.notify(traveler, 'message', 'recipient_message',
      coalesce(who, 'Recipient'), preview, rid, info);
  end if;

  return jsonb_build_object('id', new_id);
end;
$$;
revoke all on function public.recipient_send(text, text) from public;
grant execute on function public.recipient_send(text, text)
  to anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. The traveler's side (the app)
-- -----------------------------------------------------------------------------
create or replace function public.recipient_chat(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid    uuid := auth.uid();
  result jsonb;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;
  if not exists (
    select 1 from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.id = p_request_id and t.traveler_id = uid
       and r.status in ('paid', 'handed_off', 'delivered')) then
    raise exception 'nata:request_not_found';
  end if;

  update nata.recipient_messages
     set read_at = now()
   where request_id = p_request_id and author = 'recipient'
     and read_at is null;
  -- Reading the chat reads its notification too.
  update nata.notifications
     set is_read = true, read_at = coalesce(read_at, now())
   where user_id = uid and related_id = p_request_id
     and payload ->> 'event' = 'recipient_message'
     and not coalesce(is_read, false);

  select jsonb_build_object(
    'recipient', coalesce(rr.name, ''),
    'sender', coalesce(sp.first_name, ''),
    'item', coalesce(
      (select i.name from nata.request_items i
        where i.request_id = r.id order by i.position limit 1),
      r.item_name, ''),
    'seen_at', l.last_seen_at,
    'chat_open', nata.recipient_chat_open(r.id),
    'messages', coalesce(
      (select jsonb_agg(jsonb_build_object(
                'id', m.id, 'author', m.author, 'body', m.body,
                'at', m.created_at, 'read', m.read_at is not null)
                order by m.created_at)
         from nata.recipient_messages m where m.request_id = r.id),
      '[]'::jsonb))
    into result
    from nata.delivery_requests r
    left join nata.request_recipients rr on rr.request_id = r.id
    left join nata.profiles sp on sp.id = r.sender_id
    left join nata.recipient_links l on l.request_id = r.id
   where r.id = p_request_id;
  return result;
end;
$$;
revoke all on function public.recipient_chat(uuid) from public;
grant execute on function public.recipient_chat(uuid) to authenticated;

create or replace function public.send_recipient_message(
  p_request_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid     uuid := auth.uid();
  v_body  text := btrim(coalesce(p_body, ''));
  seen    timestamptz;
  nudged  timestamptz;
  new_id  uuid;
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

  -- The recipient isn't on the page: a text, at most every 30 minutes.
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
$$;
revoke all on function public.send_recipient_message(uuid, text) from public;
grant execute on function public.send_recipient_message(uuid, text)
  to authenticated;
