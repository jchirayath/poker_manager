-- Allow local profiles without requiring auth.users FK
-- Drop existing foreign key constraint on profiles.id referencing auth.users
ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- Enforce that non-local profiles must still correspond to auth.users
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_auth_user_for_non_local_profiles ON public.profiles;
CREATE TRIGGER trg_enforce_auth_user_for_non_local_profiles
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.enforce_auth_user_for_non_local_profiles();
