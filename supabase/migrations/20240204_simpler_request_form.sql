-- A simpler delivery request form.
--
-- Run AFTER 20240203_flat_fee_rates.sql. Safe to re-run.
--
-- The form no longer asks for each item's estimated value, a receipt, the
-- package's dimensions or its size (envelope, shoebox, backpack). Values,
-- receipts and dimensions were already optional here; the size class was
-- required. Now send_delivery_request and update_delivery_request accept no
-- size class (null): a parcel with no size isn't checked against the trip's
-- size limit. A size that is given is still checked, for older app builds.
-- Requests already sent keep what they have.

CREATE OR REPLACE FUNCTION public.send_delivery_request(p_id uuid, p_trip_ids uuid[], p_items jsonb, p_item_weight_kg numeric, p_item_size text, p_item_size_class text, p_photo_paths text[])
 RETURNS TABLE(request_id uuid, trip_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare
  uid         uuid := auth.uid();
  trip        record;
  it          record;
  path        text;
  rid         uuid;
  n_trips     integer;
  dest        integer;
  fee         record;
  trip_class  text;
  item_count  integer;
  summary_name  text;
  summary_cat   text;
  summary_notes text;
  cur           text;
  declared      numeric;
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Already sent by an earlier attempt of the same request: nothing to do.
  if exists (select 1 from nata.delivery_requests r
              where r.group_id = p_id and r.sender_id = uid) then
    return query
      select r.id, r.trip_id from nata.delivery_requests r
       where r.group_id = p_id and r.sender_id = uid
       order by r.created_at, r.id;
    return;
  end if;

  -- 1 to 5 different travelers' trips.
  n_trips := coalesce(cardinality(p_trip_ids), 0);
  if n_trips = 0 then
    raise exception 'nata:trip_unavailable';
  end if;
  if n_trips > 5 then
    raise exception 'nata:too_many_travelers';
  end if;
  if (select count(distinct x) from unnest(p_trip_ids) x) <> n_trips then
    raise exception 'nata:duplicate';
  end if;

  -- Items: 1 to 5, each with a name and a known category.
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'nata:item_required';
  end if;
  item_count := jsonb_array_length(p_items);
  if item_count > 5 then
    raise exception 'nata:too_many_items';
  end if;
  for it in
    select e.item, e.n from jsonb_array_elements(p_items) with ordinality as e(item, n)
  loop
    if jsonb_typeof(it.item) <> 'object'
       or coalesce(btrim(it.item ->> 'name'), '') = ''
       or char_length(btrim(it.item ->> 'name')) > 80
       or char_length(coalesce(it.item ->> 'description', '')) > 300 then
      raise exception 'nata:item_required';
    end if;
    if coalesce(it.item ->> 'category', '') not in ('electronics', 'apparel', 'documents') then
      raise exception 'nata:item_category_invalid';
    end if;
    if it.item ? 'value' and (
         jsonb_typeof(it.item -> 'value') <> 'number'
         or (it.item ->> 'value')::numeric < 0
         or (it.item ->> 'value')::numeric > 1000000) then
      raise exception 'nata:item_value_invalid';
    end if;
    if coalesce(it.item ->> 'receipt_path', '') <> ''
       and (it.item ->> 'receipt_path') not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  if p_item_weight_kg is null or p_item_weight_kg <= 0 then
    raise exception 'nata:weight_invalid';
  end if;
  -- The size is optional now (20240204); older app builds still send one.
  if p_item_size_class is not null
     and p_item_size_class not in ('envelope', 'shoebox', 'backpack') then
    raise exception 'nata:size_required';
  end if;
  if coalesce(array_length(p_photo_paths, 1), 0) = 0 then
    raise exception 'nata:photo_required';
  end if;
  foreach path in array p_photo_paths loop
    -- A photo must be in the sender's own folder for this request.
    if path not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  -- Every trip: live, someone else's, going to the same city, and able to
  -- take the parcel.
  for trip in
    select t.id, t.traveler_id, t.status, t.departure_date, t.max_weight_kg,
           t.max_size, t.arrival_city_id
      from unnest(p_trip_ids) as x(id)
      left join nata.trips t on t.id = x.id
  loop
    if trip.id is null or trip.status <> 'live' or trip.departure_date < current_date then
      raise exception 'nata:trip_unavailable';
    end if;
    if trip.traveler_id = uid then
      raise exception 'nata:own_trip';
    end if;
    if dest is null then
      dest := trip.arrival_city_id;
    elsif dest <> trip.arrival_city_id then
      raise exception 'nata:different_destinations';
    end if;
    if trip.max_weight_kg is not null and p_item_weight_kg > trip.max_weight_kg then
      raise exception 'nata:weight_too_heavy';
    end if;
    trip_class := nata.trip_size_class(trip.max_size);
    if trip_class is not null and p_item_size_class is not null
       and nata.size_class_rank(p_item_size_class) > nata.size_class_rank(trip_class) then
      raise exception 'nata:size_too_big';
    end if;
    if exists (
      select 1 from nata.delivery_requests r
       where r.trip_id = trip.id
         and r.sender_id = uid
         and r.status in ('pending', 'accepted', 'paid', 'handed_off')
    ) then
      raise exception 'nata:duplicate';
    end if;
  end loop;

  -- At most 5 open requests per sender going to the same city; a request
  -- sent to several travelers counts once. The lock makes two sends at the
  -- same moment wait for each other.
  perform pg_advisory_xact_lock(
    hashtextextended('nata:destination:' || uid::text || ':' || dest::text, 0));
  if (
    select count(distinct coalesce(r.group_id, r.id)) from nata.delivery_requests r
      join nata.trips t on t.id = r.trip_id
     where r.sender_id = uid
       and t.arrival_city_id = dest
       and r.status in ('pending', 'accepted', 'paid', 'handed_off')
  ) >= 5 then
    raise exception 'nata:destination_limit';
  end if;

  -- The summary kept on each request.
  select left(string_agg(btrim(e.item ->> 'name'), ', ' order by e.n), 120),
         min(e.item ->> 'category') filter (where e.n = 1),
         coalesce(string_agg(nullif(btrim(e.item ->> 'description'), ''), E'\n' order by e.n), '')
    into summary_name, summary_cat, summary_notes
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  select upper(btrim(s.currency_code)) into cur
    from nata.user_settings s where s.user_id = uid;
  if cur is null or cur !~ '^[A-Z]{3}$' then
    cur := 'USD';
  end if;
  select sum(round((e.item ->> 'value')::numeric, 2))
    into declared
    from jsonb_array_elements(p_items) as e(item)
   where e.item ? 'value';

  for trip in
    select x.id, x.n from unnest(p_trip_ids) with ordinality as x(id, n) order by x.n
  loop
    rid := case when trip.n = 1 then p_id else gen_random_uuid() end;
    select f.amount, f.currency into fee from nata.flat_fee(uid, trip.id) f;

    begin
      insert into nata.delivery_requests (
        id, trip_id, sender_id, group_id, pricing,
        item_name, item_category, item_description,
        item_weight_kg, item_size, item_size_class,
        traveler_price, platform_fee, total_amount, currency,
        display_currency, declared_value, declared_currency,
        expires_at, status
      ) values (
        rid, trip.id, uid, p_id, 'flat',
        summary_name, summary_cat, left(summary_notes, 300),
        p_item_weight_kg, nullif(btrim(coalesce(p_item_size, '')), ''), p_item_size_class,
        0, fee.amount, fee.amount, fee.currency,
        cur, declared, case when declared is not null then cur end,
        now() + nata.request_response_window(), 'pending'
      );
    exception when unique_violation then
      raise exception 'nata:duplicate';
    end;

    insert into nata.request_items (request_id, position, name, category, description,
                                    value, value_currency, receipt_path)
    select rid, e.n::smallint,
           btrim(e.item ->> 'name'),
           e.item ->> 'category',
           coalesce(btrim(e.item ->> 'description'), ''),
           case when e.item ? 'value' then round((e.item ->> 'value')::numeric, 2) end,
           case when e.item ? 'value' then cur end,
           nullif(btrim(coalesce(e.item ->> 'receipt_path', '')), '')
      from jsonb_array_elements(p_items) with ordinality as e(item, n);

    -- The same photos for every traveler, in the group's folder.
    insert into nata.request_photos (request_id, uploaded_by, photo_path, type)
    select rid, uid, ph, 'item' from unnest(p_photo_paths) as ph;

    request_id := rid;
    trip_id := trip.id;
    return next;
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_delivery_request(p_id uuid, p_items jsonb, p_item_weight_kg numeric, p_item_size text, p_item_size_class text, p_recipient_name text, p_recipient_phone text, p_photo_paths text[] DEFAULT NULL::text[], p_expected_total numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid         uuid := auth.uid();
  req         record;
  trip        record;
  it          record;
  path        text;
  cost        numeric(10, 2);
  fee         numeric(10, 2);
  total       numeric(10, 2);
  trip_class  text;
  item_count  integer;
  summary_name  text;
  summary_cat   text;
  summary_notes text;
  cur           text;
  declared      numeric;
  old_receipts  text[];
begin
  if uid is null then
    raise exception 'nata:not_signed_in';
  end if;

  -- Lock the request so two edits (or an edit and the traveler's answer)
  -- cannot interleave.
  select r.id, r.sender_id, r.status, r.trip_id, r.pricing, r.traveler_price,
         r.platform_fee, r.total_amount
    into req
    from nata.delivery_requests r
   where r.id = p_id
     for update;

  if not found or req.sender_id <> uid then
    raise exception 'nata:request_not_found';
  end if;
  if req.status <> 'pending' then
    raise exception 'nata:request_not_editable';
  end if;

  select t.id, t.status, t.departure_date, t.max_weight_kg, t.max_size,
         dc.latitude  as dep_lat, dc.longitude as dep_lon,
         ac.latitude  as arr_lat, ac.longitude as arr_lon
    into trip
    from nata.trips t
    join nata.cities dc on dc.id = t.departure_city_id
    join nata.cities ac on ac.id = t.arrival_city_id
   where t.id = req.trip_id;

  if not found or trip.status <> 'live' or trip.departure_date < current_date then
    raise exception 'nata:trip_unavailable';
  end if;

  -- The same checks as create_delivery_request.
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'nata:item_required';
  end if;
  item_count := jsonb_array_length(p_items);
  if item_count > 5 then
    raise exception 'nata:too_many_items';
  end if;
  for it in
    select e.item, e.n from jsonb_array_elements(p_items) with ordinality as e(item, n)
  loop
    if jsonb_typeof(it.item) <> 'object'
       or coalesce(btrim(it.item ->> 'name'), '') = ''
       or char_length(btrim(it.item ->> 'name')) > 80
       or char_length(coalesce(it.item ->> 'description', '')) > 300 then
      raise exception 'nata:item_required';
    end if;
    if coalesce(it.item ->> 'category', '') not in ('electronics', 'apparel', 'documents') then
      raise exception 'nata:item_category_invalid';
    end if;
    -- The item's estimated value and receipt (20240194), as at creation.
    if it.item ? 'value' and (
         jsonb_typeof(it.item -> 'value') <> 'number'
         or (it.item ->> 'value')::numeric < 0
         or (it.item ->> 'value')::numeric > 1000000) then
      raise exception 'nata:item_value_invalid';
    end if;
    if coalesce(it.item ->> 'receipt_path', '') <> ''
       and (it.item ->> 'receipt_path') not like uid::text || '/' || p_id::text || '/%' then
      raise exception 'nata:photo_invalid';
    end if;
  end loop;

  -- Flat requests have no recipient (20240200).
  if req.pricing <> 'flat' then
    if coalesce(btrim(p_recipient_name), '') = '' then
      raise exception 'nata:recipient_required';
    end if;
    if p_recipient_phone is null or p_recipient_phone !~ '^\+[1-9][0-9]{7,14}$' then
      raise exception 'nata:phone_invalid';
    end if;
  end if;
  if p_item_weight_kg is null or p_item_weight_kg <= 0 then
    raise exception 'nata:weight_invalid';
  end if;
  if trip.max_weight_kg is not null and p_item_weight_kg > trip.max_weight_kg then
    raise exception 'nata:weight_too_heavy';
  end if;

  -- The size is optional now (20240204); older app builds still send one.
  if p_item_size_class is not null
     and p_item_size_class not in ('envelope', 'shoebox', 'backpack') then
    raise exception 'nata:size_required';
  end if;
  trip_class := nata.trip_size_class(trip.max_size);
  if trip_class is not null and p_item_size_class is not null
     and nata.size_class_rank(p_item_size_class) > nata.size_class_rank(trip_class) then
    raise exception 'nata:size_too_big';
  end if;

  if p_photo_paths is not null then
    if coalesce(array_length(p_photo_paths, 1), 0) = 0 then
      raise exception 'nata:photo_required';
    end if;
    foreach path in array p_photo_paths loop
      if path not like uid::text || '/' || p_id::text || '/%' then
        raise exception 'nata:photo_invalid';
      end if;
    end loop;
  end if;

  -- Priced again, as at creation: the weight or the days to departure may
  -- have changed since.
  if req.pricing = 'flat' then
    -- The fee doesn't change.
    cost  := req.traveler_price;
    fee   := req.platform_fee;
    total := req.total_amount;
  else
  cost  := nata.delivery_cost_usd(
             nata.haversine_km(trip.dep_lat::double precision, trip.dep_lon::double precision,
                               trip.arr_lat::double precision, trip.arr_lon::double precision),
             nata.hours_until_departure(trip.departure_date),
             p_item_weight_kg);
  fee   := nata.platform_fee_for(cost);
  total := cost + fee;
  if p_expected_total is not null and abs(p_expected_total - total) > 0.05 then
    raise exception 'nata:price_changed';
  end if;
  end if;

  select left(string_agg(btrim(e.item ->> 'name'), ', ' order by e.n), 120),
         min(e.item ->> 'category') filter (where e.n = 1),
         coalesce(string_agg(nullif(btrim(e.item ->> 'description'), ''), E'\n' order by e.n), '')
    into summary_name, summary_cat, summary_notes
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  -- Values stay in the request's currency; the declared value is their total.
  select coalesce(r.display_currency::text, 'USD') into cur
    from nata.delivery_requests r where r.id = p_id;
  select sum(round((e.item ->> 'value')::numeric, 2))
    into declared
    from jsonb_array_elements(p_items) as e(item)
   where e.item ? 'value';

  update nata.delivery_requests
     set item_name        = summary_name,
         item_category    = summary_cat,
         item_description = left(summary_notes, 300),
         item_weight_kg   = p_item_weight_kg,
         item_size        = nullif(btrim(coalesce(p_item_size, '')), ''),
         item_size_class  = p_item_size_class,
         traveler_price   = cost,
         platform_fee     = fee,
         total_amount     = total,
         declared_value   = declared,
         declared_currency = case when declared is not null then cur end,
         updated_at       = now()
   where id = p_id;

  -- A receipt stays with the item in its place unless a new one is sent.
  select array_agg(i.receipt_path order by i.position)
    into old_receipts
    from nata.request_items i where i.request_id = p_id;
  delete from nata.request_items where request_id = p_id;
  insert into nata.request_items (request_id, position, name, category, description,
                                  value, value_currency, receipt_path)
  select p_id, e.n::smallint,
         btrim(e.item ->> 'name'),
         e.item ->> 'category',
         coalesce(btrim(e.item ->> 'description'), ''),
         case when e.item ? 'value' then round((e.item ->> 'value')::numeric, 2) end,
         case when e.item ? 'value' then cur end,
         coalesce(nullif(btrim(coalesce(e.item ->> 'receipt_path', '')), ''),
                  old_receipts[e.n::integer])
    from jsonb_array_elements(p_items) with ordinality as e(item, n);

  -- (request_recipients comes from the additions script; no unique key on
  -- request_id is assumed.)
  if req.pricing <> 'flat' then
    update nata.request_recipients
       set name = btrim(p_recipient_name), phone = p_recipient_phone
     where request_id = p_id;
    if not found then
      insert into nata.request_recipients (request_id, name, phone)
      values (p_id, btrim(p_recipient_name), p_recipient_phone);
    end if;
  end if;

  if p_photo_paths is not null then
    delete from nata.request_photos where request_id = p_id and type = 'item';
    foreach path in array p_photo_paths loop
      insert into nata.request_photos (request_id, uploaded_by, photo_path, type)
      values (p_id, uid, path, 'item');
    end loop;
  end if;

  return p_id;
end;
$function$;
