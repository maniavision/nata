-- Every event reaches the phone.
--
-- Run AFTER 20240175_payout_accounts_two.sql. Safe to re-run.
--
--   * Chat: every message is pushed. Before, a message was not notified
--     while the chat's last notification was unread and under 10 minutes
--     old, so a conversation pushed once. Now that unread notification is
--     brought up to date with the new message (and to the top of the list)
--     and pushed again: one row per chat in the list, a push per message.
--   * Paid: the sender is told too (payment_received), not only the traveler.
--   * Delivered: the traveler is told too (delivery_confirmed), not only the
--     sender.
--
-- The app writes these in the user's language from payload.event
-- (notification_text.dart), and send-push does too (texts.ts).

-- -----------------------------------------------------------------------------
-- 1. Delivery requests (20240142, with the two new events)
-- -----------------------------------------------------------------------------
create or replace function nata.notify_request_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  traveler   uuid;
  sender     text;
  trav_name  text;
  route      text;
  info       jsonb;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  select t.traveler_id,
         coalesce(dc.name, '') || ' → ' || coalesce(ac.name, ''),
         tp.first_name
    into traveler, route, trav_name
    from nata.trips t
    left join nata.cities dc on dc.id = t.departure_city_id
    left join nata.cities ac on ac.id = t.arrival_city_id
    left join nata.profiles tp on tp.id = t.traveler_id
   where t.id = new.trip_id;

  select p.first_name into sender from nata.profiles p where p.id = new.sender_id;

  info := jsonb_build_object(
    'sender', coalesce(sender, ''),
    'traveler', coalesce(trav_name, ''),
    'route', coalesce(route, ''),
    'request_id', new.id);

  if tg_op = 'INSERT' then
    perform nata.notify(traveler, 'request', 'request_new',
      'New delivery request',
      coalesce(sender, 'A sender') || ' wants you to carry an item on ' || route || '.',
      new.id, info);
    return new;
  end if;

  case new.status
    when 'accepted' then
      perform nata.notify(new.sender_id, 'request', 'request_accepted',
        'Request accepted',
        coalesce(trav_name, 'The traveler') || ' accepted your request. Pay within 24 hours to confirm it.',
        new.id, info);
    when 'declined' then
      perform nata.notify(new.sender_id, 'request', 'request_declined',
        'Request declined',
        coalesce(trav_name, 'The traveler') || ' can''t take your item. Find another traveler on ' || route || '.',
        new.id, info);
    when 'expired' then
      if old.status = 'pending' then
        perform nata.notify(new.sender_id, 'request', 'request_expired_unanswered',
          'Request expired',
          coalesce(trav_name, 'The traveler') || ' didn''t answer in time. Find another traveler.',
          new.id, info);
      else
        perform nata.notify(new.sender_id, 'request', 'request_expired_unpaid',
          'Request expired',
          'The 24 hours to pay have passed, so the request was closed.',
          new.id, info);
        perform nata.notify(traveler, 'request', 'request_expired_unpaid_traveler',
          'Request expired',
          coalesce(sender, 'The sender') || ' didn''t pay in time, so the request was closed.',
          new.id, info);
      end if;
    when 'cancelled' then
      if auth.uid() is not null and auth.uid() = traveler then
        perform nata.notify(new.sender_id, 'request', 'request_cancelled_by_traveler',
          'Request cancelled',
          coalesce(trav_name, 'The traveler') || ' cancelled your request.',
          new.id, info);
      else
        perform nata.notify(traveler, 'request', 'request_cancelled_by_sender',
          'Request cancelled',
          coalesce(sender, 'The sender') || ' cancelled their request on ' || route || '.',
          new.id, info);
      end if;
    when 'paid' then
      perform nata.notify(traveler, 'payment', 'request_paid',
        'Payment secured',
        coalesce(sender, 'The sender') || ' paid. The money is held safely until delivery, and chat is open.',
        new.id, info);
      perform nata.notify(new.sender_id, 'payment', 'payment_received',
        'Payment received',
        'Your payment is held safely until delivery. You can now chat with '
          || coalesce(trav_name, 'the traveler') || '.',
        new.id, info);
    when 'handed_off' then
      perform nata.notify(new.sender_id, 'trip', 'item_picked_up',
        'Item picked up',
        coalesce(trav_name, 'The traveler') || ' has your item and is on the way.',
        new.id, info);
    when 'delivered' then
      perform nata.notify(new.sender_id, 'request', 'item_delivered',
        'Item delivered',
        coalesce(trav_name, 'The traveler') || ' delivered your item. Confirm you received it.',
        new.id, info);
      perform nata.notify(traveler, 'payment', 'delivery_confirmed',
        'Delivery confirmed',
        'You delivered ' || coalesce(sender, 'the sender') || '''s item. Your payout is on its way.',
        new.id, info);
    else
      null;
  end case;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Chat messages (20240158): a push for every message
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
  info         jsonb;
  pending      uuid;
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

  select nullif(btrim(coalesce(p.first_name, '')), '')
    into author_name
    from nata.profiles p where p.id = new.author_id;

  preview := nullif(btrim(coalesce(new.body, '')), '');
  if preview is not null and char_length(preview) > 120 then
    preview := left(preview, 117) || '...';
  end if;

  info := jsonb_build_object(
    'author', coalesce(author_name, ''),
    'message', coalesce(preview, ''),
    'photo', new.attachment_path is not null,
    'conversation_id', new.conversation_id,
    'event', 'message_new');

  -- The chat's notification not read yet: brought up to date and pushed
  -- again, rather than a new row per message.
  select n.id into pending
    from nata.notifications n
   where n.user_id = recipient
     and n.payload ->> 'event' = 'message_new'
     and n.related_id = new.conversation_id
     and not coalesce(n.is_read, false)
   order by n.created_at desc
   limit 1;

  if pending is not null then
    begin
      update nata.notifications
         set title = coalesce(author_name, 'New message'),
             body = coalesce(preview, ''),
             payload = info,
             created_at = now(),
             pushed_at = null
       where id = pending;
      if exists (select 1 from nata.push_tokens t where t.user_id = recipient) then
        perform nata.request_push(array[pending]);
      end if;
    exception when others then
      -- A notification must never stop the message.
      raise warning 'notify_new_message failed: %', sqlerrm;
    end;
    return new;
  end if;

  perform nata.notify(
    recipient,
    'message',
    'message_new',
    coalesce(author_name, 'New message'),
    coalesce(preview, ''),
    new.conversation_id,
    info
  );
  return new;
end;
$$;

revoke all on function nata.notify_new_message() from public, anon, authenticated;
