-- Create stored procedure to record settlements
CREATE OR REPLACE FUNCTION public.record_settlement(
  p_game_id UUID,
  p_from_user_id UUID,
  p_to_user_id UUID,
  p_amount DECIMAL,
  p_payment_method VARCHAR
)
RETURNS TABLE(
  id UUID,
  game_id UUID,
  from_user_id UUID,
  to_user_id UUID,
  amount DECIMAL,
  payment_method VARCHAR,
  settled_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  INSERT INTO public.settlements (
    game_id,
    from_user_id,
    to_user_id,
    amount,
    payment_method
  )
  VALUES (
    p_game_id,
    p_from_user_id,
    p_to_user_id,
    p_amount,
    p_payment_method
  )
  ON CONFLICT (game_id, from_user_id, to_user_id) DO UPDATE
  SET 
    amount = p_amount,
    payment_method = p_payment_method,
    settled_at = CURRENT_TIMESTAMP
  RETURNING 
    settlements.id,
    settlements.game_id,
    settlements.from_user_id,
    settlements.to_user_id,
    settlements.amount,
    settlements.payment_method,
    settlements.settled_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.record_settlement TO authenticated;
