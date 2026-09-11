-- ============================================================
-- MARKETRADE — HARDWARE CATEGORY MIGRATION
-- Run this once in the Supabase SQL Editor. Safe to re-run.
-- Adds the hardware_subcategory column to listings so the new
-- 🔨 Hardware category can store its subcategory, the same way
-- every other flat category does.
-- ============================================================

ALTER TABLE listings ADD COLUMN IF NOT EXISTS hardware_subcategory text;
