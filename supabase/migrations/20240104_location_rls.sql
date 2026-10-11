-- ============================================================
-- Public read access for nata.countries and nata.cities
-- Run in Supabase SQL Editor
-- ============================================================

-- Countries: already has "public read countries" policy from before.
-- Add it if missing:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'nata' AND tablename = 'countries'
    AND policyname = 'public read countries'
  ) THEN
    CREATE POLICY "public read countries"
      ON nata.countries FOR SELECT USING (true);
  END IF;
END $$;

-- Cities: allow anyone to read (it's a reference table)
ALTER TABLE nata.cities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public read cities" ON nata.cities;
CREATE POLICY "public read cities"
  ON nata.cities FOR SELECT USING (true);
