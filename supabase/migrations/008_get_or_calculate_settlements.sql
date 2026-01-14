CREATE OR REPLACE FUNCTION get_or_calculate_settlements(p_game_id UUID)
RETURNS TABLE (
  settlement_id UUID,
  payer_id UUID,
  payee_id UUID,
  amount DECIMAL(10, 2),
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    s.from_user_id,
    s.to_user_id,
    s.amount,
    s.status
  FROM settlements s
  WHERE s.game_id = p_game_id
  ORDER BY s.created_at;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
