-- ============================================================
-- FREE MODE — run in MARKETPLACE Supabase SQL Editor
-- Lets ALL sellers post without an active paid subscription. Currently
-- ON, since there is no payment provider wired up. Turn OFF (set value
-- back to 'false') if/when paid seller plans are introduced —
-- everything else (plans, pricing, subscription_payments, the paywall
-- screen itself) stays fully intact and resumes normally.
-- Safe to re-run.
-- ============================================================

INSERT INTO settings (key, value) VALUES ('free_mode', 'true')
ON CONFLICT (key) DO UPDATE SET value = 'true';

-- Listings: allow insert when EITHER the seller has an active paid plan
-- (unchanged, normal path) OR free_mode is on (temporary bypass) OR
-- they're an admin. Keeps the existing rate limit (8/5min) in all cases.
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
      OR EXISTS (SELECT 1 FROM settings WHERE key = 'free_mode' AND value = 'true')
    )
  )
  AND (
    SELECT count(*) FROM listings
    WHERE seller_id = auth.uid() AND created_at > now() - interval '5 minutes'
  ) < 8
);
