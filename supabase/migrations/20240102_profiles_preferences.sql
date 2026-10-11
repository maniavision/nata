-- Run in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/xnzredskhxfgywggetzw/sql

-- Add language and currency preference columns to nata.profiles
ALTER TABLE nata.profiles
  ADD COLUMN IF NOT EXISTS language     text NOT NULL DEFAULT 'en'
    CHECK (language IN ('en', 'es', 'fr')),
  ADD COLUMN IF NOT EXISTS currency     char(3) NOT NULL DEFAULT 'USD'
    CHECK (currency IN ('USD', 'EUR', 'GBP', 'XOF')),
  ADD COLUMN IF NOT EXISTS country_of_residence char(2)
    REFERENCES nata.countries (iso_code) ON UPDATE CASCADE ON DELETE SET NULL;

-- RLS: users can read and update their own profile preferences
CREATE POLICY IF NOT EXISTS "users can read own profile"
  ON nata.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY IF NOT EXISTS "users can update own profile"
  ON nata.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Also allow public read on nata.countries (if not already done)
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
