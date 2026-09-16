-- ============================================================
-- MARKETRADE — PROPERTIES RENAME + JOBS & WORK + BOATS &
-- WATERMOBILE + CAMPING + BOARD GAMES + VEHICLE DETAIL FIELDS
-- MIGRATION
-- Run this once in the Supabase SQL Editor, after setup.sql /
-- all_in_one_setup.sql (and after any other migrations you've
-- already applied). Safe to re-run.
--
-- 1) Renames the 🏠 Accommodation category to 🏠 Properties.
--    Adds a `properties_subcategory` column (the old
--    `accommodation_subcategory` column is left in place, untouched,
--    for backward compatibility) and moves any existing
--    category='Accommodation' listings over to category='Properties'.
--
-- 2) Adds a new 🧑‍💼 Jobs & Work category via a
--    `jobs_subcategory` column.
--
-- 3) Adds a new ⛵ Boats & Watermobile category via a
--    `watermobile_subcategory` column (All Watermobile / Parts /
--    Accessories).
--
-- 4) Adds a new 🏕️ Camping category (split out of Sports &
--    Services) via a `camping_subcategory` column.
--
-- 5) Adds a new 🎲 Board Games category (split out of Toys &
--    Services) via a `boardgames_subcategory` column.
--
-- 6) Adds dedicated Vehicles-category detail fields so a vehicle
--    listing can capture Make, Model, Year, Transmission, Fuel
--    Type, For Sale By, Colour, Kilometers and Location — matching
--    the fields shown on a typical vehicle listing.
-- ============================================================

-- ---------- 1) Properties (renamed from Accommodation) ----------
ALTER TABLE listings ADD COLUMN IF NOT EXISTS properties_subcategory text;
UPDATE listings SET properties_subcategory = accommodation_subcategory
  WHERE category = 'Accommodation' AND properties_subcategory IS NULL;
UPDATE listings SET category = 'Properties' WHERE category = 'Accommodation';

-- ---------- 2) Jobs & Work ----------
ALTER TABLE listings ADD COLUMN IF NOT EXISTS jobs_subcategory text;

-- ---------- 3) Boats & Watermobile ----------
ALTER TABLE listings ADD COLUMN IF NOT EXISTS watermobile_subcategory text;

-- ---------- 4) Camping (own category, split out of Sports & Services) ----------
ALTER TABLE listings ADD COLUMN IF NOT EXISTS camping_subcategory text;

-- ---------- 5) Board Games (own category, split out of Toys & Services) ----------
ALTER TABLE listings ADD COLUMN IF NOT EXISTS boardgames_subcategory text;

-- ---------- 6) Vehicle detail fields ----------
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_make text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_model text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_year text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_transmission text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_fuel_type text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_for_sale_by text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_colour text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_kilometers integer;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_location text;
