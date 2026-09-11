-- ============================================================
-- MARKETRADE — VEHICLES CATEGORY + FREE MODE MIGRATION
-- Run this once in the Supabase SQL Editor, after setup.sql
-- (and after rate_limiting_migration.sql, if you've already run
-- that one). Safe to re-run.
--
-- 1) Adds a `vehicles_subcategory` column to `listings` so the
--    new 🚗 Vehicles category can store its subcategory, the
--    same way every other flat category does.
--
-- 2) Adds a `free_mode_active` row to `settings` (defaults to
--    'false') and updates the `listings_insert` RLS policy so
--    that when an admin flips Free Mode ON from the admin panel,
--    ALL sellers can post without an active paid subscription —
--    enforced at the database level, not just in the UI.
-- ============================================================

-- ---------- 1) Vehicles subcategory column ----------
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicles_subcategory text;

-- ---------- 2) Free Mode setting ----------
INSERT INTO settings (key, value) VALUES ('free_mode_active', 'false')
ON CONFLICT (key) DO NOTHING;

-- Re-apply the listings insert policy so it also allows posting when
-- free_mode_active = 'true', on top of the existing checks. This
-- mirrors whichever version of the policy is currently live for you
-- (including the rate-limit clause, if you've applied that migration) —
-- adjust the rate-limit clause below to match your setup if needed.
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
