CREATE TRIGGER check_transaction_integrity
  BEFORE INSERT OR UPDATE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION validate_game_financial_integrity();
