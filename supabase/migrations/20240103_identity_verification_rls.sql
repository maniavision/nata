-- ============================================================
-- RLS for nata.identity_verifications
-- Run in Supabase SQL Editor
-- ============================================================

ALTER TABLE nata.identity_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users can insert own verification" ON nata.identity_verifications;
DROP POLICY IF EXISTS "users can read own verification" ON nata.identity_verifications;

-- Users can submit their own verification
CREATE POLICY "users can insert own verification"
  ON nata.identity_verifications FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own verification (needed for upsert)
CREATE POLICY "users can update own verification"
  ON nata.identity_verifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can read their own verification status
CREATE POLICY "users can read own verification"
  ON nata.identity_verifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Only service role can update (for admin/webhook review)
-- No UPDATE policy for authenticated role

-- ============================================================
-- Private storage bucket for identity documents
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'identity-documents',
  'identity-documents',
  false,
  52428800, -- 50 MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Users can upload to their own folder: {user_id}/{filename}
DROP POLICY IF EXISTS "users_upload_own_documents" ON storage.objects;
CREATE POLICY "users_upload_own_documents"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'identity-documents'
    AND name LIKE (auth.uid()::text || '/%')
  );

-- Users can read their own documents
DROP POLICY IF EXISTS "users_read_own_documents" ON storage.objects;
CREATE POLICY "users_read_own_documents"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'identity-documents'
    AND name LIKE (auth.uid()::text || '/%')
  );

-- Users can replace (upsert) their own documents
DROP POLICY IF EXISTS "users_update_own_documents" ON storage.objects;
CREATE POLICY "users_update_own_documents"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'identity-documents'
    AND name LIKE (auth.uid()::text || '/%')
  )
  WITH CHECK (
    bucket_id = 'identity-documents'
    AND name LIKE (auth.uid()::text || '/%')
  );

-- Users can delete their own documents
DROP POLICY IF EXISTS "users_delete_own_documents" ON storage.objects;
CREATE POLICY "users_delete_own_documents"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'identity-documents'
    AND name LIKE (auth.uid()::text || '/%')
  );

-- Also ensure users can see the bucket itself
DROP POLICY IF EXISTS "users_view_buckets" ON storage.buckets;
CREATE POLICY "users_view_buckets"
  ON storage.buckets FOR SELECT
  TO authenticated
  USING (id = 'identity-documents');
