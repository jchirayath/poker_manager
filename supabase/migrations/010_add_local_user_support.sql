-- =============================================
-- ADD LOCAL USER SUPPORT TO PROFILES
-- Allow creating local users without authentication
-- =============================================

-- Add is_local_user flag to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_local_user BOOLEAN DEFAULT FALSE;

-- Add index for efficient queries
CREATE INDEX IF NOT EXISTS idx_profiles_is_local_user ON public.profiles(is_local_user);

-- Make email optional for local users (update constraint)
ALTER TABLE public.profiles
ALTER COLUMN email DROP NOT NULL;

-- Add a check constraint to ensure local users have at least first_name
ALTER TABLE public.profiles
ADD CONSTRAINT local_users_must_have_name CHECK (
  (is_local_user = FALSE AND email IS NOT NULL) OR
  (is_local_user = TRUE AND first_name IS NOT NULL AND first_name != '')
);

-- Update RLS policies to allow inserting local users
-- Local users can be created by authenticated users for their groups
CREATE POLICY "Authenticated users can create local users"
  ON public.profiles FOR INSERT
  WITH CHECK (
    is_local_user = TRUE AND
    auth.role() = 'authenticated'
  );

-- Allow viewing local users
CREATE POLICY "Users can view local users in their groups"
  ON public.profiles FOR SELECT
  USING (
    is_local_user = TRUE OR
    id = auth.uid()
  );

-- Allow updating local users by group admins
CREATE POLICY "Group admins can update local users"
  ON public.profiles FOR UPDATE
  USING (
    is_local_user = TRUE AND
    EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.user_id = auth.uid()
        AND gm.role = 'admin'
        AND EXISTS (
          SELECT 1 FROM public.group_members gm2
          WHERE gm2.user_id = profiles.id
            AND gm2.group_id = gm.group_id
        )
    )
  );
