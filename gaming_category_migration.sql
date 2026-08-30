-- ============================================================
-- MARKETRADE — GAMING CATEGORY MIGRATION
-- Run this once in the Supabase SQL Editor. Safe to re-run.
-- Adds the gaming_subcategory column to listings so the new
-- 🎮 Gaming category can store its subcategory, the same way
-- every other flat category does.
-- ============================================================

ALTER TABLE listings ADD COLUMN IF NOT EXISTS gaming_subcategory text;
