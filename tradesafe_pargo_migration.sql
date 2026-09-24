-- ============================================================
-- MARKETRADE — TRADESAFE ESCROW + PARGO DELIVERY + WALLET
-- Run this whole file once in the Supabase SQL Editor. Safe to
-- re-run (IF NOT EXISTS / IF EXISTS everywhere).
--
-- This adds a SECOND, OPTIONAL way for a buyer to pay a seller:
-- real online payment held in escrow by TradeSafe, released to
-- the seller's in-app Wallet either when the seller enters the
-- buyer's Collection PIN (in-person handover) or automatically
-- 24 hours after Pargo confirms the parcel reached the pickup
-- point (unless the buyer opens a dispute first).
--
-- The existing "arrange payment privately with the seller" flow
-- (place_order / orders.status='confirmed') is untouched — both
-- flows coexist. how-payments-work.html has been updated to
-- describe both.
-- ============================================================

-- ===================== ORDERS: escrow + delivery columns =====================
-- Existing `orders` table never stored a price (buyers/sellers agreed price
-- privately). Escrow orders need a real amount, so we snapshot it at checkout.
ALTER TABLE orders ADD COLUMN IF NOT EXISTS unit_price numeric;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee numeric DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS total_amount numeric; -- unit_price*quantity + delivery_fee, snapshot at checkout

-- 'offline'   = existing WhatsApp/cash/EFT-arranged-privately flow (default, unchanged)
-- 'tradesafe' = new escrow flow below
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method text DEFAULT 'offline';

-- Payment status of the TradeSafe transaction itself
--   pending -> paid -> (released | refunded)   |   failed
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status text;

-- Escrow status once paid: held -> released | disputed -> resolved_release | resolved_refund
ALTER TABLE orders ADD COLUMN IF NOT EXISTS escrow_status text;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS tradesafe_transaction_id text; -- TradeSafe transaction ID (short form, used in mutations)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tradesafe_allocation_id text; -- the single allocation's ID (used for release/dispute mutations)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tradesafe_checkout_url text; -- hosted payment page the buyer was sent to

-- Delivery method chosen at checkout for THIS order
--   'in_person' = existing meetup handover, buyer gives seller a 6-digit PIN
--   'pargo'     = Pargo pickup-point delivery
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_method text;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS collection_pin text;         -- 6-digit PIN shown to buyer, entered by seller on handover
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pargo_point_id text;         -- Pargo pickup point ID chosen at checkout
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pargo_point_name text;       -- human-readable name/address for display
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pargo_shipment_id text;      -- Pargo's shipment/waybill reference
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pargo_status text;           -- Pargo's own status string ("in_transit", "at_point", "collected", ...)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at timestamptz;    -- set when Pargo confirms the parcel reached the point
ALTER TABLE orders ADD COLUMN IF NOT EXISTS escrow_release_at timestamptz; -- delivered_at + 24h — the cron job's release deadline

ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_status text DEFAULT 'none'; -- none | open | resolved_release | resolved_refund
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_reason text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_opened_at timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_resolved_at timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_resolution_note text;

CREATE INDEX IF NOT EXISTS idx_orders_escrow_release ON orders (escrow_release_at) WHERE escrow_status = 'held';
CREATE INDEX IF NOT EXISTS idx_orders_payment_method ON orders (payment_method);

-- ===================== PROFILES: wallet + TradeSafe token cache =====================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS wallet_balance numeric DEFAULT 0;
-- Cached TradeSafe "token" ID for this user (tokenCreate is only called once per
-- user — the same token is then reused as a party on every future transaction).
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS tradesafe_token_id text;
-- ID number is required by TradeSafe to create a user token (buyers and sellers
-- both need one; sellers additionally need banking details — collected via the
-- existing "withdraw to bank" flow the first time they request a payout).
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS id_number text;

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS wallet_balance_non_negative;
ALTER TABLE profiles ADD CONSTRAINT wallet_balance_non_negative CHECK (wallet_balance >= 0);

-- ===================== WALLET TRANSACTIONS (ledger) =====================
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  seller_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  type text NOT NULL, -- 'escrow_release' | 'withdrawal_request' | 'withdrawal_paid' | 'adjustment'
  amount numeric NOT NULL, -- positive = credit to wallet, negative = debit
  note text,
  status text DEFAULT 'completed', -- 'completed' | 'pending' (used for withdrawal_request until admin pays out)
  created_at timestamptz DEFAULT now()
);
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "wallet_tx_read" ON wallet_transactions;
CREATE POLICY "wallet_tx_read" ON wallet_transactions FOR SELECT USING (
  auth.uid() = seller_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
-- No direct INSERT/UPDATE policy for regular users — every row is written by
-- edge functions using the service-role key (escrow release, withdrawal
-- requests, admin payouts), never directly by client-side code.
DROP POLICY IF EXISTS "wallet_tx_admin_write" ON wallet_transactions;
CREATE POLICY "wallet_tx_admin_write" ON wallet_transactions FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
) WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- ===================== WALLET WITHDRAWAL REQUESTS =====================
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  seller_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount numeric NOT NULL CHECK (amount > 0),
  status text DEFAULT 'pending', -- 'pending' | 'paid' | 'rejected'
  bank_details jsonb, -- snapshot of where to pay, entered by the seller
  admin_note text,
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "withdrawals_read" ON withdrawal_requests;
CREATE POLICY "withdrawals_read" ON withdrawal_requests FOR SELECT USING (
  auth.uid() = seller_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
DROP POLICY IF EXISTS "withdrawals_insert" ON withdrawal_requests;
CREATE POLICY "withdrawals_insert" ON withdrawal_requests FOR INSERT WITH CHECK (auth.uid() = seller_id);
DROP POLICY IF EXISTS "withdrawals_admin_update" ON withdrawal_requests;
CREATE POLICY "withdrawals_admin_update" ON withdrawal_requests FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- ===================== place_order: also accept a delivery method =====================
-- Kept 100% backward compatible: p_delivery_method/p_pargo_point_id/p_pargo_point_name
-- are optional and only used by the offline flow to remember what the buyer picked
-- (e.g. so the seller can see "buyer wants Pargo to Sandton City" even without
-- escrow). Escrow ('tradesafe') orders are created directly by the
-- tradesafe-checkout edge function instead of this RPC, because they need a
-- service-role insert plus a call to the TradeSafe API before the row is final.
CREATE OR REPLACE FUNCTION public.place_order(
  p_listing_id uuid,
  p_quantity integer,
  p_delivery_method text DEFAULT NULL,
  p_pargo_point_id text DEFAULT NULL,
  p_pargo_point_name text DEFAULT NULL
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

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'listing_id', v_listing.id,
    'listing_title', v_listing.title,
    'quantity', p_quantity,
    'seller_id', v_seller.id,
    'seller_name', COALESCE(v_seller.full_name, 'Seller'),
    'seller_whatsapp', COALESCE(v_seller.whatsapp, ''),
    'seller_residence', COALESCE(v_seller.residence, '')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.place_order(uuid, integer, text, text, text) TO authenticated;

-- ===================== Wallet balance credit helper (used by edge functions) =====================
-- Wrapping the credit in a function keeps the ledger (wallet_transactions) and
-- the running total (profiles.wallet_balance) from ever drifting apart, and
-- makes it easy to call with the service-role key from an edge function.
CREATE OR REPLACE FUNCTION public.credit_seller_wallet(
  p_seller_id uuid,
  p_order_id uuid,
  p_amount numeric,
  p_type text,
  p_note text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO wallet_transactions (seller_id, order_id, type, amount, note)
  VALUES (p_seller_id, p_order_id, p_type, p_amount, p_note);

  UPDATE profiles SET wallet_balance = COALESCE(wallet_balance,0) + p_amount
  WHERE id = p_seller_id;
END;
$$;
-- Only ever called with the service-role key from edge functions (not exposed
-- to authenticated/anon), so no GRANT to those roles.

-- Lets an admin debit a seller's wallet from admin.html directly (e.g. once a
-- withdrawal_request has actually been paid out via EFT) without needing the
-- service-role key client-side. Mirrors credit_seller_wallet's bookkeeping.
CREATE OR REPLACE FUNCTION public.admin_adjust_wallet_balance(
  p_seller_id uuid,
  p_delta numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RAISE EXCEPTION 'Admins only';
  END IF;
  UPDATE profiles SET wallet_balance = COALESCE(wallet_balance,0) + p_delta WHERE id = p_seller_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_adjust_wallet_balance(uuid, numeric) TO authenticated;

COMMENT ON TABLE wallet_transactions IS 'Ledger of every credit/debit to a seller''s in-app wallet (escrow releases, withdrawal requests/payouts).';
COMMENT ON COLUMN orders.dispute_status IS 'none | open | resolved_release | resolved_refund — set by open-dispute and admin-resolve-dispute edge functions.';
