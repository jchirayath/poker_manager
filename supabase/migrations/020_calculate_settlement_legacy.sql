CREATE OR REPLACE FUNCTION calculate_settlement(game_uuid UUID)
RETURNS TABLE(payer UUID, payee UUID, amount DECIMAL) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.payer_id,
    c.payee_id,
    c.amount
  FROM calculate_settlement_atomic(game_uuid) c;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
