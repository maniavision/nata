-- The chat closes once the item is delivered.
--
-- Run AFTER 20240163_trips_live_and_ticket_access.sql. Safe to re-run.
--
-- Chat opened at payment (20240130) and stayed open after delivery. Now
-- nata.chat_unlocked() is true only while the delivery is under way (paid or
-- handed off), so once the request is delivered (or cancelled) neither
-- member can send a message or upload a chat photo. What was said stays
-- readable: reading needs membership only. The app shows the same rule: a
-- delivered request's chat has no input, only a note that it is closed.

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
       and r.status in ('paid', 'handed_off')
  );
end;
$$;

revoke all on function nata.chat_unlocked(text) from public;
grant execute on function nata.chat_unlocked(text) to authenticated;
