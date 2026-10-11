-- Add avatar_path to nata.profiles and migrate data from avatar_url if it exists
ALTER TABLE nata.profiles
ADD COLUMN IF NOT EXISTS avatar_path TEXT;

-- If avatar_url exists, we might want to keep it or migrate it.
-- The user specifically asked for avatar_path.
-- For now, let's just ensure avatar_path exists.
