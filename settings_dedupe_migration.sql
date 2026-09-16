-- ============================================================
-- MARKETRADE — SETTINGS TABLE DEDUPE / INTEGRITY FIX
-- Run this once in the Supabase SQL Editor. Safe to re-run.
--
-- What this fixes:
-- The `settings` table (paywall_active / free_mode_active) is
-- supposed to have exactly one row per key, enforced by a PRIMARY
-- KEY on `key`. If that constraint was ever missing when earlier
-- setup/migration scripts were run, you can end up with more than
-- one row for the same key. A couple of places in the app read
-- this table with .single()/.maybeSingle() (which errors out if
-- more than one row comes back) — when that happens, the app
-- silently treats Free Mode as OFF, which hides every listing from
-- sellers who don't have an active paid plan on the main Browse
-- page, even though the admin dashboard may still show Free Mode
-- as ON (it reads the table in a way that tolerates duplicates).
--
-- This script keeps one row per key (preferring 'true' if any
-- duplicate for that key is set to 'true', so nobody's Free Mode
-- toggle gets silently reset to off), removes the rest, and makes
-- sure the primary key constraint is actually in place going
-- forward so this can't happen again.
-- ============================================================

-- Keep a single row per key. When duplicates exist for a key,
-- prefer a 'true' row over a 'false' row so an admin's existing
-- Free Mode / paywall choice isn't lost by the cleanup.
WITH ranked AS (
  SELECT ctid, key, value,
         row_number() OVER (
           PARTITION BY key
           ORDER BY (value = 'true') DESC, ctid
         ) AS rn
  FROM settings
)
DELETE FROM settings s
USING ranked r
WHERE s.ctid = r.ctid AND r.rn > 1;

-- Make sure the primary key constraint actually exists (a no-op if
-- it's already there).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'settings' AND constraint_type = 'PRIMARY KEY'
  ) THEN
    ALTER TABLE settings ADD PRIMARY KEY (key);
  END IF;
END $$;

-- Make sure both expected rows exist (harmless if they already do).
INSERT INTO settings (key, value) VALUES ('paywall_active', 'false')
ON CONFLICT (key) DO NOTHING;
INSERT INTO settings (key, value) VALUES ('free_mode_active', 'false')
ON CONFLICT (key) DO NOTHING;
