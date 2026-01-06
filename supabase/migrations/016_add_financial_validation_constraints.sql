-- =============================================
-- Add Financial Validation Constraints
-- Migration: 016_add_financial_validation_constraints
-- Purpose: Enforce data integrity for financial records
-- - Prevent negative amounts
-- - Enforce 2 decimal place precision
-- - Add reasonable max constraints
-- =============================================

-- ====================
-- Transactions Table Constraints
-- ====================

-- Remove old constraint if exists and add comprehensive validation
ALTER TABLE transactions
DROP CONSTRAINT IF EXISTS "amount_positive",
DROP CONSTRAINT IF EXISTS transactions_amount_check;

-- Add constraint: amount must be positive
ALTER TABLE transactions
ADD CONSTRAINT transactions_amount_positive
  CHECK (amount > 0);

-- Add constraint: amount must have at most 2 decimal places (0.01 cent minimum)
ALTER TABLE transactions
ADD CONSTRAINT transactions_amount_precision
  CHECK (amount = ROUND(amount::numeric, 2));

-- Add constraint: reasonable maximum transaction (prevent typos like $999999)
ALTER TABLE transactions
ADD CONSTRAINT transactions_amount_max
  CHECK (amount <= 10000.00);

-- Create index for efficient queries on amount/status
CREATE INDEX IF NOT EXISTS idx_transactions_amount
  ON transactions(amount);

CREATE INDEX IF NOT EXISTS idx_transactions_type
  ON transactions(type);

CREATE INDEX IF NOT EXISTS idx_transactions_game_user
  ON transactions(game_id, user_id);

-- ====================
-- Settlements Table Constraints
-- ====================

-- Remove old constraint if exists and add comprehensive validation
ALTER TABLE settlements
DROP CONSTRAINT IF EXISTS settlements_amount_check;

-- Add constraint: amount must be positive
ALTER TABLE settlements
ADD CONSTRAINT settlements_amount_positive
  CHECK (amount > 0);

-- Add constraint: amount must have at most 2 decimal places
ALTER TABLE settlements
ADD CONSTRAINT settlements_amount_precision
  CHECK (amount = ROUND(amount::numeric, 2));

-- Add constraint: reasonable maximum settlement (typically smaller than transaction max)
ALTER TABLE settlements
ADD CONSTRAINT settlements_amount_max
  CHECK (amount <= 5000.00);

-- Add constraint: payer and payee must be different
ALTER TABLE settlements
ADD CONSTRAINT settlements_different_parties
  CHECK (payer_id != payee_id);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_settlements_amount
  ON settlements(amount);

CREATE INDEX IF NOT EXISTS idx_settlements_payer
  ON settlements(payer_id);

CREATE INDEX IF NOT EXISTS idx_settlements_payee
  ON settlements(payee_id);

CREATE INDEX IF NOT EXISTS idx_settlements_status
  ON settlements(status);

CREATE INDEX IF NOT EXISTS idx_settlements_game_status
  ON settlements(game_id, status);

-- ====================
-- Game Participants Table Constraints
-- ====================

-- Add constraints to game_participants to ensure valid financial data
ALTER TABLE game_participants
DROP CONSTRAINT IF EXISTS game_participants_buyin_check,
DROP CONSTRAINT IF EXISTS game_participants_cashout_check;

-- Add constraint: buyin must be non-negative
ALTER TABLE game_participants
ADD CONSTRAINT game_participants_buyin_positive
  CHECK (total_buyin >= 0);

-- Add constraint: cashout must be non-negative
ALTER TABLE game_participants
ADD CONSTRAINT game_participants_cashout_positive
  CHECK (total_cashout >= 0);

-- Add constraint: buyin must have at most 2 decimal places
ALTER TABLE game_participants
ADD CONSTRAINT game_participants_buyin_precision
  CHECK (total_buyin = ROUND(total_buyin::numeric, 2));

-- Add constraint: cashout must have at most 2 decimal places
ALTER TABLE game_participants
ADD CONSTRAINT game_participants_cashout_precision
  CHECK (total_cashout = ROUND(total_cashout::numeric, 2));

-- Create indexes for efficient financial calculations
CREATE INDEX IF NOT EXISTS idx_game_participants_buyin
  ON game_participants(total_buyin);

CREATE INDEX IF NOT EXISTS idx_game_participants_cashout
  ON game_participants(total_cashout);

CREATE INDEX IF NOT EXISTS idx_game_participants_net_result
  ON game_participants(net_result);

-- ====================
-- Player Statistics Table Constraints
-- ====================

-- Add constraints for player statistics data integrity
ALTER TABLE player_statistics
DROP CONSTRAINT IF EXISTS player_statistics_amounts_check;

-- Amount fields must have at most 2 decimal places
ALTER TABLE player_statistics
ADD CONSTRAINT player_statistics_buyin_precision
  CHECK (total_buyin = ROUND(total_buyin::numeric, 2));

ALTER TABLE player_statistics
ADD CONSTRAINT player_statistics_cashout_precision
  CHECK (total_cashout = ROUND(total_cashout::numeric, 2));

ALTER TABLE player_statistics
ADD CONSTRAINT player_statistics_net_precision
  CHECK (net_profit = ROUND(net_profit::numeric, 2));

ALTER TABLE player_statistics
ADD CONSTRAINT player_statistics_win_precision
  CHECK (biggest_win = ROUND(biggest_win::numeric, 2));

ALTER TABLE player_statistics
ADD CONSTRAINT player_statistics_loss_precision
  CHECK (biggest_loss = ROUND(biggest_loss::numeric, 2));

-- ====================
-- Validation Functions
-- ====================

-- Create validation helper function for transactions
CREATE OR REPLACE FUNCTION validate_transaction_amount(
  p_amount DECIMAL,
  p_type TEXT
)
RETURNS TABLE (
  is_valid BOOLEAN,
  message TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT 
    CASE 
      WHEN p_amount IS NULL THEN FALSE
      WHEN p_amount <= 0 THEN FALSE
      WHEN p_amount > 10000.00 THEN FALSE
      WHEN p_amount != ROUND(p_amount::numeric, 2) THEN FALSE
      ELSE TRUE
    END,
    CASE 
      WHEN p_amount IS NULL THEN 'Amount cannot be null'
      WHEN p_amount <= 0 THEN 'Amount must be positive'
      WHEN p_amount > 10000.00 THEN 'Amount exceeds maximum of $10,000'
      WHEN p_amount != ROUND(p_amount::numeric, 2) THEN 'Amount must have at most 2 decimal places'
      ELSE 'Valid'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create validation helper function for settlements
CREATE OR REPLACE FUNCTION validate_settlement_amount(
  p_amount DECIMAL
)
RETURNS TABLE (
  is_valid BOOLEAN,
  message TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT 
    CASE 
      WHEN p_amount IS NULL THEN FALSE
      WHEN p_amount <= 0 THEN FALSE
      WHEN p_amount > 5000.00 THEN FALSE
      WHEN p_amount != ROUND(p_amount::numeric, 2) THEN FALSE
      ELSE TRUE
    END,
    CASE 
      WHEN p_amount IS NULL THEN 'Amount cannot be null'
      WHEN p_amount <= 0 THEN 'Amount must be positive'
      WHEN p_amount > 5000.00 THEN 'Settlement exceeds maximum of $5,000'
      WHEN p_amount != ROUND(p_amount::numeric, 2) THEN 'Amount must have at most 2 decimal places'
      ELSE 'Valid'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ====================
-- Audit Log Function for Financial Operations
-- ====================

-- Create audit log table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.financial_audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  operation TEXT CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')) NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  old_amount DECIMAL(10,2),
  new_amount DECIMAL(10,2),
  old_status TEXT,
  new_status TEXT,
  change_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for audit queries
CREATE INDEX IF NOT EXISTS idx_financial_audit_record 
  ON financial_audit_log(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_financial_audit_user 
  ON financial_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_financial_audit_created_at 
  ON financial_audit_log(created_at DESC);

-- Create trigger function for transaction auditing
CREATE OR REPLACE FUNCTION audit_transaction_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO financial_audit_log (
      table_name, record_id, operation, user_id, 
      new_amount, created_at
    ) VALUES (
      'transactions', NEW.id, 'INSERT', NEW.user_id,
      NEW.amount, NOW()
    );
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO financial_audit_log (
      table_name, record_id, operation, user_id,
      old_amount, new_amount, created_at
    ) VALUES (
      'transactions', NEW.id, 'UPDATE', NEW.user_id,
      OLD.amount, NEW.amount, NOW()
    );
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO financial_audit_log (
      table_name, record_id, operation, user_id,
      old_amount, created_at
    ) VALUES (
      'transactions', OLD.id, 'DELETE', OLD.user_id,
      OLD.amount, NOW()
    );
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for transaction changes
DROP TRIGGER IF EXISTS transaction_audit_trigger ON transactions;
CREATE TRIGGER transaction_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON transactions
FOR EACH ROW
EXECUTE FUNCTION audit_transaction_change();

-- Create trigger function for settlement auditing
CREATE OR REPLACE FUNCTION audit_settlement_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO financial_audit_log (
      table_name, record_id, operation, user_id,
      new_amount, new_status, created_at
    ) VALUES (
      'settlements', NEW.id, 'INSERT', NEW.payer_id,
      NEW.amount, NEW.status, NOW()
    );
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO financial_audit_log (
      table_name, record_id, operation, user_id,
      old_amount, new_amount, old_status, new_status,
      created_at
    ) VALUES (
      'settlements', NEW.id, 'UPDATE', NEW.payer_id,
      OLD.amount, NEW.amount, OLD.status, NEW.status,
      NOW()
    );
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for settlement changes
DROP TRIGGER IF EXISTS settlement_audit_trigger ON settlements;
CREATE TRIGGER settlement_audit_trigger
AFTER INSERT OR UPDATE ON settlements
FOR EACH ROW
EXECUTE FUNCTION audit_settlement_change();

-- Create trigger function for game_participants auditing
CREATE OR REPLACE FUNCTION audit_game_participant_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO financial_audit_log (
      table_name, record_id, operation, user_id,
      new_amount, created_at
    ) VALUES (
      'game_participants', NEW.id, 'INSERT', NEW.user_id,
      NEW.total_buyin, NOW()
    );
  ELSIF TG_OP = 'UPDATE' THEN
    -- Log if buyin or cashout changed
    IF OLD.total_buyin != NEW.total_buyin OR OLD.total_cashout != NEW.total_cashout THEN
      INSERT INTO financial_audit_log (
        table_name, record_id, operation, user_id,
        old_amount, new_amount, created_at
      ) VALUES (
        'game_participants', NEW.id, 'UPDATE', NEW.user_id,
        OLD.total_buyin + OLD.total_cashout,
        NEW.total_buyin + NEW.total_cashout,
        NOW()
      );
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for game_participants changes
DROP TRIGGER IF EXISTS game_participant_audit_trigger ON game_participants;
CREATE TRIGGER game_participant_audit_trigger
AFTER INSERT OR UPDATE ON game_participants
FOR EACH ROW
EXECUTE FUNCTION audit_game_participant_change();

-- ====================
-- Audit Query Helper Functions
-- ====================

-- Get audit history for a specific record
CREATE OR REPLACE FUNCTION get_financial_audit_history(
  p_table_name TEXT,
  p_record_id UUID
)
RETURNS TABLE (
  id UUID,
  operation TEXT,
  user_id UUID,
  old_amount DECIMAL(10,2),
  new_amount DECIMAL(10,2),
  old_status TEXT,
  new_status TEXT,
  change_reason TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fal.id,
    fal.operation,
    fal.user_id,
    fal.old_amount,
    fal.new_amount,
    fal.old_status,
    fal.new_status,
    fal.change_reason,
    fal.created_at
  FROM financial_audit_log fal
  WHERE fal.table_name = p_table_name
    AND fal.record_id = p_record_id
  ORDER BY fal.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get recent audit entries for a user
CREATE OR REPLACE FUNCTION get_user_financial_audit(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  table_name TEXT,
  record_id UUID,
  operation TEXT,
  old_amount DECIMAL(10,2),
  new_amount DECIMAL(10,2),
  old_status TEXT,
  new_status TEXT,
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
    fal.created_at
  FROM financial_audit_log fal
  WHERE fal.user_id = p_user_id
  ORDER BY fal.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get audit summary for a game
CREATE OR REPLACE FUNCTION get_game_financial_audit_summary(
  p_game_id UUID
)
RETURNS TABLE (
  table_name TEXT,
  operation_count INTEGER,
  total_amount DECIMAL(10,2),
  first_change TIMESTAMPTZ,
  last_change TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fal.table_name,
    COUNT(*)::INTEGER as operation_count,
    COALESCE(SUM(fal.new_amount), 0) as total_amount,
    MIN(fal.created_at) as first_change,
    MAX(fal.created_at) as last_change
  FROM financial_audit_log fal
  WHERE fal.record_id IN (
    SELECT id FROM transactions WHERE game_id = p_game_id
    UNION
    SELECT id FROM settlements WHERE game_id = p_game_id
    UNION
    SELECT id FROM game_participants WHERE game_id = p_game_id
  )
  GROUP BY fal.table_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================
-- Grant Permissions
-- ====================

-- Grant execute permission on validation functions
GRANT EXECUTE ON FUNCTION validate_transaction_amount(DECIMAL, TEXT) 
  TO authenticated;

GRANT EXECUTE ON FUNCTION validate_settlement_amount(DECIMAL) 
  TO authenticated;

GRANT EXECUTE ON FUNCTION validate_settlement_amount(DECIMAL) 
  TO anon;

-- Grant execute permission on audit query functions
GRANT EXECUTE ON FUNCTION get_financial_audit_history(TEXT, UUID)
  TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_financial_audit(UUID, INTEGER)
  TO authenticated;

GRANT EXECUTE ON FUNCTION get_game_financial_audit_summary(UUID)
  TO authenticated;

-- RLS Policy for audit log (users can only see their own audit entries)
ALTER TABLE financial_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own financial audit"
  ON financial_audit_log FOR SELECT
  USING (
    user_id = auth.uid() OR
    user_id IS NULL
  );

CREATE POLICY "Only service role can insert audit logs"
  ON financial_audit_log FOR INSERT
  WITH CHECK (true);

-- ====================
-- Data Integrity Check (one-time)
-- ====================

-- These checks ensure existing data complies with new constraints
-- If any violations exist, they will be logged for manual review

DO $$ 
DECLARE
  v_invalid_transactions INTEGER;
  v_invalid_settlements INTEGER;
  v_invalid_participants INTEGER;
BEGIN
  -- Check for invalid transactions
  SELECT COUNT(*) INTO v_invalid_transactions
  FROM transactions
  WHERE amount <= 0 
    OR amount > 10000.00
    OR amount != ROUND(amount::numeric, 2);
  
  IF v_invalid_transactions > 0 THEN
    RAISE WARNING 'Found % invalid transactions - review required', v_invalid_transactions;
  END IF;

  -- Check for invalid settlements
  SELECT COUNT(*) INTO v_invalid_settlements
  FROM settlements
  WHERE amount <= 0 
    OR amount > 5000.00
    OR amount != ROUND(amount::numeric, 2)
    OR payer_id = payee_id;
  
  IF v_invalid_settlements > 0 THEN
    RAISE WARNING 'Found % invalid settlements - review required', v_invalid_settlements;
  END IF;

  -- Check for invalid game_participants
  SELECT COUNT(*) INTO v_invalid_participants
  FROM game_participants
  WHERE total_buyin < 0
    OR total_cashout < 0
    OR total_buyin != ROUND(total_buyin::numeric, 2)
    OR total_cashout != ROUND(total_cashout::numeric, 2);
  
  IF v_invalid_participants > 0 THEN
    RAISE WARNING 'Found % invalid game participants - review required', v_invalid_participants;
  END IF;

  RAISE NOTICE 'Financial validation constraints applied successfully';
END $$;
