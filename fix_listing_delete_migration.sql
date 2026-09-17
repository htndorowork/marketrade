-- ============================================================
-- FIX: Deleting a listing fails if it has messages or reviews
-- Run in MARKETPLACE Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- ---------- 1) Messages: allow listing_id to be nulled by the FK's
-- ON DELETE SET NULL action (this is what was breaking listing deletes —
-- the protection trigger was blocking Postgres's own cascade cleanup),
-- while still blocking anyone from rewriting it to a DIFFERENT listing.
CREATE OR REPLACE FUNCTION public.protect_message_content()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.content IS DISTINCT FROM OLD.content
     OR NEW.sender_id IS DISTINCT FROM OLD.sender_id
     OR NEW.buyer_id IS DISTINCT FROM OLD.buyer_id
     OR NEW.seller_id IS DISTINCT FROM OLD.seller_id
     OR (NEW.listing_id IS DISTINCT FROM OLD.listing_id AND NEW.listing_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Cannot modify message content';
  END IF;
  RETURN NEW;
END;
$$;

-- ---------- 2) Reviews: listing_id had no ON DELETE behavior at all,
-- so deleting a listing with any reviews would fail outright with a
-- foreign key violation. Detach the review from the listing instead of
-- blocking the delete — the review itself (rating/comment) is kept.
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_listing_id_fkey;
ALTER TABLE reviews
ADD CONSTRAINT reviews_listing_id_fkey
FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE SET NULL;
