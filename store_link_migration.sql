-- Adds an optional external link (website, WhatsApp catalog, Instagram, etc.)
-- that sellers can show on their public storefront page.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS store_link text;
