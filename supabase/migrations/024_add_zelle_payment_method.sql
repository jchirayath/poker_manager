-- Migration: Add 'zelle' to settlements payment_method constraint
-- The app supports Zelle as a payment option but it was missing from the database constraint

-- Drop the existing constraint
ALTER TABLE public.settlements
DROP CONSTRAINT IF EXISTS settlements_payment_method_check;

-- Add the updated constraint with 'zelle' included
ALTER TABLE public.settlements
ADD CONSTRAINT settlements_payment_method_check
CHECK (payment_method IN ('cash', 'paypal', 'venmo', 'zelle'));
