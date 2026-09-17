-- ============================================================
-- LISTING-LEVEL REVIEWS — run in MARKETPLACE Supabase SQL Editor
-- Safe to re-run.
-- ============================================================

-- ---------- 1) Add the column ----------
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS listing_id uuid REFERENCES listings(id);

-- ---------- 2) Backfill existing reviews from their order's listing ----------
UPDATE reviews r
SET listing_id = o.listing_id
FROM orders o
WHERE r.order_id = o.id AND r.listing_id IS NULL;

-- ---------- 3) Auto-fill listing_id on new reviews going forward, ----------
-- so the client never has to get it right by hand.
CREATE OR REPLACE FUNCTION public.fill_review_listing_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.listing_id IS NULL THEN
    SELECT listing_id INTO NEW.listing_id FROM orders WHERE id = NEW.order_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fill_review_listing_id ON reviews;
CREATE TRIGGER trg_fill_review_listing_id
  BEFORE INSERT ON reviews
  FOR EACH ROW EXECUTE FUNCTION public.fill_review_listing_id();

-- ---------- 4) Index for fast "reviews for this listing" lookups ----------
CREATE INDEX IF NOT EXISTS idx_reviews_listing_id ON reviews(listing_id);
