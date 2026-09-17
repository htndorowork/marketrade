-- ============================================================
-- Escrow checkout (TradeSafe) + delivery (Pargo) migration
-- Run in the MARKETPLACE Supabase SQL Editor, project kqsqtasykdtpdrkqyaxp
--
-- NOTE: this block is now already included in COMPLETE_SETUP.sql (with
-- the buyer_cancel_order / release_escrow_internal fixes from
-- escrow_system_fixes.sql applied there too). Only run this file
-- standalone against a database that ran an older COMPLETE_SETUP.sql
-- (or the base setup.sql) before this existed — a fresh setup should
-- just run COMPLETE_SETUP.sql and skip this file.
--
-- Replaces the old "place_order reveals WhatsApp, you two sort out
-- payment yourselves" flow with a real paid checkout:
--   1. Buyer pays (Card / Ozow / SnapScan / RCS) into TradeSafe escrow.
--   2. Buyer picks a delivery method: in-person handover, or Pargo.
--   3. TradeSafe only releases the money into the seller's wallet once
--      the buyer enters the order's Collection PIN at handover, OR
--      24 hours pass after Pargo confirms delivery with no dispute.
--
-- This migration only touches the database. It does not talk to
-- TradeSafe or Pargo itself — that happens in the Edge Functions under
-- supabase-functions/ (tradesafe-checkout, tradesafe-webhook,
-- pargo-points, pargo-shipment, release-expired-escrows), which call
-- these tables/functions using the service role key.
-- ============================================================

-- ---------- orders: escrow + delivery fields ----------
ALTER TABLE orders ADD COLUMN IF NOT EXISTS amount numeric;                       -- total price actually charged (price at time of order × quantity)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'unpaid'; -- unpaid | paid | failed | refunded
ALTER TABLE orders ADD COLUMN IF NOT EXISTS escrow_status text DEFAULT 'none';    -- none | held | released | refunded | disputed
ALTER TABLE orders ADD COLUMN IF NOT EXISTS collection_pin text;                  -- 6-digit PIN, generated once payment clears
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_method text DEFAULT 'pickup';-- pickup (in-person handover) | pargo
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pargo_point_id text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pargo_point_name text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pargo_waybill_id text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at timestamp;               -- set when Pargo confirms drop-off at destination point
ALTER TABLE orders ADD COLUMN IF NOT EXISTS escrow_released_at timestamp;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_opened_at timestamp;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_reason text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tradesafe_transaction_id text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tradesafe_allocation_id text;

-- ---------- profiles: wallet balances ----------
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS wallet_balance numeric DEFAULT 0;   -- released, withdrawable funds
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS wallet_pending numeric DEFAULT 0;   -- held in escrow, not released yet (display only, not a real balance)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS tradesafe_token_id text;            -- the seller's TradeSafe "token" (their tokenised banking/user record — see tokenCreate in TradeSafe's docs)

-- ---------- wallet ledger ----------
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  seller_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  amount numeric NOT NULL,               -- positive = credit (escrow release), negative = debit (withdrawal)
  type text NOT NULL,                    -- escrow_release | withdrawal_requested | withdrawal_paid | adjustment
  status text DEFAULT 'completed',       -- completed | pending | failed
  note text,
  created_at timestamp DEFAULT now()
);
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "wallet_read_own" ON wallet_transactions;
CREATE POLICY "wallet_read_own" ON wallet_transactions
  FOR SELECT USING (
    auth.uid() = seller_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );
-- No direct INSERT/UPDATE policy for regular users — all writes go through
-- the SECURITY DEFINER functions below (or the service-role Edge Functions),
-- never straight from client code, so a buyer/seller can't credit themselves.

-- ============================================================
-- place_order_paid: like the old place_order, but leaves the order
-- unpaid/unheld until the TradeSafe webhook confirms funds cleared.
-- Called by the client at the *start* of checkout, before redirecting
-- to TradeSafe's hosted payment page.
-- ============================================================
CREATE OR REPLACE FUNCTION public.place_order_paid(
  p_listing_id uuid,
  p_quantity integer,
  p_delivery_method text,
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
  v_amount numeric;
BEGIN
  IF v_buyer IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_quantity IS NULL OR p_quantity < 1 THEN RAISE EXCEPTION 'Invalid quantity'; END IF;
  IF p_delivery_method NOT IN ('pickup','pargo') THEN RAISE EXCEPTION 'Invalid delivery method'; END IF;
  IF p_delivery_method = 'pargo' AND (p_pargo_point_id IS NULL OR btrim(p_pargo_point_id) = '') THEN
    RAISE EXCEPTION 'Select a Pargo pickup point';
  END IF;

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

  v_unit_price := CASE WHEN COALESCE(v_listing.discount_percent,0) > 0
    THEN ROUND(v_listing.price * (1 - v_listing.discount_percent / 100.0))
    ELSE v_listing.price END;
  v_amount := v_unit_price * p_quantity;

  -- Reserve stock immediately so two buyers can't both "win" it while one
  -- is off paying. If payment fails/expires, release-expired-escrows (or
  -- the tradesafe-webhook failure handler) puts the stock back.
  UPDATE listings SET quantity = quantity - p_quantity WHERE id = v_listing.id;

  INSERT INTO orders (
    listing_id, seller_id, buyer_id, buyer_name, buyer_whatsapp, quantity, status,
    amount, payment_status, escrow_status, delivery_method, pargo_point_id, pargo_point_name
  ) VALUES (
    v_listing.id, v_listing.seller_id, v_buyer, v_buyer_p.full_name, v_buyer_p.whatsapp, p_quantity, 'confirmed',
    v_amount, 'unpaid', 'none', p_delivery_method, p_pargo_point_id, p_pargo_point_name
  ) RETURNING id INTO v_order_id;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'amount', v_amount,
    'listing_title', v_listing.title,
    'seller_id', v_seller.id,
    'seller_name', COALESCE(v_seller.full_name, 'Seller'),
    'seller_tradesafe_token', v_seller.tradesafe_token_id,
    'buyer_email', v_buyer_p.full_name -- placeholder; edge function pulls the real auth email via service role
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.place_order_paid(uuid, integer, text, text, text) TO authenticated;

-- ============================================================
-- mark_order_paid: called ONLY by the tradesafe-webhook Edge Function
-- (service role — never exposed to the client) once TradeSafe confirms
-- the deposit cleared. Generates the Collection PIN and puts the order
-- into escrow.
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_order_paid(
  p_order_id uuid,
  p_tradesafe_transaction_id text,
  p_tradesafe_allocation_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pin text;
BEGIN
  v_pin := lpad(floor(random() * 1000000)::text, 6, '0');
  UPDATE orders SET
    payment_status = 'paid',
    escrow_status = 'held',
    collection_pin = v_pin,
    tradesafe_transaction_id = p_tradesafe_transaction_id,
    tradesafe_allocation_id = COALESCE(p_tradesafe_allocation_id, tradesafe_allocation_id)
  WHERE id = p_order_id AND payment_status = 'unpaid';
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found or already processed'; END IF;
  RETURN jsonb_build_object('order_id', p_order_id, 'collection_pin', v_pin);
END;
$$;
-- Intentionally NOT granted to `authenticated` — only the service role
-- (used by the Edge Function) may call this.

-- ============================================================
-- mark_order_payment_failed: called by tradesafe-webhook on a failed/
-- cancelled/expired deposit. Restocks the listing.
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_order_payment_failed(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_order orders%ROWTYPE;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_order.payment_status <> 'unpaid' THEN RETURN; END IF;
  UPDATE orders SET payment_status = 'failed', status = 'cancelled' WHERE id = p_order_id;
  UPDATE listings SET quantity = quantity + v_order.quantity WHERE id = v_order.listing_id;
END;
$$;

-- ============================================================
-- pargo_mark_delivered: called by the pargo-shipment webhook once
-- Pargo confirms the parcel reached the destination point. Starts the
-- 24-hour auto-release clock.
-- ============================================================
CREATE OR REPLACE FUNCTION public.pargo_mark_delivered(p_order_id uuid, p_waybill_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE orders SET delivered_at = now(), pargo_waybill_id = COALESCE(p_waybill_id, pargo_waybill_id)
  WHERE id = p_order_id AND escrow_status = 'held' AND delivered_at IS NULL;
END;
$$;

-- ============================================================
-- release_escrow_internal: shared release logic — credits the seller's
-- wallet and flips the order to released. Used by both the PIN-confirm
-- path and the 24h auto-release cron job.
-- NOTE: this only updates the marketplace's own ledger. The actual bank
-- payout instruction to TradeSafe (allocationAcceptDelivery mutation)
-- must be fired by the Edge Function alongside/after this call.
-- ============================================================
CREATE OR REPLACE FUNCTION public.release_escrow_internal(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_order orders%ROWTYPE;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF v_order.escrow_status <> 'held' THEN RETURN; END IF; -- already released/disputed/refunded — no-op

  UPDATE orders SET escrow_status = 'released', escrow_released_at = now() WHERE id = p_order_id;
  UPDATE profiles SET wallet_balance = COALESCE(wallet_balance,0) + v_order.amount WHERE id = v_order.seller_id;
  INSERT INTO wallet_transactions (seller_id, order_id, amount, type, status, note)
  VALUES (v_order.seller_id, v_order.id, v_order.amount, 'escrow_release', 'completed', 'Released for order '||v_order.id);
END;
$$;

-- ============================================================
-- confirm_handover_pin: the SELLER runs this at in-person handover once
-- the buyer reads them the Collection PIN.
-- ============================================================
CREATE OR REPLACE FUNCTION public.confirm_handover_pin(p_order_id uuid, p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_order orders%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF v_order.seller_id <> auth.uid() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF v_order.escrow_status <> 'held' THEN RAISE EXCEPTION 'This order isn''t awaiting handover'; END IF;
  IF v_order.collection_pin IS NULL OR p_pin IS NULL OR btrim(p_pin) <> v_order.collection_pin THEN
    RAISE EXCEPTION 'Incorrect PIN';
  END IF;

  PERFORM public.release_escrow_internal(p_order_id);
  RETURN jsonb_build_object('order_id', p_order_id, 'released', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.confirm_handover_pin(uuid, text) TO authenticated;

-- ============================================================
-- open_dispute: the BUYER raises a dispute any time while escrow_status
-- = 'held', before it releases. Freezes auto-release.
-- ============================================================
CREATE OR REPLACE FUNCTION public.open_dispute(p_order_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_order orders%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF v_order.buyer_id <> auth.uid() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF v_order.escrow_status <> 'held' THEN RAISE EXCEPTION 'This order can''t be disputed right now'; END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN RAISE EXCEPTION 'Add a reason'; END IF;

  UPDATE orders SET escrow_status = 'disputed', dispute_opened_at = now(), dispute_reason = p_reason
  WHERE id = p_order_id;
  -- TODO: notify an admin (reuse the existing `reports` table / notifications
  -- trigger — see growth_and_safety_migration.sql) so a human resolves it in
  -- TradeSafe per the dispute flow in their docs.
END;
$$;
GRANT EXECUTE ON FUNCTION public.open_dispute(uuid, text) TO authenticated;

-- ============================================================
-- release_expired_escrows: run on a schedule (pg_cron, every 15 min —
-- see the block at the bottom of this file) by the service role.
-- Auto-releases any Pargo order that was marked delivered 24h+ ago and
-- was never disputed.
-- ============================================================
CREATE OR REPLACE FUNCTION public.release_expired_escrows()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid; v_count integer := 0;
BEGIN
  FOR v_id IN
    SELECT id FROM orders
    WHERE escrow_status = 'held'
      AND delivery_method = 'pargo'
      AND delivered_at IS NOT NULL
      AND delivered_at <= now() - interval '24 hours'
  LOOP
    PERFORM public.release_escrow_internal(v_id);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- ============================================================
-- request_withdrawal: seller cashes out their wallet_balance. Marks a
-- pending ledger row — an Edge Function/admin then actually triggers the
-- TradeSafe payout and calls mark_withdrawal_paid.
-- ============================================================
CREATE OR REPLACE FUNCTION public.request_withdrawal(p_amount numeric)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_seller uuid := auth.uid(); v_balance numeric; v_id uuid;
BEGIN
  IF v_seller IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Invalid amount'; END IF;
  SELECT wallet_balance INTO v_balance FROM profiles WHERE id = v_seller FOR UPDATE;
  IF COALESCE(v_balance,0) < p_amount THEN RAISE EXCEPTION 'Amount exceeds your wallet balance'; END IF;

  UPDATE profiles SET wallet_balance = wallet_balance - p_amount WHERE id = v_seller;
  INSERT INTO wallet_transactions (seller_id, amount, type, status, note)
  VALUES (v_seller, -p_amount, 'withdrawal_requested', 'pending', 'Withdrawal requested')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(numeric) TO authenticated;

-- Admin marks a withdrawal as actually paid out (after triggering the
-- TradeSafe/bank payout by hand or via an admin Edge Function).
CREATE OR REPLACE FUNCTION public.admin_mark_withdrawal_paid(p_tx_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  UPDATE wallet_transactions SET status = 'completed', type = 'withdrawal_paid' WHERE id = p_tx_id AND status = 'pending';
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_mark_withdrawal_paid(uuid) TO authenticated;

-- ============================================================
-- Schedule the 24h auto-release check. Requires the pg_cron extension
-- (Database → Extensions → enable "pg_cron" in the Supabase dashboard
-- first, then run this once).
-- ============================================================
-- SELECT cron.schedule('release-expired-escrows', '*/15 * * * *', $$SELECT public.release_expired_escrows();$$);
