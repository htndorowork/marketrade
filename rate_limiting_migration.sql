-- ============================================================
-- MARKETRADE — RATE LIMITING MIGRATION
-- Run this once in the Supabase SQL Editor, after the other
-- migrations. Safe to re-run.
--
-- Adds lightweight abuse limits directly at the database level
-- (RLS), so they apply no matter what client hits the API:
--   - Messages: max 15 per rolling 60 seconds per sender
--   - Reports:  max 5 per rolling 60 minutes per reporter
--   - Listings: max 8 new listings per rolling 5 minutes per seller
--     (on top of the existing active-subscription requirement)
-- Limits are generous enough for normal use and only kick in for
-- bot-speed abuse.
-- ============================================================

-- ---------- Messages ----------
DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users bu
    WHERE bu.is_blocked = true
      AND bu.blocked_id = sender_id
      AND bu.blocker_id = (CASE WHEN sender_id = buyer_id THEN seller_id ELSE buyer_id END)
  )
  AND (
    SELECT count(*) FROM messages m
    WHERE m.sender_id = auth.uid() AND m.created_at > now() - interval '60 seconds'
  ) < 15
);

-- ---------- Reports ----------
DROP POLICY IF EXISTS "reports_insert" ON reports;
CREATE POLICY "reports_insert" ON reports FOR INSERT WITH CHECK (
  auth.uid() = reporter_id
  AND (
    SELECT count(*) FROM reports r
    WHERE r.reporter_id = auth.uid() AND r.created_at > now() - interval '60 minutes'
  ) < 5
);

-- ---------- Listings ----------
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
      OR EXISTS (SELECT 1 FROM settings WHERE key = 'free_mode_active' AND value = 'true')
    )
  )
  AND (
    SELECT count(*) FROM listings l
    WHERE l.seller_id = auth.uid() AND l.created_at > now() - interval '5 minutes'
  ) < 8
);
