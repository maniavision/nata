-- Reporting a problem with a delivery.
--
-- Run AFTER 20240142_notification_events.sql. Safe to re-run.
--
--   * nata.disputes: one report per person per request, with what went wrong
--     and their own words. Support reads them (service role); users only see
--     their own.
--   * public.report_problem(p_request_id, p_reason, p_details): the sender
--     reports within 3 days of delivery; the traveler can report from pickup
--     until 3 days after delivery. The other side is told a problem was
--     reported. It does not hold the traveler's payout, which the delivery
--     code has already released; support follows up from here.

create table if not exists nata.disputes (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null references nata.delivery_requests (id) on delete cascade,
  reporter_id  uuid not null references nata.profiles (id) on delete cascade,
  reason       text not null
                 check (reason in ('not_received', 'damaged', 'wrong_item',
                                   'opened', 'other')),
  details      text not null default '' check (char_length(details) <= 1000),
  status       text not null default 'open'
                 check (status in ('open', 'resolved')),
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz,
  unique (request_id, reporter_id)
);

alter table nata.disputes enable row level security;

drop policy if exists "Reporters read their disputes" on nata.disputes;
create policy "Reporters read their disputes"
  on nata.disputes for select
  to authenticated
  using (reporter_id = auth.uid());

revoke insert, update, delete on nata.disputes from anon, authenticated;
grant select on nata.disputes to authenticated;

drop function if exists public.report_problem(uuid, text, text);
create function public.report_problem(
  p_request_id  uuid,
  p_reason      text,
  p_details     text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid       uuid := auth.uid();
  req       record;
  traveler  uuid;
  new_id    uuid;
  other     uuid;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  select r.id, r.status, r.sender_id, r.delivered_at, t.traveler_id
    into req
    from nata.delivery_requests r
    join nata.trips t on t.id = r.trip_id
   where r.id = p_request_id;
  if not found or uid not in (req.sender_id, req.traveler_id) then
    raise exception 'nata:request_not_found';
  end if;
  traveler := req.traveler_id;

  -- The sender, once the traveler says it is delivered; the traveler, from
  -- pickup. Either way, no later than 3 days after delivery.
  if (uid = req.sender_id and req.status <> 'delivered')
     or (uid = traveler and req.status not in ('handed_off', 'delivered')) then
    raise exception 'nata:not_reportable';
  end if;
  if req.status = 'delivered'
     and req.delivered_at is not null
     and req.delivered_at < now() - interval '3 days' then
    raise exception 'nata:report_window_closed';
  end if;

  if exists (select 1 from nata.disputes d
              where d.request_id = p_request_id and d.reporter_id = uid) then
    raise exception 'nata:already_reported';
  end if;

  insert into nata.disputes (request_id, reporter_id, reason, details)
  values (p_request_id, uid, p_reason,
          left(trim(coalesce(p_details, '')), 1000))
  returning id into new_id;

  other := case when uid = req.sender_id then traveler else req.sender_id end;
  perform nata.notify(other, 'request', 'problem_reported',
    'Problem reported',
    'A problem was reported on one of your deliveries. Our support team will contact you.',
    p_request_id, jsonb_build_object('request_id', p_request_id));

  return new_id;
end;
$$;

revoke all on function public.report_problem(uuid, text, text) from public, anon;
grant execute on function public.report_problem(uuid, text, text) to authenticated;
