-- Storage RLS Policies for Nata App

-- Ensure the 'user-assets' bucket exists and is public
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-assets', 'user-assets', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Policies for 'user-assets' bucket

-- 1. Allow public to read avatars (Public Access)
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'user-assets');

-- 2. Allow authenticated users to upload to their own avatar folder
-- Path convention: avatars/{user_id}/avatar_{user_id}.extension
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'user-assets' AND
    (storage.foldername(name))[1] = 'avatars' AND
    (storage.foldername(name))[2] = auth.uid()::text
  );

-- 3. Allow users to update their own avatar
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'user-assets' AND
    (storage.foldername(name))[1] = 'avatars' AND
    (storage.foldername(name))[2] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'user-assets' AND
    (storage.foldername(name))[1] = 'avatars' AND
    (storage.foldername(name))[2] = auth.uid()::text
  );

-- 4. Allow users to delete their own avatar
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
CREATE POLICY "Users can delete their own avatar"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'user-assets' AND
    (storage.foldername(name))[1] = 'avatars' AND
    (storage.foldername(name))[2] = auth.uid()::text
  );
