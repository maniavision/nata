-- In-app notifications (the page opened by the bell on Home).
--
-- Run in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql
--
-- This table is a PROPOSAL made when no notifications schema existed. If you
-- already have one, tell me and the app's NotificationService will be adapted
-- instead. Safe to re-run.
--
-- Rows are created by the backend (a database trigger, an edge function or the
-- service role), never by the app itself, so there is no INSERT policy. A
-- signed-in user can read their own notifications and mark them read.

create table if not exists nata.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references nata.profiles (id) on delete cascade,
  -- Drives the icon and the Requests / Trips / Payments filters.
  type        text not null default 'system'
              check (type in ('request', 'trip', 'payment', 'message',
                              'verification', 'system')),
  title       text not null,
  body        text not null default '',
  -- Optional picture (e.g. the sender's avatar for a message).
  image_url   text null,
  -- Optional pointer to the trip / request / payment this is about.
  related_id  uuid null,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on nata.notifications (user_id, created_at desc);

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

-- A user may flip is_read but must not be able to rewrite the message itself.
revoke update on nata.notifications from authenticated;
grant select on nata.notifications to authenticated;
grant update (is_read) on nata.notifications to authenticated;
