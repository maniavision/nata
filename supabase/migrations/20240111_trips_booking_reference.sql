-- Flight booking reference (PNR) on trips.
--
-- Your project already has this column and check (it was created in the
-- dashboard), so this is a no-op there. It exists so a fresh database built
-- from these migrations matches production. Safe to re-run.

alter table nata.trips
  add column if not exists booking_reference text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'trips_booking_reference_check'
      and conrelid = 'nata.trips'::regclass
  ) then
    alter table nata.trips
      add constraint trips_booking_reference_check
      check (booking_reference ~ '^[A-Z0-9]{5,8}$');
  end if;
end
$$;
