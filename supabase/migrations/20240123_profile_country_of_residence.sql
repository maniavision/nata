-- The user's country of residence, saved at sign-up from the country they
-- picked for their phone number. The home screen starts the "sending from"
-- search on that country's capital (nata.cities.is_capital).
--
-- 20240102_profiles_preferences.sql declared this column too; this makes
-- sure it exists wherever that migration was not run.
--
-- Safe to re-run.

alter table nata.profiles
  add column if not exists country_of_residence char(2)
    references nata.countries (iso_code) on update cascade on delete set null;
