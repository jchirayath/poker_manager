-- Fix profile update permissions by adding SECURITY DEFINER to the trigger function
-- This allows the function to access auth.users table during profile updates

CREATE OR REPLACE FUNCTION public.enforce_auth_user_for_non_local_profiles()
RETURNS trigger AS $$
BEGIN
  IF COALESCE(NEW.is_local_user, FALSE) = FALSE THEN
    IF NEW.id IS NULL THEN
      RAISE EXCEPTION 'profiles.id must be provided for non-local users';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = NEW.id) THEN
      RAISE EXCEPTION 'profiles.id must reference an existing auth.users.id for non-local users';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
