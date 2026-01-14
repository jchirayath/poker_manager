CREATE OR REPLACE FUNCTION update_player_statistics()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    INSERT INTO player_statistics (
      user_id, group_id, games_played, total_buyin, total_cashout, net_profit, biggest_win, biggest_loss
    )
    SELECT gp.user_id, g.group_id, 1, gp.total_buyin, gp.total_cashout, gp.net_result,
      CASE WHEN gp.net_result > 0 THEN gp.net_result ELSE 0 END,
      CASE WHEN gp.net_result < 0 THEN gp.net_result ELSE 0 END
    FROM game_participants gp
    JOIN games g ON g.id = gp.game_id
    WHERE gp.game_id = NEW.id
    ON CONFLICT (user_id, group_id) DO UPDATE SET
      games_played = player_statistics.games_played + 1,
      total_buyin = player_statistics.total_buyin + EXCLUDED.total_buyin,
      total_cashout = player_statistics.total_cashout + EXCLUDED.total_cashout,
      net_profit = player_statistics.net_profit + EXCLUDED.net_profit,
      biggest_win = GREATEST(player_statistics.biggest_win, EXCLUDED.biggest_win),
      biggest_loss = LEAST(player_statistics.biggest_loss, EXCLUDED.biggest_loss),
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
