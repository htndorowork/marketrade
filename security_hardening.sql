-- ============================================================
-- SECURITY HARDENING — run in MARKETPLACE Supabase SQL Editor
-- Project: kqsqtasykdtpdrkqyaxp
-- Safe to re-run.
-- ============================================================

-- ---------- 1) Protect privileged profile columns ----------
-- Users may update their own profile, but NOT is_admin / subscription / is_blocked.
-- Admin RPCs and service_role set app.bypass_profile_guard = on for the transaction.

CREATE OR REPLACE FUNCTION public.protect_profile_privileges()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF coalesce(auth.role(), '') = 'service_role'
     OR current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;
  IF current_setting('app.bypass_profile_guard', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin
     OR NEW.subscription_paid_until IS DISTINCT FROM OLD.subscription_paid_until
     OR NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
    RAISE EXCEPTION 'Cannot modify privileged profile fields';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_privileges ON profiles;
CREATE TRIGGER trg_protect_profile_privileges
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privileges();

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE id = auth.uid()), false);
$$;

-- ---------- 2) Admin RPCs ----------

CREATE OR REPLACE FUNCTION public.admin_extend_subscription(p_seller_id uuid, p_days integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start date;
  v_until date;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_days IS NULL OR p_days NOT IN (7, 30) THEN RAISE EXCEPTION 'Invalid plan days'; END IF;

  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  SELECT CASE
    WHEN subscription_paid_until IS NOT NULL AND subscription_paid_until > CURRENT_DATE
      THEN subscription_paid_until
    ELSE CURRENT_DATE
  END INTO v_start
  FROM profiles WHERE id = p_seller_id;

  IF v_start IS NULL THEN RAISE EXCEPTION 'Seller not found'; END IF;
  v_until := v_start + p_days;

  UPDATE profiles
  SET subscription_paid_until = v_until, is_blocked = false, role = 'seller'
  WHERE id = p_seller_id;

  INSERT INTO admin_audit_log (admin_id, action, target_id, details)
  VALUES (auth.uid(), 'mark_paid', p_seller_id, 'Extended subscription '||p_days||' days');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_blocked(p_seller_id uuid, p_blocked boolean, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  PERFORM set_config('app.bypass_profile_guard', 'on', true);
  UPDATE profiles SET is_blocked = COALESCE(p_blocked, true) WHERE id = p_seller_id;
  INSERT INTO admin_audit_log (admin_id, action, target_id, details)
  VALUES (auth.uid(), CASE WHEN p_blocked THEN 'block_seller' ELSE 'unblock_seller' END, p_seller_id, COALESCE(p_reason, ''));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_role(p_user_id uuid, p_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_role NOT IN ('buyer', 'seller') THEN RAISE EXCEPTION 'Invalid role'; END IF;
  UPDATE profiles SET role = p_role WHERE id = p_user_id;
  INSERT INTO admin_audit_log (admin_id, action, target_id, details)
  VALUES (auth.uid(), 'change_role', p_user_id, 'Set role to '||p_role);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_is_admin(p_user_id uuid, p_is_admin boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_user_id = auth.uid() AND p_is_admin IS FALSE THEN
    RAISE EXCEPTION 'Cannot remove your own admin access';
  END IF;
  PERFORM set_config('app.bypass_profile_guard', 'on', true);
  UPDATE profiles SET is_admin = COALESCE(p_is_admin, false) WHERE id = p_user_id;
  INSERT INTO admin_audit_log (admin_id, action, target_id, details)
  VALUES (auth.uid(), 'toggle_admin', p_user_id, CASE WHEN p_is_admin THEN 'Granted admin' ELSE 'Removed admin' END);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_block_all_overdue()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n integer;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  PERFORM set_config('app.bypass_profile_guard', 'on', true);
  UPDATE profiles
  SET is_blocked = true
  WHERE role = 'seller'
    AND subscription_paid_until IS NOT NULL
    AND subscription_paid_until < CURRENT_DATE
    AND COALESCE(is_blocked, false) = false;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO admin_audit_log (admin_id, action, target_id, details)
  VALUES (auth.uid(), 'bulk_block_overdue', NULL, n||' sellers blocked');
  RETURN n;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_extend_subscription(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_blocked(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_is_admin(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_block_all_overdue() TO authenticated;

-- ---------- 3) Orders: auth required + atomic place + buyer cancel ----------

DROP POLICY IF EXISTS "orders_insert" ON orders;
CREATE POLICY "orders_insert" ON orders FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL AND auth.uid() = buyer_id
);

DROP POLICY IF EXISTS "orders_update" ON orders;
DROP POLICY IF EXISTS "orders_update_seller_admin" ON orders;
CREATE POLICY "orders_update_seller_admin" ON orders FOR UPDATE USING (
  auth.uid() = seller_id OR public.is_admin()
);

CREATE OR REPLACE FUNCTION public.place_order(p_listing_id uuid, p_quantity integer)
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
       AND NOT EXISTS (SELECT 1 FROM settings WHERE key = 'free_mode' AND value = 'true') THEN
      RAISE EXCEPTION 'Seller unavailable';
    END IF;
  END IF;

  INSERT INTO orders (listing_id, seller_id, buyer_id, buyer_name, buyer_whatsapp, quantity, status)
  VALUES (v_listing.id, v_listing.seller_id, v_buyer, v_buyer_p.full_name, v_buyer_p.whatsapp, p_quantity, 'confirmed')
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

CREATE OR REPLACE FUNCTION public.buyer_cancel_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order orders%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF v_order.buyer_id <> auth.uid() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF v_order.status <> 'confirmed' THEN RAISE EXCEPTION 'Only confirmed orders can be cancelled'; END IF;

  UPDATE orders SET status = 'cancelled' WHERE id = p_order_id;
  IF v_order.listing_id IS NOT NULL AND v_order.quantity IS NOT NULL THEN
    UPDATE listings SET quantity = quantity + v_order.quantity WHERE id = v_order.listing_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_listing_views(p_listing_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE listings SET view_count = COALESCE(view_count, 0) + 1 WHERE id = p_listing_id AND COALESCE(is_draft, false) = false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.place_order(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buyer_cancel_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_listing_views(uuid) TO authenticated, anon;

-- ---------- 4) Listings read: hide drafts from public ----------
DROP POLICY IF EXISTS "listings_read" ON listings;
CREATE POLICY "listings_read" ON listings FOR SELECT USING (
  COALESCE(is_draft, false) = false
  OR auth.uid() = seller_id
  OR public.is_admin()
);

-- ---------- 5) Storage: authenticated uploads only, own folder ----------
DROP POLICY IF EXISTS "Anyone can upload images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload listing images" ON storage.objects;
DROP POLICY IF EXISTS "Public read listing images" ON storage.objects;

CREATE POLICY "Authenticated upload listing images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'listing-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Public read listing images"
ON storage.objects FOR SELECT
USING (bucket_id = 'listing-images');

-- Sellers may delete their own uploaded objects
DROP POLICY IF EXISTS "Owner delete listing images" ON storage.objects;
CREATE POLICY "Owner delete listing images"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'listing-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------- 6) Messages: parties may only flip is_read (not rewrite content) ----------
CREATE OR REPLACE FUNCTION public.protect_message_content()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.content IS DISTINCT FROM OLD.content
     OR NEW.sender_id IS DISTINCT FROM OLD.sender_id
     OR NEW.buyer_id IS DISTINCT FROM OLD.buyer_id
     OR NEW.seller_id IS DISTINCT FROM OLD.seller_id
     OR NEW.listing_id IS DISTINCT FROM OLD.listing_id THEN
    RAISE EXCEPTION 'Cannot modify message content';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_message_content ON messages;
CREATE TRIGGER trg_protect_message_content
  BEFORE UPDATE ON messages
  FOR EACH ROW EXECUTE FUNCTION public.protect_message_content();

-- ---------- 7) Subscription payments table (if not already applied) ----------
CREATE TABLE IF NOT EXISTS subscription_payments (
  id text PRIMARY KEY,
  seller_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  plan text NOT NULL,
  amount numeric NOT NULL,
  days integer NOT NULL,
  status text DEFAULT 'pending',
  pf_payment_id text,
  created_at timestamp DEFAULT now(),
  paid_at timestamp
);

ALTER TABLE subscription_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sub_pay_insert_own" ON subscription_payments;
DROP POLICY IF EXISTS "sub_pay_read_own" ON subscription_payments;
DROP POLICY IF EXISTS "sub_pay_admin" ON subscription_payments;

CREATE POLICY "sub_pay_insert_own" ON subscription_payments
  FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "sub_pay_read_own" ON subscription_payments
  FOR SELECT USING (
    auth.uid() = seller_id OR public.is_admin()
  );
CREATE POLICY "sub_pay_admin" ON subscription_payments
  FOR ALL USING (public.is_admin());
