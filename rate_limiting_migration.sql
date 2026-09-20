-- ============================================================
-- RATE LIMITING — run in MARKETPLACE Supabase SQL Editor
-- Requires setup.sql and growth_and_safety_migration.sql already applied.
-- Safe to re-run.
--
-- Enforced server-side (inside RLS WITH CHECK), so it can't be bypassed
-- by calling the API directly instead of going through the app UI.
-- Limits:
--   - Messages:  15 per minute per sender
--   - Reports:    5 per hour per reporter
--   - Listings:   8 per 5 minutes per seller
-- ============================================================

-- ---------- Messages: 15/min ----------
DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = (CASE WHEN sender_id = buyer_id THEN seller_id ELSE buyer_id END)
      AND blocked_id = sender_id
  )
  AND (
    SELECT count(*) FROM messages
    WHERE sender_id = auth.uid() AND created_at > now() - interval '1 minute'
  ) < 15
);

-- ---------- Reports: 5/hour ----------
DROP POLICY IF EXISTS "reports_insert" ON reports;
CREATE POLICY "reports_insert" ON reports FOR INSERT WITH CHECK (
  auth.uid() = reporter_id
  AND (
    SELECT count(*) FROM reports
    WHERE reporter_id = auth.uid() AND created_at > now() - interval '1 hour'
  ) < 5
);

-- ---------- Listings: 8/5min ----------
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
  AND (
    SELECT count(*) FROM listings
    WHERE seller_id = auth.uid() AND created_at > now() - interval '5 minutes'
  ) < 8
);
