-- Notifications for each step of a delivery.
--
-- Run AFTER 20240141_wallet_history.sql. Safe to re-run.
--
-- 1. The live nata.notifications table was created before
--    20240112_notifications.sql (with type / payload / read_at), so that
--    file's CREATE TABLE never ran. This adds the columns the app reads
--    (title, body, image_url, related_id, is_read) without dropping anything,
--    keeps read_at in step with is_read, and sets the read / mark-read
--    policies again.
-- 2. nata.notify() writes one notification. The text is not stored in one
--    language: payload.event names what happened (request_accepted, ...) and
--    payload carries the names and route, so the app writes it in the user's
--    language. title / body hold an English copy for anything else.
-- 3. Triggers call it when a request is created or changes status, when a
--    payout is paid, and when an identity check is decided.

-- -----------------------------------------------------------------------------
-- 1. The table
-- -----------------------------------------------------------------------------
create table if not exists nata.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references nata.profiles (id) on delete cascade,
  type        text not null default 'system',
  created_at  timestamptz not null default now()
);

alter table nata.notifications
  add column if not exists title       text not null default '',
  add column if not exists body        text not null default '',
  add column if not exists image_url   text,
  add column if not exists related_id  uuid,
  add column if not exists payload     jsonb not null default '{}'::jsonb,
  add column if not exists is_read     boolean not null default false,
  add column if not exists read_at     timestamptz;

-- Rows read before is_read existed.
update nata.notifications set is_read = true
 where read_at is not null and not is_read;

create index if not exists notifications_user_created_idx
  on nata.notifications (user_id, created_at desc);

create or replace function nata.notifications_sync_read()
returns trigger
language plpgsql
as $$
begin
  if new.is_read and new.read_at is null then
    new.read_at := now();
  elsif not new.is_read then
    new.read_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_sync_read on nata.notifications;
create trigger notifications_sync_read
  before insert or update of is_read on nata.notifications
  for each row execute function nata.notifications_sync_read();

alter table nata.notifications enable row level security;

drop policy if exists "Users can read their own notifications"
  on nata.notifications;
create policy "Users can read their own notifications"
  on nata.notifications for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can mark their own notifications read"
  on nata.notifications;
create policy "Users can mark their own notifications read"
  on nata.notifications for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke insert, update, delete on nata.notifications from anon, authenticated;
grant select on nata.notifications to authenticated;
grant update (is_read) on nata.notifications to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Writing one
-- -----------------------------------------------------------------------------
create or replace function nata.notify(
  p_user     uuid,
  p_type     text,
  p_event    text,
  p_title    text,
  p_body     text,
  p_related  uuid default null,
  p_payload  jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user is null then
    return;
  end if;
  insert into nata.notifications
    (user_id, type, title, body, related_id, payload)
  values
    (p_user, p_type, p_title, coalesce(p_body, ''), p_related,
     coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('event', p_event));
exception when others then
  -- A notification must never stop the change that caused it.
  raise warning 'nata.notify failed: %', sqlerrm;
end;
$$;

revoke all on function nata.notify(uuid, text, text, text, text, uuid, jsonb)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Delivery requests
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
    else
      null;
  end case;
  return new;
end;
$$;

drop trigger if exists notify_request_change on nata.delivery_requests;
create trigger notify_request_change
  after insert or update of status on nata.delivery_requests
  for each row execute function nata.notify_request_change();

-- -----------------------------------------------------------------------------
-- 4. Payouts
-- -----------------------------------------------------------------------------
create or replace function nata.notify_payout_paid()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    perform nata.notify(new.traveler_id, 'payment', 'payout_paid',
      'Payout sent',
      'Your payout of ' || coalesce(new.payout_currency, new.currency, '') || ' '
        || coalesce(new.payout_amount, new.amount)::text || ' is on its way.',
      new.id,
      jsonb_build_object(
        'amount', coalesce(new.payout_amount, new.amount),
        'currency', coalesce(new.payout_currency, new.currency)));
  end if;
  return new;
end;
$$;

drop trigger if exists notify_payout_paid on nata.payouts;
create trigger notify_payout_paid
  after update of status on nata.payouts
  for each row execute function nata.notify_payout_paid();

-- -----------------------------------------------------------------------------
-- 5. Identity checks
-- -----------------------------------------------------------------------------
create or replace function nata.notify_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.verification_status is not distinct from old.verification_status then
    return new;
  end if;
  if new.verification_status = 'verified' then
    perform nata.notify(new.id, 'verification', 'identity_verified',
      'Identity verified',
      'You''re verified. You can now send and accept delivery requests.',
      null, '{}'::jsonb);
  elsif new.verification_status = 'rejected' then
    perform nata.notify(new.id, 'verification', 'identity_rejected',
      'Identity check failed',
      'We couldn''t verify your ID. Please try again with a clear photo.',
      null, '{}'::jsonb);
  end if;
  return new;
end;
$$;

drop trigger if exists notify_verification on nata.profiles;
create trigger notify_verification
  after update of verification_status on nata.profiles
  for each row execute function nata.notify_verification();
