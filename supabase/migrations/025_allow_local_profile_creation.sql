-- =============================================
-- Allow Local User Profiles Without auth.users Entry
-- Fixes FK constraint violation when creating local users
-- =============================================

-- Step 1: Drop all foreign key constraints on profiles.id that reference auth.users
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
    WHERE tc.table_name = 'profiles'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_schema = 'auth'
      AND ccu.table_name = 'users'
  ) LOOP
    EXECUTE 'ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    RAISE NOTICE 'Dropped constraint: %', r.constraint_name;
  END LOOP;
END $$;

-- Step 2: Add a check constraint + trigger to enforce FK only for non-local users
-- This allows local users (is_local_user = TRUE) to have any UUID
-- while requiring real users to have a matching auth.users entry

CREATE OR REPLACE FUNCTION public.enforce_auth_user_for_profiles()
RETURNS TRIGGER AS $$
BEGIN
  -- Local users don't need an auth.users entry
  IF NEW.is_local_user = TRUE THEN
    RETURN NEW;
  END IF;

  -- Non-local users must have a corresponding auth.users entry
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.id) THEN
    RAISE EXCEPTION 'Non-local profiles must have a corresponding auth.users entry (id: %)', NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if it exists and recreate
DROP TRIGGER IF EXISTS enforce_auth_user_trigger ON public.profiles;
CREATE TRIGGER enforce_auth_user_trigger
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_auth_user_for_profiles();

-- Step 3: Add RLS policy for creating local user profiles
CREATE POLICY "Authenticated users can create local profiles"
  ON profiles FOR INSERT
  WITH CHECK (
    is_local_user = TRUE
  );

-- Step 4: Add RLS policy for updating local user profiles
CREATE POLICY "Authenticated users can update local profiles"
  ON profiles FOR UPDATE
  USING (
    is_local_user = TRUE
  )
  WITH CHECK (
    is_local_user = TRUE
  );
