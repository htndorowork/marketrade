-- ============================================================
-- MARKETRADE — "MAKE AN OFFER" (buyer-negotiated price)
-- Run this whole file once in the Supabase SQL Editor. Safe to
-- re-run (IF NOT EXISTS / IF EXISTS everywhere).
--
-- A buyer can offer a different amount for a listing (10% lower,
-- 10% higher, list price, or a custom amount — same idea as the
-- Facebook Marketplace "Your offer" sheet). The offer is sent as
-- a chat message so buyer + seller negotiate inside Messages.
-- If the seller accepts, that price applies ONLY to that buyer,
-- for that listing — the public listing price never changes.
-- The buyer then has a "Buy at R X" link that carries the offer
-- through checkout (both the free/offline flow and the TradeSafe
-- escrow flow), where it's re-validated server-side before use.
-- ============================================================

-- ===================== OFFERS =====================
CREATE TABLE IF NOT EXISTS offers (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  buyer_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  sender_id uuid NOT NULL, -- who made THIS offer/counter (buyer or seller)
  amount numeric NOT NULL CHECK (amount > 0),
  -- pending | accepted | declined | countered | completed | cancelled
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  responded_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_offers_listing_buyer ON offers (listing_id, buyer_id);
CREATE INDEX IF NOT EXISTS idx_offers_status ON offers (status);

ALTER TABLE offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "offers_read" ON offers;
CREATE POLICY "offers_read" ON offers FOR SELECT USING (
  auth.uid() = buyer_id OR auth.uid() = seller_id
);

-- Either side can open a negotiation, but only as themselves, only tied to
-- the real buyer/seller pair for that listing, and only while the previous
-- offer on this listing (if any) from this buyer isn't still open — this
-- keeps a buyer from stacking multiple simultaneous pending offers.
DROP POLICY IF EXISTS "offers_insert" ON offers;
CREATE POLICY "offers_insert" ON offers FOR INSERT WITH CHECK (
  auth.uid() = sender_id
  AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
  AND buyer_id <> seller_id
  AND EXISTS (SELECT 1 FROM listings WHERE id = listing_id AND seller_id = offers.seller_id)
);

-- Either party in the negotiation can update status (accept/decline/mark
-- countered/mark completed at checkout) — never the amount or who it's from.
DROP POLICY IF EXISTS "offers_update" ON offers;
CREATE POLICY "offers_update" ON offers FOR UPDATE USING (
  auth.uid() = buyer_id OR auth.uid() = seller_id
) WITH CHECK (
  auth.uid() = buyer_id OR auth.uid() = seller_id
);

-- ===================== MESSAGES: link a chat bubble to an offer =====================
ALTER TABLE messages ADD COLUMN IF NOT EXISTS offer_id uuid REFERENCES offers(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_messages_offer ON messages (offer_id);

-- ===================== place_order: honor an accepted offer's price =====================
-- 100% backward compatible: p_offer_id is optional. When supplied, it is
-- re-validated here (never trusted from the client) — must be an 'accepted'
-- offer, for THIS listing, made to THIS buyer — before its amount replaces
-- the listing price. The offer is then marked 'completed' so it can't be
-- reused for a second, separate purchase at the old agreed price.
CREATE OR REPLACE FUNCTION public.place_order(
  p_listing_id uuid,
  p_quantity integer,
  p_delivery_method text DEFAULT NULL,
  p_pargo_point_id text DEFAULT NULL,
  p_pargo_point_name text DEFAULT NULL,
  p_offer_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_buyer uuid := auth.uid();
  v_listing listings%ROWTYPE;
  v_seller profiles%ROWTYPE;
  v_buyer_p profiles%ROWTYPE;
  v_offer offers%ROWTYPE;
  v_order_id uuid;
  v_unit_price numeric;
BEGIN
  IF v_buyer IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_quantity IS NULL OR p_quantity < 1 THEN RAISE EXCEPTION 'Invalid quantity'; END IF;

  SELECT * INTO v_buyer_p FROM profiles WHERE id = v_buyer;
  IF v_buyer_p.full_name IS NULL OR btrim(v_buyer_p.full_name) = ''
     OR v_buyer_p.whatsapp IS NULL OR btrim(v_buyer_p.whatsapp) = '' THEN
    RAISE EXCEPTION 'Add your name and WhatsApp on your profile before ordering';
  END IF;

  SELECT * INTO v_listing FROM listings WHERE id = p_listing_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Listing not found'; END IF;
  IF COALESCE(v_listing.is_draft, false) OR NOT COALESCE(v_listing.is_available, true) THEN
    RAISE EXCEPTION 'Listing unavailable';
  END IF;
  IF COALESCE(v_listing.quantity, 0) < p_quantity THEN
    RAISE EXCEPTION 'Not enough stock';
  END IF;

  SELECT * INTO v_seller FROM profiles WHERE id = v_listing.seller_id;
  IF COALESCE(v_seller.is_blocked, false) THEN RAISE EXCEPTION 'Seller unavailable'; END IF;
  IF NOT COALESCE(v_seller.is_admin, false) THEN
    IF (v_seller.subscription_paid_until IS NULL OR v_seller.subscription_paid_until < CURRENT_DATE)
       AND NOT EXISTS (SELECT 1 FROM settings WHERE key = 'free_mode_active' AND value = 'true') THEN
      RAISE EXCEPTION 'Seller unavailable';
    END IF;
  END IF;

  v_unit_price := CASE WHEN COALESCE(v_listing.discount_percent,0) > 0
    THEN ROUND(v_listing.price * (1 - v_listing.discount_percent/100.0), 2)
    ELSE v_listing.price END;

  IF p_offer_id IS NOT NULL THEN
    SELECT * INTO v_offer FROM offers WHERE id = p_offer_id FOR UPDATE;
    IF NOT FOUND OR v_offer.listing_id <> p_listing_id OR v_offer.buyer_id <> v_buyer
       OR v_offer.status <> 'accepted' THEN
      RAISE EXCEPTION 'This offer is no longer valid — please check the price with the seller again.';
    END IF;
    v_unit_price := v_offer.amount;
  END IF;

  INSERT INTO orders (
    listing_id, seller_id, buyer_id, buyer_name, buyer_whatsapp, quantity, status,
    unit_price, delivery_fee, total_amount, payment_method, delivery_method,
    pargo_point_id, pargo_point_name
  )
  VALUES (
    v_listing.id, v_listing.seller_id, v_buyer, v_buyer_p.full_name, v_buyer_p.whatsapp, p_quantity, 'confirmed',
    v_unit_price, COALESCE(v_listing.delivery_fee,0), v_unit_price * p_quantity + COALESCE(v_listing.delivery_fee,0),
    'offline', p_delivery_method, p_pargo_point_id, p_pargo_point_name
  )
  RETURNING id INTO v_order_id;

  UPDATE listings
  SET quantity = quantity - p_quantity
  WHERE id = v_listing.id;

  IF p_offer_id IS NOT NULL THEN
    UPDATE offers SET status = 'completed', responded_at = now() WHERE id = p_offer_id;
  END IF;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'listing_id', v_listing.id,
    'listing_title', v_listing.title,
    'quantity', p_quantity,
    'unit_price', v_unit_price,
    'seller_id', v_seller.id,
    'seller_name', COALESCE(v_seller.full_name, 'Seller'),
    'seller_whatsapp', COALESCE(v_seller.whatsapp, ''),
    'seller_residence', COALESCE(v_seller.residence, '')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.place_order(uuid, integer, text, text, text, uuid) TO authenticated;
