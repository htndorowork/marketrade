-- ============================================================
-- STORE LINK — run in MARKETPLACE Supabase SQL Editor
-- Lets sellers add an external link (e.g. Instagram, WhatsApp
-- catalog, another storefront) to their store page.
-- Safe to re-run.
-- ============================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS store_link text;
