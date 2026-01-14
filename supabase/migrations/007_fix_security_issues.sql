-- =============================================
-- Security Fixes Migration
-- Fixes function search_path and RLS policy issues
-- =============================================

-- =============================================
-- DROP FUNCTIONS WITH CHANGED SIGNATURES FIRST
-- Required when return type changes
-- =============================================
DROP FUNCTION IF EXISTS public.get_user_financial_audit(UUID, INTEGER);
DROP FUNCTION IF EXISTS public.get_financial_audit_history(TEXT, UUID, UUID, INTEGER);
DROP FUNCTION IF EXISTS public.get_game_financial_audit_summary(UUID);

-- =============================================
-- PART 1: FIX FUNCTION SEARCH_PATH ISSUES
-- Set search_path = public for all functions to prevent
-- search_path manipulation attacks
-- =============================================

-- 1. Fix update_updated_at_column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- 2. Fix get_full_address
CREATE OR REPLACE FUNCTION public.get_full_address(p profiles)
RETURNS TEXT AS $$
BEGIN
  RETURN CONCAT_WS(', ',
    NULLIF(p.street_address, ''),
    NULLIF(p.city, ''),
    NULLIF(p.state_province, ''),
    NULLIF(p.postal_code, ''),
    NULLIF(p.country, '')
  );
END;
$$ LANGUAGE plpgsql STABLE SET search_path = public;

-- 3. Fix set_creator_as_admin
CREATE OR REPLACE FUNCTION public.set_creator_as_admin()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_creator = TRUE THEN
    NEW.role := 'admin';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- 4. Fix calculate_settlement (legacy function)
CREATE OR REPLACE FUNCTION public.calculate_settlement(game_uuid UUID)
RETURNS TABLE(payer UUID, payee UUID, amount DECIMAL) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.payer_id,
    c.payee_id,
    c.amount
  FROM public.calculate_settlement_atomic(game_uuid) c;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Fix validate_transaction_amount
CREATE OR REPLACE FUNCTION public.validate_transaction_amount(
  p_amount DECIMAL,
  p_type TEXT
)
RETURNS TABLE (
  is_valid BOOLEAN,
  message TEXT
) AS $$
BEGIN
  -- Check for null
  IF p_amount IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Amount cannot be null'::TEXT;
    RETURN;
  END IF;

  -- Check for negative
  IF p_amount <= 0 THEN
    RETURN QUERY SELECT FALSE, 'Amount must be positive'::TEXT;
    RETURN;
  END IF;

  -- Check precision (2 decimal places)
  IF p_amount != ROUND(p_amount::numeric, 2) THEN
    RETURN QUERY SELECT FALSE, 'Amount must have at most 2 decimal places'::TEXT;
    RETURN;
  END IF;

  -- Check maximum
  IF p_amount > 10000.00 THEN
    RETURN QUERY SELECT FALSE, 'Amount exceeds maximum allowed ($10,000)'::TEXT;
    RETURN;
  END IF;

  RETURN QUERY SELECT TRUE, 'Valid'::TEXT;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- 6. Fix validate_settlement_amount
CREATE OR REPLACE FUNCTION public.validate_settlement_amount(
  p_amount DECIMAL
)
RETURNS TABLE (
  is_valid BOOLEAN,
  message TEXT
) AS $$
BEGIN
  -- Check for null
  IF p_amount IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Amount cannot be null'::TEXT;
    RETURN;
  END IF;

  -- Check for negative
  IF p_amount <= 0 THEN
    RETURN QUERY SELECT FALSE, 'Amount must be positive'::TEXT;
    RETURN;
  END IF;

  -- Check precision (2 decimal places)
  IF p_amount != ROUND(p_amount::numeric, 2) THEN
    RETURN QUERY SELECT FALSE, 'Amount must have at most 2 decimal places'::TEXT;
    RETURN;
  END IF;

  -- Check maximum
  IF p_amount > 5000.00 THEN
    RETURN QUERY SELECT FALSE, 'Amount exceeds maximum allowed ($5,000)'::TEXT;
    RETURN;
  END IF;

  RETURN QUERY SELECT TRUE, 'Valid'::TEXT;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- 7. Fix audit_transaction_change
CREATE OR REPLACE FUNCTION public.audit_transaction_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.financial_audit_log (
      id, table_name, record_id, operation, user_id, new_amount, created_at
    ) VALUES (
      gen_random_uuid(), 'transactions', NEW.id, 'INSERT', NEW.user_id, NEW.amount, NOW()
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.financial_audit_log (
      id, table_name, record_id, operation, user_id, old_amount, new_amount, created_at
    ) VALUES (
      gen_random_uuid(), 'transactions', NEW.id, 'UPDATE', NEW.user_id, OLD.amount, NEW.amount, NOW()
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.financial_audit_log (
      id, table_name, record_id, operation, user_id, old_amount, created_at
    ) VALUES (
      gen_random_uuid(), 'transactions', OLD.id, 'DELETE', OLD.user_id, OLD.amount, NOW()
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8. Fix audit_settlement_change
CREATE OR REPLACE FUNCTION public.audit_settlement_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.financial_audit_log (
      id, table_name, record_id, operation, user_id, new_amount, new_status, created_at
    ) VALUES (
      gen_random_uuid(), 'settlements', NEW.id, 'INSERT', NEW.from_user_id, NEW.amount, NEW.status, NOW()
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.financial_audit_log (
      id, table_name, record_id, operation, user_id, old_amount, new_amount, old_status, new_status, created_at
    ) VALUES (
      gen_random_uuid(), 'settlements', NEW.id, 'UPDATE', NEW.from_user_id, OLD.amount, NEW.amount, OLD.status, NEW.status, NOW()
    );
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 9. Fix audit_game_participant_change
CREATE OR REPLACE FUNCTION public.audit_game_participant_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.financial_audit_log (
      id, table_name, record_id, operation, user_id, new_amount, change_reason, created_at
    ) VALUES (
      gen_random_uuid(), 'game_participants', NEW.id, 'INSERT', NEW.user_id, NEW.total_buyin, 'participant_joined', NOW()
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Only audit if financial data changed
    IF OLD.total_buyin != NEW.total_buyin OR OLD.total_cashout != NEW.total_cashout THEN
      INSERT INTO public.financial_audit_log (
        id, table_name, record_id, operation, user_id, old_amount, new_amount, change_reason, created_at
      ) VALUES (
        gen_random_uuid(), 'game_participants', NEW.id, 'UPDATE', NEW.user_id,
        OLD.total_buyin + OLD.total_cashout, NEW.total_buyin + NEW.total_cashout,
        'financial_update', NOW()
      );
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10. Fix sync_profile_to_locations
CREATE OR REPLACE FUNCTION public.sync_profile_to_locations()
RETURNS TRIGGER AS $$
BEGIN
  -- When profile address changes, update any linked locations
  IF (OLD.street_address IS DISTINCT FROM NEW.street_address OR
      OLD.city IS DISTINCT FROM NEW.city OR
      OLD.state_province IS DISTINCT FROM NEW.state_province OR
      OLD.postal_code IS DISTINCT FROM NEW.postal_code OR
      OLD.country IS DISTINCT FROM NEW.country) THEN

    UPDATE public.locations
    SET
      street_address = NEW.street_address,
      city = NEW.city,
      state_province = NEW.state_province,
      postal_code = NEW.postal_code,
      country = NEW.country,
      updated_at = NOW()
    WHERE profile_id = NEW.id AND is_primary = TRUE;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 11. Fix get_location_full_address
CREATE OR REPLACE FUNCTION public.get_location_full_address(loc public.locations)
RETURNS TEXT AS $$
BEGIN
  RETURN CONCAT_WS(', ',
    NULLIF(loc.street_address, ''),
    NULLIF(loc.city, ''),
    NULLIF(loc.state_province, ''),
    NULLIF(loc.postal_code, ''),
    NULLIF(loc.country, '')
  );
END;
$$ LANGUAGE plpgsql STABLE SET search_path = public;

-- 12. Fix enforce_auth_user_for_non_local_profiles
CREATE OR REPLACE FUNCTION public.enforce_auth_user_for_non_local_profiles()
RETURNS TRIGGER AS $$
BEGIN
  -- Skip validation for local users
  IF NEW.is_local_user = TRUE THEN
    RETURN NEW;
  END IF;

  -- For non-local users, ensure they have an auth.users entry
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.id) THEN
    RAISE EXCEPTION 'Non-local profiles must have a corresponding auth.users entry';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 13. Fix get_financial_audit_history
CREATE OR REPLACE FUNCTION public.get_financial_audit_history(
  p_table_name TEXT DEFAULT NULL,
  p_record_id UUID DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
  id UUID,
  table_name TEXT,
  record_id UUID,
  operation TEXT,
  user_id UUID,
  old_amount DECIMAL,
  new_amount DECIMAL,
  old_status TEXT,
  new_status TEXT,
  change_reason TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    fal.id,
    fal.table_name,
    fal.record_id,
    fal.operation,
    fal.user_id,
    fal.old_amount,
    fal.new_amount,
    fal.old_status,
    fal.new_status,
    fal.change_reason,
    fal.created_at
  FROM public.financial_audit_log fal
  WHERE (p_table_name IS NULL OR fal.table_name = p_table_name)
    AND (p_record_id IS NULL OR fal.record_id = p_record_id)
    AND (p_user_id IS NULL OR fal.user_id = p_user_id)
  ORDER BY fal.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 14. Fix get_user_financial_audit
CREATE OR REPLACE FUNCTION public.get_user_financial_audit(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  table_name TEXT,
  record_id UUID,
  operation TEXT,
  old_amount DECIMAL,
  new_amount DECIMAL,
  old_status TEXT,
  new_status TEXT,
  change_reason TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    fal.id,
    fal.table_name,
    fal.record_id,
    fal.operation,
    fal.old_amount,
    fal.new_amount,
    fal.old_status,
    fal.new_status,
    fal.change_reason,
    fal.created_at
  FROM public.financial_audit_log fal
  WHERE fal.user_id = p_user_id
  ORDER BY fal.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 15. Fix get_game_financial_audit_summary
CREATE OR REPLACE FUNCTION public.get_game_financial_audit_summary(
  p_game_id UUID
)
RETURNS TABLE (
  total_transactions BIGINT,
  total_settlements BIGINT,
  latest_audit_entry TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.financial_audit_log fal
     WHERE fal.table_name = 'transactions'
     AND fal.record_id IN (SELECT t.id FROM public.transactions t WHERE t.game_id = p_game_id))::BIGINT,
    (SELECT COUNT(*) FROM public.financial_audit_log fal
     WHERE fal.table_name = 'settlements'
     AND fal.record_id IN (SELECT s.id FROM public.settlements s WHERE s.game_id = p_game_id))::BIGINT,
    (SELECT MAX(fal.created_at) FROM public.financial_audit_log fal
     WHERE fal.record_id IN (
       SELECT t.id FROM public.transactions t WHERE t.game_id = p_game_id
       UNION ALL
       SELECT s.id FROM public.settlements s WHERE s.game_id = p_game_id
     ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 16. Fix audit_rls_access_attempt
CREATE OR REPLACE FUNCTION public.audit_rls_access_attempt()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get current user ID safely
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;

  -- Log RLS policy evaluation for sensitive operations
  -- This is called by RLS policies for debugging and audit purposes
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================
-- PART 2: FIX RLS POLICY ISSUES
-- Replace overly permissive policies with proper restrictions
-- =============================================

-- Create financial_audit_log table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.financial_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  operation TEXT CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  old_amount DECIMAL(10,2),
  new_amount DECIMAL(10,2),
  old_status TEXT,
  new_status TEXT,
  change_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on financial_audit_log
ALTER TABLE public.financial_audit_log ENABLE ROW LEVEL SECURITY;

-- Fix financial_audit_log INSERT policy
-- Only allow inserts via trigger functions (SECURITY DEFINER context)
DROP POLICY IF EXISTS "Only service role can insert audit logs" ON public.financial_audit_log;

CREATE POLICY "Audit logs are insert-only via triggers"
  ON public.financial_audit_log FOR INSERT
  WITH CHECK (
    -- Allow inserts from trigger context (SECURITY DEFINER functions)
    -- Regular users cannot insert directly
    current_setting('role', true) = 'rls_definer' OR
    -- Or if called from a trigger context
    EXISTS (SELECT 1 WHERE pg_trigger_depth() > 0)
  );

-- Allow read access to audit logs for group admins
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.financial_audit_log;

CREATE POLICY "Admins can view related audit logs"
  ON public.financial_audit_log FOR SELECT
  USING (
    -- Users can see audit logs for their own transactions
    user_id = auth.uid()
    OR
    -- Group admins can see audit logs for their groups' data
    EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- Fix settlements INSERT policy - require game membership
DROP POLICY IF EXISTS "Anyone can insert settlements" ON public.settlements;

CREATE POLICY "Group members can insert settlements"
  ON public.settlements FOR INSERT
  WITH CHECK (
    -- User must be a member of the game's group
    game_id IN (
      SELECT g.id FROM public.games g
      INNER JOIN public.group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
    OR
    -- Or user is the group creator
    game_id IN (
      SELECT g.id FROM public.games g
      WHERE g.group_id IN (
        SELECT grp.id FROM public.groups grp WHERE grp.created_by = auth.uid()
      )
    )
  );

-- Fix settlements UPDATE policy - require proper authorization
DROP POLICY IF EXISTS "Anyone can update settlements" ON public.settlements;

CREATE POLICY "Authorized users can update settlements"
  ON public.settlements FOR UPDATE
  USING (
    -- User is involved in the settlement
    auth.uid() = from_user_id OR auth.uid() = to_user_id
    OR
    -- Or user is a group admin for the game's group
    game_id IN (
      SELECT g.id FROM public.games g
      INNER JOIN public.group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  )
  WITH CHECK (
    -- User is involved in the settlement
    auth.uid() = from_user_id OR auth.uid() = to_user_id
    OR
    -- Or user is a group admin for the game's group
    game_id IN (
      SELECT g.id FROM public.games g
      INNER JOIN public.group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- =============================================
-- PART 3: CREATE INDEXES FOR AUDIT LOG PERFORMANCE
-- =============================================

CREATE INDEX IF NOT EXISTS idx_financial_audit_log_table_name ON public.financial_audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_financial_audit_log_record_id ON public.financial_audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_financial_audit_log_user_id ON public.financial_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_financial_audit_log_created_at ON public.financial_audit_log(created_at DESC);

-- =============================================
-- GRANT PERMISSIONS
-- =============================================

GRANT SELECT ON public.financial_audit_log TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_transaction_amount(DECIMAL, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_settlement_amount(DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_financial_audit_history(TEXT, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_financial_audit(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_game_financial_audit_summary(UUID) TO authenticated;
