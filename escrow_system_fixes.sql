-- ============================================================
-- escrow_system_fixes.sql
--
-- These two fixes are now already folded into COMPLETE_SETUP.sql
-- (and applied there for any fresh install) — buyer_cancel_order and
-- release_escrow_internal in that file already have them.
--
-- Only run this file standalone if your database already ran the
-- original escrow_system_migration.sql (or an older COMPLETE_SETUP.sql
-- from before this fix existed) and you just need to patch those two
-- functions in place, without re-running the rest of the migration.
--
-- Three gaps found while wiring the frontend to the new TradeSafe +
-- Pargo escrow system:
--
-- 1) buyer_cancel_order let a buyer cancel ANY 'confirmed' order,
--    including one that's already been paid into escrow. Cancelling
--    just restocks the listing and marks the order 'cancelled' — it
--    doesn't touch TradeSafe at all, so the buyer's money would be
--    stuck in escrow with no order left to release it against. Once
--    money has moved, cancellation needs to go through open_dispute
--    instead (frontend now only shows "Cancel" while payment_status
--    is still 'unpaid').
--
-- 2) release_escrow_internal (called by both confirm_handover_pin and
--    the Pargo 24h auto-release cron) only ever updated escrow_status.
--    For pickup orders the frontend also flips orders.status to
--    'completed' itself right after confirm_handover_pin succeeds —
--    but there's no equivalent client-side step for a Pargo order
--    auto-released by the cron job, so those orders would sit at
--    status='confirmed' forever even once paid out. Moving this into
--    release_escrow_internal itself covers both paths consistently.
-- ============================================================

CREATE OR REPLACE FUNCTION public.buyer_cancel_order(p_order_id uuid)
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
  IF v_order.status <> 'confirmed' THEN RAISE EXCEPTION 'This order can''t be cancelled'; END IF;
  IF COALESCE(v_order.payment_status,'unpaid') <> 'unpaid' THEN
    RAISE EXCEPTION 'This order has already been paid — open a dispute instead of cancelling';
  END IF;

  UPDATE orders SET status = 'cancelled' WHERE id = p_order_id;
  UPDATE listings SET quantity = quantity + v_order.quantity WHERE id = v_order.listing_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.buyer_cancel_order(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.release_escrow_internal(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_order orders%ROWTYPE;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_order.escrow_status <> 'held' THEN RETURN; END IF; -- already released/disputed/refunded — no-op

  UPDATE orders SET escrow_status = 'released', escrow_released_at = now(), status = 'completed' WHERE id = p_order_id;
  UPDATE profiles SET wallet_balance = COALESCE(wallet_balance,0) + v_order.amount WHERE id = v_order.seller_id;
  INSERT INTO wallet_transactions (seller_id, order_id, amount, type, status, note)
  VALUES (v_order.seller_id, v_order.id, v_order.amount, 'escrow_release', 'completed', 'Released for order '||v_order.id);
END;
$$;

-- ============================================================
-- 3) There was no way to ever resolve a dispute once open_dispute
--    froze an order — escrow_status just sat at 'disputed' forever,
--    with no path back to either the seller or the buyer.
--    admin_resolve_dispute gives an admin exactly two outcomes:
--      'release' — side with the seller: reuses the same safe,
--                   already-audited release_escrow_internal path.
--      'refund'  — side with the buyer: marks the order refunded
--                   in our own records. This does NOT call TradeSafe's
--                   refund API — I don't have your TradeSafe API
--                   details verified, and guessing at a real money
--                   -moving refund call is exactly the kind of thing
--                   that shouldn't be faked. This flags the order so
--                   an admin can process the actual refund through
--                   TradeSafe's own dashboard/support, and records
--                   that it was flagged.
-- ============================================================
ALTER TABLE orders ADD COLUMN IF NOT EXISTS admin_note text;

CREATE OR REPLACE FUNCTION public.admin_resolve_dispute(p_order_id uuid, p_resolution text, p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_order orders%ROWTYPE; v_is_admin boolean;
BEGIN
  SELECT COALESCE(is_admin,false) INTO v_is_admin FROM profiles WHERE id = auth.uid();
  IF NOT COALESCE(v_is_admin,false) THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_resolution NOT IN ('release','refund') THEN RAISE EXCEPTION 'Invalid resolution'; END IF;

  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF v_order.escrow_status <> 'disputed' THEN RAISE EXCEPTION 'This order isn''t under dispute'; END IF;

  IF p_resolution = 'release' THEN
    UPDATE orders SET escrow_status = 'held', admin_note = p_note WHERE id = p_order_id; -- back to 'held' so release_escrow_internal's guard passes
    PERFORM release_escrow_internal(p_order_id);
  ELSE
    UPDATE orders SET escrow_status = 'refunded', payment_status = 'refunded', status = 'cancelled', admin_note = p_note WHERE id = p_order_id;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_resolve_dispute(uuid, text, text) TO authenticated;
