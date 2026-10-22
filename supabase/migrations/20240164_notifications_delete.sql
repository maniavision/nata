-- Members delete their notifications; read ones go by themselves after 24h.
--
-- Run AFTER 20240163_trips_live_and_ticket_access.sql. Safe to re-run.
--
--   * A member can delete their own notifications (swipe left in the app);
--     authenticated gets the DELETE privilege it never had on this table.
--   * Every hour, notifications read more than 24 hours ago are deleted.
--     Unread ones stay until they are read (or deleted).

grant delete on nata.notifications to authenticated;

drop policy if exists "Users can delete their own notifications"
  on nata.notifications;
create policy "Users can delete their own notifications"
  on nata.notifications for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function nata.delete_read_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with gone as (
    delete from nata.notifications
     where is_read
       and coalesce(read_at, updated_at) < now() - interval '24 hours'
    returning 1
  )
  select count(*) into n from gone;
  return n;
end;
$$;

revoke all on function nata.delete_read_notifications() from public, anon, authenticated;

select cron.schedule(
  'delete-read-notifications', '23 * * * *',
  $job$ select nata.delete_read_notifications(); $job$
);
