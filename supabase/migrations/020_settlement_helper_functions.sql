-- Migration: Add settlement helper functions
-- Purpose: Add idempotent settlement retrieval
-- Date: January 4, 2026

-- Function to safely get or calculate settlements (idempotent)
CREATE OR REPLACE FUNCTION get_or_calculate_settlements(p_game_id UUID)
RETURNS TABLE (
  settlement_id UUID,
  payer_id UUID,
  payee_id UUID,
  amount DECIMAL(10, 2),
  status TEXT
) AS $$
BEGIN
  -- Try to return existing settlements first
  RETURN QUERY
  SELECT 
    s.id,
    s.payer_id,
    s.payee_id,
    s.amount,
    s.status
  FROM settlements s
  WHERE s.game_id = p_game_id
  AND s.deleted_at IS NULL
  ORDER BY s.created_at;

  -- If no settlements exist, calculate them atomically
  IF NOT FOUND THEN
    RETURN QUERY
    SELECT 
      c.settlement_id,
      c.payer_id,
      c.payee_id,
      c.amount,
      c.status
    FROM calculate_settlement_atomic(p_game_id) c;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
