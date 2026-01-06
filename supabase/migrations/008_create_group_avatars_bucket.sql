-- =============================================
-- GROUP AVATARS STORAGE BUCKET
-- =============================================

-- Create group-avatars bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('group-avatars', 'group-avatars', true)
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- STORAGE POLICIES FOR GROUP AVATARS
-- =============================================

-- Allow anyone to view group avatars (public bucket)
CREATE POLICY "Group avatar images are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'group-avatars');

-- Allow authenticated users to upload group avatars
CREATE POLICY "Authenticated users can upload group avatars"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'group-avatars'
    AND auth.role() = 'authenticated'
  );

-- Allow authenticated users to update group avatars
CREATE POLICY "Authenticated users can update group avatars"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'group-avatars'
    AND auth.role() = 'authenticated'
  );

-- Allow authenticated users to delete group avatars
CREATE POLICY "Authenticated users can delete group avatars"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'group-avatars'
    AND auth.role() = 'authenticated'
  );
