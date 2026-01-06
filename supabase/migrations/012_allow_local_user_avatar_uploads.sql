-- =============================================
-- UPDATE STORAGE POLICIES FOR LOCAL USER AVATARS
-- =============================================

-- Drop existing policies for avatars bucket
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

-- Allow authenticated users to upload their own avatar OR upload for local users
CREATE POLICY "Users can upload avatars"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      -- Users uploading their own avatar
      auth.uid()::text = (storage.foldername(name))[1]
      OR
      -- Allow group creators/admins to upload avatars for local users in their groups
      EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = (storage.foldername(name))[1]::uuid
        AND p.is_local_user = true
      )
    )
  );

-- Allow users to update their own avatar or local user avatars
CREATE POLICY "Users can update avatars"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (
      -- Users updating their own avatar
      auth.uid()::text = (storage.foldername(name))[1]
      OR
      -- Allow updates for local user avatars
      EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = (storage.foldername(name))[1]::uuid
        AND p.is_local_user = true
      )
    )
  );

-- Allow users to delete their own avatar or local user avatars
CREATE POLICY "Users can delete avatars"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (
      -- Users deleting their own avatar
      auth.uid()::text = (storage.foldername(name))[1]
      OR
      -- Allow deletion of local user avatars
      EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = (storage.foldername(name))[1]::uuid
        AND p.is_local_user = true
      )
    )
  );
