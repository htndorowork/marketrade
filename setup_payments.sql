-- ============================================================
-- Seller subscription payments — run in the MARKETPLACE Supabase SQL Editor
-- Project: kqsqtasykdtpdrkqyaxp
-- ============================================================

-- Payment records (created when seller clicks Pay, completed by the payment
-- provider's webhook once wired up)
CREATE TABLE IF NOT EXISTS subscription_payments (
  id text PRIMARY KEY,
  seller_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  plan text NOT NULL,
  amount numeric NOT NULL,
  days integer NOT NULL,
  status text DEFAULT 'pending',
  pf_payment_id text,
  created_at timestamp DEFAULT now(),
  paid_at timestamp
);

ALTER TABLE subscription_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sub_pay_insert_own" ON subscription_payments;
DROP POLICY IF EXISTS "sub_pay_read_own" ON subscription_payments;
DROP POLICY IF EXISTS "sub_pay_admin" ON subscription_payments;

CREATE POLICY "sub_pay_insert_own" ON subscription_payments
  FOR INSERT WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "sub_pay_read_own" ON subscription_payments
  FOR SELECT USING (
    auth.uid() = seller_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "sub_pay_admin" ON subscription_payments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- Require an active paid subscription to post (no free / NULL access)
DROP POLICY IF EXISTS "listings_insert" ON listings;
CREATE POLICY "listings_insert" ON listings FOR INSERT WITH CHECK (
  auth.uid() = seller_id AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND COALESCE(is_blocked,false) = false
    AND (
      COALESCE(is_admin,false) = true
      OR (subscription_paid_until IS NOT NULL AND subscription_paid_until >= CURRENT_DATE)
    )
  )
);
