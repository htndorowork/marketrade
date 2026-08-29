-- ============================================================
-- MARKETRADE — PAYSTACK SUPPORT MIGRATION
-- Run this once in the Supabase SQL Editor. Safe to re-run.
-- Adds columns so subscription_payments can track which gateway
-- (PayFast or Paystack) a payment came through, without touching
-- any existing PayFast data or behavior.
-- ============================================================

ALTER TABLE subscription_payments ADD COLUMN IF NOT EXISTS gateway text DEFAULT 'payfast';
ALTER TABLE subscription_payments ADD COLUMN IF NOT EXISTS gateway_payment_id text;

-- Backfill: any existing row already has its PayFast reference in
-- pf_payment_id — copy it into the new generic column so admin views
-- can query one column regardless of gateway.
UPDATE subscription_payments
SET gateway_payment_id = pf_payment_id
WHERE gateway_payment_id IS NULL AND pf_payment_id IS NOT NULL;
