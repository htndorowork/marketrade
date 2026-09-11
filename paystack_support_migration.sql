-- ============================================================
-- MARKETRADE — PAYSTACK SUPPORT MIGRATION
-- Run this once in the Supabase SQL Editor. Safe to re-run.
-- Adds columns so subscription_payments can track which gateway a
-- payment came through. Marketrade now processes all new subscription
-- payments through Paystack only — the PayFast integration has been
-- retired. The pf_payment_id column and any 'payfast' rows are kept
-- purely as a historical record of payments made before the switch;
-- no new PayFast payments will be created.
-- ============================================================

ALTER TABLE subscription_payments ADD COLUMN IF NOT EXISTS gateway text DEFAULT 'paystack';
ALTER TABLE subscription_payments ADD COLUMN IF NOT EXISTS gateway_payment_id text;

-- Backfill: any pre-existing row from the retired PayFast integration had
-- its reference in pf_payment_id — copy it into the new generic column so
-- admin views can query one column regardless of which gateway was used.
UPDATE subscription_payments
SET gateway_payment_id = pf_payment_id
WHERE gateway_payment_id IS NULL AND pf_payment_id IS NOT NULL;
