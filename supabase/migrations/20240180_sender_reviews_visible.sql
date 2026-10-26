-- Travelers see what other travelers said about a sender.
--
-- Run AFTER 20240179_sender_reviews.sql. Safe to re-run.
--
-- A traveler opening a delivery request sees the sender's reviews as a
-- sender (20240179), newest first. Only travelers the sender has sent a
-- request to, and the sender themself, can read them.
--
--   * public.list_sender_reviews(p_sender_id, p_limit): the reviews, with the
--     total count; the same columns as public.list_traveler_reviews.

drop function if exists public.list_sender_reviews(uuid, integer);

create or replace function public.list_sender_reviews(
  p_sender_id  uuid,
  p_limit      integer default 10
)
returns table (
  review_id          uuid,
  rating             integer,
  tags               text[],
  comment            text,
  created_at         timestamptz,
  reviewer_first     text,
  reviewer_initial   text,
  total              integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.id,
         v.rating::integer,
         v.tags,
         v.comment,
         v.created_at,
         p.first_name,
         left(coalesce(p.last_name, ''), 1),
         (count(*) over ())::integer
    from nata.reviews v
    join nata.profiles p on p.id = v.reviewer_id
   where v.reviewee_id = p_sender_id
     and v.reviewee_role = 'sender'
     and auth.uid() is not null
     and (auth.uid() = p_sender_id
          or exists (select 1
                       from nata.delivery_requests r
                       join nata.trips t on t.id = r.trip_id
                      where r.sender_id = p_sender_id
                        and t.traveler_id = auth.uid()))
   order by v.created_at desc
   limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.list_sender_reviews(uuid, integer) from public;
grant execute on function public.list_sender_reviews(uuid, integer) to authenticated;
