-- Migration: Add settlement constraints and audit tables
-- Purpose: Add validation constraints and audit logging
-- Date: January 4, 2026

-- Ensure payer and payee are different
ALTER TABLE settlements
DROP CONSTRAINT IF EXISTS settlements_no_self_payment;

ALTER TABLE settlements
ADD CONSTRAINT settlements_no_self_payment
CHECK (payer_id != payee_id);

-- Ensure amounts are reasonable
ALTER TABLE settlements
DROP CONSTRAINT IF EXISTS settlements_valid_amount;

ALTER TABLE settlements
ADD CONSTRAINT settlements_valid_amount
CHECK (amount > 0 AND amount <= 5000.00);

-- Ensure amounts have 2 decimal places
ALTER TABLE settlements
DROP CONSTRAINT IF EXISTS settlements_decimal_precision;

ALTER TABLE settlements
ADD CONSTRAINT settlements_decimal_precision
CHECK (amount = ROUND(amount::NUMERIC, 2));

-- Create settlement calculation audit table
CREATE TABLE IF NOT EXISTS settlement_calculation_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID NOT NULL REFERENCES games(id),
  attempted_by UUID REFERENCES profiles(id),
  status TEXT CHECK (status IN ('success', 'failed', 'conflict')) NOT NULL,
  error_message TEXT,
  total_buyin DECIMAL(10, 2),
  total_cashout DECIMAL(10, 2),
  settlements_created INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settlement_calc_log_game ON settlement_calculation_log(game_id);
CREATE INDEX IF NOT EXISTS idx_settlement_calc_log_status ON settlement_calculation_log(status);
CREATE INDEX IF NOT EXISTS idx_settlement_calc_log_created_at ON settlement_calculation_log(created_at DESC);
