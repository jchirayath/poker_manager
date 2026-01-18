-- =============================================
-- Create Audit Triggers for Financial Audit Log
-- Attaches audit functions to their respective tables
-- =============================================

-- Drop triggers if they exist (for idempotency)
DROP TRIGGER IF EXISTS audit_transactions_trigger ON public.transactions;
DROP TRIGGER IF EXISTS audit_settlements_trigger ON public.settlements;
DROP TRIGGER IF EXISTS audit_game_participants_trigger ON public.game_participants;

-- Create trigger for transactions table
-- Logs all INSERT, UPDATE, and DELETE operations on transactions
CREATE TRIGGER audit_transactions_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_transaction_change();

-- Create trigger for settlements table
-- Logs all INSERT and UPDATE operations on settlements
CREATE TRIGGER audit_settlements_trigger
  AFTER INSERT OR UPDATE ON public.settlements
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_settlement_change();

-- Create trigger for game_participants table
-- Logs INSERT and financial UPDATE operations on game_participants
CREATE TRIGGER audit_game_participants_trigger
  AFTER INSERT OR UPDATE ON public.game_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_game_participant_change();
