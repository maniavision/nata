-- The recipient's link stops working once the item is delivered.
--
-- Run AFTER 20240184_three_delivery_photos.sql. Safe to re-run.
--
-- The link (20240181) used to work until a week after the delivery or the
-- cancellation, and its chat until a day after the delivery. Now both end
-- as soon as the request is delivered (or cancelled): the page then says
-- the link no longer works, and neither side can write. The traveler can
-- still read the conversation in the app.

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
     and r.status in ('paid', 'handed_off');
$$;
revoke all on function nata.recipient_request(text)
  from public, anon, authenticated;

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
       and r.status in ('paid', 'handed_off'));
$$;
revoke all on function nata.recipient_chat_open(uuid)
  from public, anon, authenticated;
