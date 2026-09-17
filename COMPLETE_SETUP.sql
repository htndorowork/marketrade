-- ============================================================
-- STUDENT MARKETPLACE — COMPLETE DATABASE SETUP (ALL-IN-ONE)
-- Run this single file in the Supabase SQL Editor for a fresh
-- project, or re-run it any time to bring an existing project
-- fully up to date — every section below is idempotent (safe
-- to run more than once, including on a database that already
-- has some or all of this applied).
--
-- This file is the merged, ordered combination of every
-- individual migration file in this project. Run in this exact
-- order because later sections depend on tables/columns created
-- by earlier ones.
-- ============================================================

-- ############################################################
-- # 1. CORE SETUP (was: setup.sql)
-- ############################################################

-- ============================================================
-- STUDENT MARKETPLACE (NWU) — FULL DATABASE SETUP
-- Run this entire file in YOUR Supabase project's SQL Editor (New Query)
-- ============================================================

-- ===================== TABLES =====================

-- Profiles (users)
CREATE TABLE IF NOT EXISTS profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE,
  full_name text,
  whatsapp text,
  residence text,
  role text DEFAULT 'buyer',
  is_admin boolean DEFAULT false,
  store_name text,
  store_bio text,
  store_logo_url text,
  store_link text,
  university text,
  delivery_campuses text[] DEFAULT '{}',
  deliver_all_campuses boolean DEFAULT false,
  subscription_paid_until date,
  is_blocked boolean DEFAULT false,
  created_at timestamp DEFAULT now(),
  PRIMARY KEY (id)
);

-- Safe to re-run
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS store_name text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS store_bio text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS store_logo_url text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS store_link text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS university text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS delivery_campuses text[] DEFAULT '{}';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_campuses boolean DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_paid_until date;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_blocked boolean DEFAULT false;
-- Institution/campus support (universities, TVET colleges, private higher-ed institutions)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS institution_type text; -- 'university' | 'tvet' | 'private' — buyer's own institution type
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS campus text; -- buyer's own campus (university/institution name reuses the existing `university` column)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_universities boolean DEFAULT false; -- seller sells to every university, any campus
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_tvet boolean DEFAULT false; -- seller sells to every TVET college, any campus
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_private boolean DEFAULT false; -- seller sells to every private higher-ed institution, any campus
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS seller_institutions jsonb DEFAULT '[]'::jsonb; -- [{type,name,campuses:[...]}, ...] specific institutions a seller delivers to (beyond the "all X" toggles above)

-- Listings
CREATE TABLE IF NOT EXISTS listings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  seller_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  price numeric NOT NULL,
  category text NOT NULL,
  discount_percent numeric DEFAULT 0,
  quantity integer DEFAULT 1,
  image_url text,
  image_url_2 text,
  image_url_3 text,
  image_url_4 text,
  image_url_5 text,
  image_url_6 text,
  condition text,
  is_negotiable boolean DEFAULT false,
  delivery_fee numeric DEFAULT 0,
  is_draft boolean DEFAULT false,
  is_sold boolean DEFAULT false,
  is_available boolean DEFAULT true,
  textbook_year text,
  textbook_subject text,
  electronics_subcategory text,
  clothing_subcategory text,
  food_subcategory text,
  beauty_subcategory text,
  wigs_subcategory text,
  perfumes_subcategory text,
  tutoring_subcategory text,
  accommodation_subcategory text,
  transport_subcategory text,
  services_subcategory text,
  stationary_subcategory text,
  appliances_subcategory text,
  rentals_subcategory text,
  furniture_subcategory text,
  utensils_subcategory text,
  jewellery_subcategory text,
  bags_subcategory text,
  toys_subcategory text,
  pets_subcategory text,
  tools_subcategory text,
  snacks_subcategory text,
  sports_subcategory text,
  books_subcategory text,
  music_subcategory text,
  cameras_subcategory text,
  gaming_subcategory text,
  tickets_subcategory text,
  events_subcategory text,
  plants_subcategory text,
  decor_subcategory text,
  baby_subcategory text,
  data_subcategory text,
  health_subcategory text,
  career_subcategory text,
  created_at timestamp DEFAULT now()
);

-- Safe to re-run: adds the columns above if this table already existed
ALTER TABLE listings ADD COLUMN IF NOT EXISTS textbook_year text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS textbook_subject text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS electronics_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS clothing_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS food_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS beauty_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS wigs_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS perfumes_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS tutoring_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS accommodation_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS transport_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS services_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS stationary_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS appliances_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS rentals_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS furniture_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS utensils_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS jewellery_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS bags_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS toys_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS pets_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS tools_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS snacks_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS sports_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS books_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS music_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS cameras_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS gaming_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS tickets_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS events_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS plants_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS decor_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS baby_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS data_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS health_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS career_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS image_url_4 text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS image_url_5 text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS image_url_6 text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS condition text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS is_negotiable boolean DEFAULT false;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS delivery_fee numeric DEFAULT 0;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS is_draft boolean DEFAULT false;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS is_sold boolean DEFAULT false;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS renewed_at timestamp DEFAULT now();
ALTER TABLE listings ADD COLUMN IF NOT EXISTS view_count integer DEFAULT 0;

-- Orders
CREATE TABLE IF NOT EXISTS orders (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id uuid,
  seller_id uuid,
  buyer_id uuid,
  buyer_name text,
  buyer_whatsapp text,
  quantity integer DEFAULT 1,
  status text DEFAULT 'confirmed',
  created_at timestamp DEFAULT now()
);

-- Cart items (optional persistence)
CREATE TABLE IF NOT EXISTS cart_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  buyer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  quantity integer DEFAULT 1,
  created_at timestamp DEFAULT now()
);

-- Reviews (one per completed order, buyer rates the seller)
CREATE TABLE IF NOT EXISTS reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id uuid UNIQUE,
  seller_id uuid,
  buyer_id uuid,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text,
  dispute_status text DEFAULT 'none',
  dispute_reason text,
  created_at timestamp DEFAULT now()
);
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS dispute_status text DEFAULT 'none';
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS dispute_reason text;

-- Buyer reviews (one per completed order, seller rates the buyer)
CREATE TABLE IF NOT EXISTS buyer_reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id uuid UNIQUE,
  seller_id uuid,
  buyer_id uuid,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text,
  created_at timestamp DEFAULT now()
);

-- Favorites / wishlist
CREATE TABLE IF NOT EXISTS favorites (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  listing_id uuid,
  created_at timestamp DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

-- Reports (a listing or a seller/user)
CREATE TABLE IF NOT EXISTS reports (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id uuid,
  listing_id uuid,
  reported_user_id uuid,
  order_id uuid,
  reason text NOT NULL,
  details text,
  status text DEFAULT 'open',
  created_at timestamp DEFAULT now()
);

-- Messages (in-app chat between a buyer and seller, optionally tied to a listing)
CREATE TABLE IF NOT EXISTS messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id uuid,
  buyer_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamp DEFAULT now()
);

-- Notifications (back-in-stock, price-drop alerts on favorited listings)
CREATE TABLE IF NOT EXISTS notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  type text NOT NULL,
  message text NOT NULL,
  listing_id uuid,
  is_read boolean DEFAULT false,
  created_at timestamp DEFAULT now()
);

-- Admin audit log
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id uuid,
  action text NOT NULL,
  target_id uuid,
  details text,
  created_at timestamp DEFAULT now()
);

-- Settings (paywall control)
CREATE TABLE IF NOT EXISTS settings (
  key text PRIMARY KEY,
  value text
);
INSERT INTO settings (key, value) VALUES ('paywall_active', 'false')
ON CONFLICT (key) DO NOTHING;

-- ===================== FOREIGN KEYS WITH SAFE DELETE =====================

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_seller_id_fkey;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_buyer_id_fkey;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_listing_id_fkey;

ALTER TABLE orders
ADD CONSTRAINT orders_seller_id_fkey
FOREIGN KEY (seller_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE orders
ADD CONSTRAINT orders_buyer_id_fkey
FOREIGN KEY (buyer_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE orders
ADD CONSTRAINT orders_listing_id_fkey
FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE SET NULL;

ALTER TABLE listings DROP CONSTRAINT IF EXISTS listings_seller_id_fkey;
ALTER TABLE listings
ADD CONSTRAINT listings_seller_id_fkey
FOREIGN KEY (seller_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_order_id_fkey;
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_seller_id_fkey;
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_buyer_id_fkey;

ALTER TABLE reviews
ADD CONSTRAINT reviews_order_id_fkey
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

ALTER TABLE reviews
ADD CONSTRAINT reviews_seller_id_fkey
FOREIGN KEY (seller_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE reviews
ADD CONSTRAINT reviews_buyer_id_fkey
FOREIGN KEY (buyer_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE buyer_reviews DROP CONSTRAINT IF EXISTS buyer_reviews_order_id_fkey;
ALTER TABLE buyer_reviews DROP CONSTRAINT IF EXISTS buyer_reviews_seller_id_fkey;
ALTER TABLE buyer_reviews DROP CONSTRAINT IF EXISTS buyer_reviews_buyer_id_fkey;
ALTER TABLE buyer_reviews ADD CONSTRAINT buyer_reviews_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;
ALTER TABLE buyer_reviews ADD CONSTRAINT buyer_reviews_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE buyer_reviews ADD CONSTRAINT buyer_reviews_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE favorites DROP CONSTRAINT IF EXISTS favorites_user_id_fkey;
ALTER TABLE favorites DROP CONSTRAINT IF EXISTS favorites_listing_id_fkey;
ALTER TABLE favorites ADD CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE favorites ADD CONSTRAINT favorites_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE;

ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_listing_id_fkey;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reported_user_id_fkey;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS order_id uuid;
ALTER TABLE reports ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE reports ADD CONSTRAINT reports_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE;
ALTER TABLE reports ADD CONSTRAINT reports_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_listing_id_fkey;
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_buyer_id_fkey;
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_seller_id_fkey;
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;
ALTER TABLE messages ADD CONSTRAINT messages_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE SET NULL;
ALTER TABLE messages ADD CONSTRAINT messages_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE messages ADD CONSTRAINT messages_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE messages ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_listing_id_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE notifications ADD CONSTRAINT notifications_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE;

ALTER TABLE admin_audit_log DROP CONSTRAINT IF EXISTS admin_audit_log_admin_id_fkey;
ALTER TABLE admin_audit_log ADD CONSTRAINT admin_audit_log_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES profiles(id) ON DELETE SET NULL;

-- ===================== ROW LEVEL SECURITY =====================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE buyer_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop any old policies (safe if they don't exist)
DROP POLICY IF EXISTS "profiles_read" ON profiles;
DROP POLICY IF EXISTS "profiles_insert" ON profiles;
DROP POLICY IF EXISTS "profiles_update" ON profiles;
DROP POLICY IF EXISTS "profiles_delete_admin" ON profiles;

DROP POLICY IF EXISTS "listings_read" ON listings;
DROP POLICY IF EXISTS "listings_insert" ON listings;
DROP POLICY IF EXISTS "listings_update_seller" ON listings;
DROP POLICY IF EXISTS "listings_update_admin" ON listings;
DROP POLICY IF EXISTS "listings_delete_seller" ON listings;
DROP POLICY IF EXISTS "listings_delete_admin" ON listings;

DROP POLICY IF EXISTS "Anyone can insert orders" ON orders;
DROP POLICY IF EXISTS "Sellers can read own orders" ON orders;
DROP POLICY IF EXISTS "Buyers can read own orders" ON orders;
DROP POLICY IF EXISTS "orders_insert" ON orders;
DROP POLICY IF EXISTS "orders_read" ON orders;
DROP POLICY IF EXISTS "orders_update" ON orders;

DROP POLICY IF EXISTS "Users manage own cart" ON cart_items;
DROP POLICY IF EXISTS "cart_manage" ON cart_items;

DROP POLICY IF EXISTS "settings_read" ON settings;
DROP POLICY IF EXISTS "settings_write" ON settings;

DROP POLICY IF EXISTS "reviews_read" ON reviews;
DROP POLICY IF EXISTS "reviews_insert" ON reviews;

DROP POLICY IF EXISTS "buyer_reviews_read" ON buyer_reviews;
DROP POLICY IF EXISTS "buyer_reviews_insert" ON buyer_reviews;

DROP POLICY IF EXISTS "favorites_manage" ON favorites;

DROP POLICY IF EXISTS "reports_insert" ON reports;
DROP POLICY IF EXISTS "reports_read_admin" ON reports;
DROP POLICY IF EXISTS "reports_update_admin" ON reports;

DROP POLICY IF EXISTS "audit_log_read_admin" ON admin_audit_log;
DROP POLICY IF EXISTS "audit_log_insert_admin" ON admin_audit_log;

DROP POLICY IF EXISTS "messages_read" ON messages;
DROP POLICY IF EXISTS "messages_insert" ON messages;
DROP POLICY IF EXISTS "messages_update" ON messages;

DROP POLICY IF EXISTS "notifications_read" ON notifications;
DROP POLICY IF EXISTS "notifications_update" ON notifications;

DROP POLICY IF EXISTS "reviews_update_dispute" ON reviews;

-- PROFILES policies
DROP POLICY IF EXISTS "profiles_read" ON profiles;
CREATE POLICY "profiles_read" ON profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "profiles_insert" ON profiles;
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_update" ON profiles;
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_delete_admin" ON profiles;
CREATE POLICY "profiles_delete_admin" ON profiles FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- LISTINGS policies
DROP POLICY IF EXISTS "listings_read" ON listings;
CREATE POLICY "listings_read" ON listings FOR SELECT USING (true);
DROP POLICY IF EXISTS "listings_insert" ON listings;
CREATE POLICY "listings_insert" ON listings FOR INSERT WITH CHECK (
  auth.uid() = seller_id AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND COALESCE(is_blocked,false) = false
    AND (
      COALESCE(is_admin,false) = true
      OR (subscription_paid_until IS NOT NULL AND subscription_paid_until >= CURRENT_DATE)
    )
  )
);
DROP POLICY IF EXISTS "listings_update_seller" ON listings;
CREATE POLICY "listings_update_seller" ON listings FOR UPDATE USING (
  auth.uid() = seller_id
) WITH CHECK (
  auth.uid() = seller_id
);
DROP POLICY IF EXISTS "listings_update_admin" ON listings;
CREATE POLICY "listings_update_admin" ON listings FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
DROP POLICY IF EXISTS "listings_delete_seller" ON listings;
CREATE POLICY "listings_delete_seller" ON listings FOR DELETE USING (auth.uid() = seller_id);
DROP POLICY IF EXISTS "listings_delete_admin" ON listings;
CREATE POLICY "listings_delete_admin" ON listings FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- ORDERS policies
DROP POLICY IF EXISTS "orders_insert" ON orders;
CREATE POLICY "orders_insert" ON orders FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "orders_read" ON orders;
CREATE POLICY "orders_read" ON orders FOR SELECT USING (
  auth.uid() = buyer_id OR auth.uid() = seller_id OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
DROP POLICY IF EXISTS "orders_update" ON orders;
CREATE POLICY "orders_update" ON orders FOR UPDATE USING (
  auth.uid() = seller_id OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- CART policies
DROP POLICY IF EXISTS "cart_manage" ON cart_items;
CREATE POLICY "cart_manage" ON cart_items
FOR ALL USING (auth.uid() = buyer_id) WITH CHECK (auth.uid() = buyer_id);

-- SETTINGS policies
DROP POLICY IF EXISTS "settings_read" ON settings;
CREATE POLICY "settings_read" ON settings FOR SELECT USING (true);
DROP POLICY IF EXISTS "settings_write" ON settings;
CREATE POLICY "settings_write" ON settings FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- REVIEWS policies
DROP POLICY IF EXISTS "reviews_read" ON reviews;
CREATE POLICY "reviews_read" ON reviews FOR SELECT USING (true);
DROP POLICY IF EXISTS "reviews_insert" ON reviews;
CREATE POLICY "reviews_insert" ON reviews FOR INSERT WITH CHECK (
  auth.uid() = buyer_id AND
  EXISTS (SELECT 1 FROM orders WHERE id = order_id AND buyer_id = auth.uid() AND status = 'completed')
);
DROP POLICY IF EXISTS "reviews_update_dispute" ON reviews;
CREATE POLICY "reviews_update_dispute" ON reviews FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);

-- BUYER_REVIEWS policies (seller rates the buyer)
DROP POLICY IF EXISTS "buyer_reviews_read" ON buyer_reviews;
CREATE POLICY "buyer_reviews_read" ON buyer_reviews FOR SELECT USING (true);
DROP POLICY IF EXISTS "buyer_reviews_insert" ON buyer_reviews;
CREATE POLICY "buyer_reviews_insert" ON buyer_reviews FOR INSERT WITH CHECK (
  auth.uid() = seller_id AND
  EXISTS (SELECT 1 FROM orders WHERE id = order_id AND seller_id = auth.uid() AND status = 'completed')
);

-- FAVORITES policies (fully private to the user)
DROP POLICY IF EXISTS "favorites_manage" ON favorites;
CREATE POLICY "favorites_manage" ON favorites FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- REPORTS policies
DROP POLICY IF EXISTS "reports_insert" ON reports;
CREATE POLICY "reports_insert" ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
DROP POLICY IF EXISTS "reports_read_admin" ON reports;
CREATE POLICY "reports_read_admin" ON reports FOR SELECT USING (
  auth.uid() = reporter_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
DROP POLICY IF EXISTS "reports_update_admin" ON reports;
CREATE POLICY "reports_update_admin" ON reports FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- ADMIN AUDIT LOG policies
DROP POLICY IF EXISTS "audit_log_read_admin" ON admin_audit_log;
CREATE POLICY "audit_log_read_admin" ON admin_audit_log FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
DROP POLICY IF EXISTS "audit_log_insert_admin" ON admin_audit_log;
CREATE POLICY "audit_log_insert_admin" ON admin_audit_log FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- MESSAGES policies
DROP POLICY IF EXISTS "messages_read" ON messages;
CREATE POLICY "messages_read" ON messages FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
);
DROP POLICY IF EXISTS "messages_update" ON messages;
CREATE POLICY "messages_update" ON messages FOR UPDATE USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

-- NOTIFICATIONS policies (inserted only by the trigger below, which bypasses RLS)
DROP POLICY IF EXISTS "notifications_read" ON notifications;
CREATE POLICY "notifications_read" ON notifications FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "notifications_update" ON notifications;
CREATE POLICY "notifications_update" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- ===================== AUTO-CREATE PROFILE ON SIGNUP =====================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, whatsapp)
  VALUES (new.id, '', '')
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===================== STORAGE BUCKET FOR IMAGES =====================
-- NOTE: Also create a bucket named "listing-images" manually:
-- Storage -> New bucket -> name: listing-images -> Public bucket: ON

DROP POLICY IF EXISTS "Anyone can upload images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view images" ON storage.objects;

CREATE POLICY "Anyone can upload images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'listing-images');

CREATE POLICY "Anyone can view images"
ON storage.objects FOR SELECT
USING (bucket_id = 'listing-images');

-- ===================== AUTO NOTIFICATIONS =====================
-- Automatically notifies everyone who favorited a listing when it comes
-- back in stock or drops in price. Runs server-side via a trigger, so it
-- works no matter which page/device changed the listing.

CREATE OR REPLACE FUNCTION notify_favoriters() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.quantity > 0 AND OLD.quantity = 0 THEN
    INSERT INTO notifications (user_id, type, message, listing_id)
    SELECT user_id, 'back_in_stock', NEW.title || ' is back in stock! 🎉', NEW.id
    FROM favorites WHERE listing_id = NEW.id;
  END IF;
  IF NEW.price < OLD.price THEN
    INSERT INTO notifications (user_id, type, message, listing_id)
    SELECT user_id, 'price_drop', NEW.title || ' just dropped to R' || NEW.price || '! 💸', NEW.id
    FROM favorites WHERE listing_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_favoriters ON listings;
CREATE TRIGGER trg_notify_favoriters AFTER UPDATE ON listings
FOR EACH ROW EXECUTE FUNCTION notify_favoriters();

-- ===================== ADMIN SETUP =====================
-- IMPORTANT: These two people must SIGN UP on the site FIRST
-- using these exact email addresses, THEN run this section again
-- to grant them admin access.

UPDATE profiles SET is_admin = true
WHERE id = (SELECT id FROM auth.users WHERE email = 'htndorowork@gmail.com');

-- ============================================================
-- DONE! After running this:
-- 1. Create the "listing-images" storage bucket (public) if not done
-- 2. Make sure both admin emails have signed up
-- 3. Re-run the ADMIN SETUP section above to confirm admin access
-- ============================================================

-- ############################################################
-- # 2. SECURITY HARDENING (was: security_hardening.sql)
-- ############################################################

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
  -- Once TradeSafe has actually taken the buyer's money into escrow,
  -- a plain cancel here would strand that payment with no order left to
  -- release it against — from that point on, cancellation has to go
  -- through open_dispute() instead (see the escrow block below).
  IF COALESCE(v_order.payment_status,'unpaid') <> 'unpaid' THEN
    RAISE EXCEPTION 'This order has already been paid — open a dispute instead of cancelling';
  END IF;

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

-- ============================================================
-- Escrow checkout (TradeSafe) + delivery (Pargo)
--
-- Replaces the old "place_order reveals WhatsApp, you two sort out
-- payment yourselves" flow (above) with a real paid checkout:
--   1. Buyer pays (Card / Ozow / SnapScan / RCS) into TradeSafe escrow.
--   2. Buyer picks a delivery method: in-person handover, or Pargo.
--   3. TradeSafe only releases the money into the seller's wallet once
--      the buyer enters the order's Collection PIN at handover, OR
--      24 hours pass after Pargo confirms delivery with no dispute.
--
-- This only touches the database. It does not talk to TradeSafe or
-- Pargo itself — that happens in the Edge Functions under
-- supabase-functions/ (tradesafe-checkout, tradesafe-webhook,
-- pargo-shipment, release-expired-escrows), which call these
-- tables/functions using the service role key.
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
-- place_order_paid: like place_order above, but leaves the order
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
-- wallet and flips the order to released/completed. Used by both the
-- PIN-confirm path and the 24h auto-release cron job.
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
  IF NOT FOUND THEN RETURN; END IF;
  IF v_order.escrow_status <> 'held' THEN RETURN; END IF; -- already released/disputed/refunded — no-op

  -- status is flipped to 'completed' here too (not just escrow_status) so
  -- Pargo orders auto-released by the cron job show up the same way as a
  -- seller-confirmed pickup, without needing a separate client-side step.
  UPDATE orders SET escrow_status = 'released', escrow_released_at = now(), status = 'completed' WHERE id = p_order_id;
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
-- see the block at the bottom of this section) by the service role.
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

-- Schedule the 24h auto-release check. Requires the pg_cron extension
-- (Database → Extensions → enable "pg_cron" in the Supabase dashboard
-- first, then run this once).
-- SELECT cron.schedule('release-expired-escrows', '*/15 * * * *', $$SELECT public.release_expired_escrows();$$);

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

-- ############################################################
-- # 3. GROWTH & SAFETY (was: growth_and_safety_migration.sql)
-- ############################################################

-- ============================================================
-- GROWTH & SAFETY FEATURES — run in MARKETPLACE Supabase SQL Editor
-- Requires security_hardening.sql (and ideally push_notifications_migration.sql,
-- so alerts/blocks/referrals also trigger real push notifications).
-- Safe to re-run.
-- ============================================================

-- ============================================================
-- PART 1 — Saved search / price alerts
-- ============================================================
CREATE TABLE IF NOT EXISTS search_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  query text,
  category text,
  max_price numeric,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE search_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "search_alerts_own_select" ON search_alerts;
DROP POLICY IF EXISTS "search_alerts_own_insert" ON search_alerts;
DROP POLICY IF EXISTS "search_alerts_own_delete" ON search_alerts;

CREATE POLICY "search_alerts_own_select" ON search_alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "search_alerts_own_insert" ON search_alerts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "search_alerts_own_delete" ON search_alerts FOR DELETE USING (auth.uid() = user_id);

-- Whenever a new listing goes live, check it against everyone's saved alerts
CREATE OR REPLACE FUNCTION public.match_search_alerts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  a RECORD;
BEGIN
  IF COALESCE(NEW.is_draft, false) OR NOT COALESCE(NEW.is_available, true) THEN
    RETURN NEW;
  END IF;

  FOR a IN
    SELECT * FROM search_alerts
    WHERE user_id <> NEW.seller_id
      AND (category IS NULL OR category = NEW.category)
      AND (max_price IS NULL OR NEW.price <= max_price)
      AND (query IS NULL OR NEW.title ILIKE '%' || query || '%' OR NEW.description ILIKE '%' || query || '%')
  LOOP
    INSERT INTO notifications (user_id, type, message, listing_id)
    VALUES (a.user_id, 'search_alert', '🔔 New match for "' || COALESCE(a.query, a.category, 'your alert') || '": ' || NEW.title, NEW.id);
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_match_search_alerts ON listings;
CREATE TRIGGER trg_match_search_alerts
  AFTER INSERT ON listings
  FOR EACH ROW EXECUTE FUNCTION public.match_search_alerts();

-- ============================================================
-- PART 2 — Block / mute a user in Messages
-- ============================================================
CREATE TABLE IF NOT EXISTS blocked_users (
  blocker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blocked_users_own_select" ON blocked_users;
DROP POLICY IF EXISTS "blocked_users_own_insert" ON blocked_users;
DROP POLICY IF EXISTS "blocked_users_own_delete" ON blocked_users;

CREATE POLICY "blocked_users_own_select" ON blocked_users FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "blocked_users_own_insert" ON blocked_users FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "blocked_users_own_delete" ON blocked_users FOR DELETE USING (auth.uid() = blocker_id);

-- Stop a blocked person from being able to message you at all (server-enforced, not just hidden in the UI)
DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = (CASE WHEN sender_id = buyer_id THEN seller_id ELSE buyer_id END)
      AND blocked_id = sender_id
  )
);

-- ============================================================
-- PART 3 — Invite / referral loop
-- ============================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by uuid REFERENCES profiles(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_bonus_given boolean DEFAULT false;

-- Capture the referrer at signup time, from ?ref=<uid> passed in as auth metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_ref uuid;
BEGIN
  BEGIN
    v_ref := (new.raw_user_meta_data->>'ref')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_ref := NULL;
  END;

  IF v_ref IS NOT NULL AND v_ref = new.id THEN
    v_ref := NULL; -- can't refer yourself
  END IF;
  IF v_ref IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_ref) THEN
    v_ref := NULL; -- unknown referrer, ignore silently
  END IF;

  INSERT INTO public.profiles (id, full_name, whatsapp, referred_by)
  VALUES (new.id, '', '', v_ref)
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Reward: the FIRST time someone you referred becomes an active paid seller,
-- you get +7 days added to your own seller access — a one-time bonus per referral.
CREATE OR REPLACE FUNCTION public.reward_referrer()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_was_active boolean;
  v_now_active boolean;
BEGIN
  v_was_active := OLD.subscription_paid_until IS NOT NULL AND OLD.subscription_paid_until >= CURRENT_DATE;
  v_now_active := NEW.subscription_paid_until IS NOT NULL AND NEW.subscription_paid_until >= CURRENT_DATE;

  IF (NOT v_was_active) AND v_now_active
     AND NEW.referred_by IS NOT NULL
     AND NOT COALESCE(NEW.referral_bonus_given, false) THEN

    PERFORM set_config('app.bypass_profile_guard', 'on', true);

    UPDATE profiles
    SET subscription_paid_until = GREATEST(COALESCE(subscription_paid_until, CURRENT_DATE), CURRENT_DATE) + 7
    WHERE id = NEW.referred_by;

    NEW.referral_bonus_given := true;

    INSERT INTO notifications (user_id, type, message)
    VALUES (NEW.referred_by, 'referral_bonus', '🎉 Someone you invited just became a seller — you got 7 bonus days!');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reward_referrer ON profiles;
CREATE TRIGGER trg_reward_referrer
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.reward_referrer();

-- ############################################################
-- # 4. SELLER PLANS (was: seller_plans_migration.sql)
-- ############################################################

-- ============================================================
-- SELLER PLAN TIERS — run in MARKETPLACE Supabase SQL Editor
-- Requires security_hardening.sql to already be applied.
-- Safe to re-run.
-- ============================================================

-- ---------- 1) Track which plan a seller is on ----------
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS seller_plan text;

-- Existing paid sellers (from before this migration) keep unlimited posting
-- until they renew under the new system — they are NOT retroactively capped.

-- ---------- 2) Protect seller_plan the same way subscription_paid_until is protected ----------
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
     OR NEW.seller_plan IS DISTINCT FROM OLD.seller_plan
     OR NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
    RAISE EXCEPTION 'Cannot modify privileged profile fields';
  END IF;
  RETURN NEW;
END;
$$;

-- ---------- 3) Canonical plan table (single source of truth for days + cap) ----------
CREATE OR REPLACE FUNCTION public.plan_days(p_plan text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_plan
    WHEN 'flash'       THEN 2
    WHEN 'quicklister' THEN 7
    WHEN 'casual'      THEN 30
    WHEN 'standard'    THEN 30
    WHEN 'power'       THEN 30
    WHEN 'quarter'     THEN 90
    WHEN 'semester'    THEN 180
    ELSE NULL
  END;
$$;

-- NULL cap = unlimited listings
CREATE OR REPLACE FUNCTION public.plan_listing_cap(p_plan text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_plan
    WHEN 'flash'       THEN 1
    WHEN 'quicklister' THEN 3
    WHEN 'casual'      THEN 5
    WHEN 'standard'    THEN 15
    WHEN 'power'       THEN NULL
    WHEN 'quarter'     THEN 15
    WHEN 'semester'    THEN NULL
    ELSE NULL
  END;
$$;

-- ---------- 4) Admin: extend subscription by PLAN (replaces the old days-only version) ----------
DROP FUNCTION IF EXISTS public.admin_extend_subscription(uuid, integer);

CREATE OR REPLACE FUNCTION public.admin_extend_subscription(p_seller_id uuid, p_plan text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start date;
  v_until date;
  v_days integer;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_days := public.plan_days(p_plan);
  IF v_days IS NULL THEN RAISE EXCEPTION 'Invalid plan: %', p_plan; END IF;

  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  SELECT CASE
    WHEN subscription_paid_until IS NOT NULL AND subscription_paid_until > CURRENT_DATE
      THEN subscription_paid_until
    ELSE CURRENT_DATE
  END INTO v_start
  FROM profiles WHERE id = p_seller_id;

  IF v_start IS NULL THEN RAISE EXCEPTION 'Seller not found'; END IF;
  v_until := v_start + v_days;

  UPDATE profiles
  SET subscription_paid_until = v_until, seller_plan = p_plan, is_blocked = false, role = 'seller'
  WHERE id = p_seller_id;

  INSERT INTO admin_audit_log (admin_id, action, target_id, details)
  VALUES (auth.uid(), 'mark_paid', p_seller_id, 'Extended subscription '||v_days||' days on plan '||p_plan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_extend_subscription(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plan_days(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plan_listing_cap(text) TO authenticated;

-- ---------- 5) Server-side enforcement: block INSERT/UPDATE once a seller hits their plan's cap ----------
-- Admins and sellers with no seller_plan on file (grandfathered pre-migration accounts) are unlimited.
-- Only fires when a listing is transitioning INTO the "active" (counted) state —
-- editing an already-active listing, or deactivating one, is always allowed.
CREATE OR REPLACE FUNCTION public.enforce_listing_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan text;
  v_is_admin boolean;
  v_cap integer;
  v_count integer;
  v_new_active boolean;
  v_old_active boolean;
BEGIN
  v_new_active := COALESCE(NEW.is_draft, false) = false
    AND COALESCE(NEW.is_sold, false) = false
    AND COALESCE(NEW.is_available, true) = true;

  IF NOT v_new_active THEN
    RETURN NEW; -- not becoming active, nothing to enforce
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_old_active := COALESCE(OLD.is_draft, false) = false
      AND COALESCE(OLD.is_sold, false) = false
      AND COALESCE(OLD.is_available, true) = true;
    IF v_old_active THEN
      RETURN NEW; -- was already active/counted, e.g. a normal edit — don't re-check
    END IF;
  END IF;

  SELECT seller_plan, is_admin INTO v_plan, v_is_admin FROM profiles WHERE id = NEW.seller_id;

  IF v_is_admin IS TRUE OR v_plan IS NULL THEN
    RETURN NEW;
  END IF;

  v_cap := public.plan_listing_cap(v_plan);
  IF v_cap IS NULL THEN
    RETURN NEW; -- unlimited plan
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM listings
  WHERE seller_id = NEW.seller_id
    AND COALESCE(is_draft, false) = false
    AND COALESCE(is_sold, false) = false
    AND COALESCE(is_available, true) = true;

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'LISTING_CAP_REACHED: your % plan allows % active listings — you already have %. Upgrade your plan to post more.', v_plan, v_cap, v_count;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_listing_cap ON listings;
CREATE TRIGGER trg_enforce_listing_cap
  BEFORE INSERT OR UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION public.enforce_listing_cap();

-- ############################################################
-- # 5. SUBSCRIPTION PAYMENTS (was: setup_payments.sql)
-- ############################################################

-- ============================================================
-- Seller subscription payments — run in the MARKETPLACE Supabase SQL Editor
-- Project: kqsqtasykdtpdrkqyaxp
-- ============================================================

-- Payment records (created when seller clicks Pay, completed by the payment
-- provider's webhook once wired up)
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
    auth.uid() = seller_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "sub_pay_admin" ON subscription_payments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- Require an active paid subscription to post (no free / NULL access)
DROP POLICY IF EXISTS "listings_insert" ON listings;
CREATE POLICY "listings_insert" ON listings FOR INSERT WITH CHECK (
  auth.uid() = seller_id AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND COALESCE(is_blocked,false) = false
    AND (
      COALESCE(is_admin,false) = true
      OR (subscription_paid_until IS NOT NULL AND subscription_paid_until >= CURRENT_DATE)
    )
  )
);

-- ############################################################
-- # 6. PUSH NOTIFICATIONS (was: push_notifications_migration.sql)
-- ############################################################

-- ============================================================
-- PUSH NOTIFICATIONS — run in MARKETPLACE Supabase SQL Editor
-- Requires security_hardening.sql already applied.
-- Safe to re-run.
--
-- After running this file, you MUST also deploy the
-- "send-push" Edge Function described in PUSH_SETUP.md
-- and set its two secrets (VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY)
-- — the app will not actually deliver pushes until that's live.
-- ============================================================

-- ---------- 1) Where we store each device's push subscription ----------
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  endpoint text NOT NULL UNIQUE,
  p256dh text NOT NULL,
  auth text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_subs_own_select" ON push_subscriptions;
DROP POLICY IF EXISTS "push_subs_own_insert" ON push_subscriptions;
DROP POLICY IF EXISTS "push_subs_own_delete" ON push_subscriptions;

CREATE POLICY "push_subs_own_select" ON push_subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "push_subs_own_insert" ON push_subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "push_subs_own_delete" ON push_subscriptions FOR DELETE USING (auth.uid() = user_id);

-- ---------- 2) Fire a push whenever a row lands in `notifications` ----------
-- This means every existing notification type (price drop, back in stock)
-- AND the new ones added below (new message, order confirmed/completed)
-- all automatically get pushed too — one trigger, one place.
--
-- NOTE: replace YOUR_PROJECT below with your actual Supabase project ref,
-- and PUSH_SHARED_SECRET
-- with a random string of your choosing — the same value must be set as
-- a secret on the edge function so it can verify the call really came
-- from your database and not a random request from the internet.
CREATE OR REPLACE FUNCTION public.trigger_push_on_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- A push notification is a nice-to-have, not something that should ever be
  -- able to break the action that triggered it. Previously, if the pg_net
  -- extension wasn't enabled (or any other push-sending error occurred),
  -- the "schema net does not exist" error propagated all the way up through
  -- notify_order_status -> this trigger, rolling back the entire order/
  -- message/etc. insert that caused it. Wrapping in BEGIN/EXCEPTION means a
  -- push failure is logged and swallowed instead of failing checkout.
  BEGIN
    PERFORM net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-push-secret', 'PUSH_SHARED_SECRET'
      ),
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', 'Student Marketplace',
        'body', NEW.message,
        'listing_id', NEW.listing_id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'push notification send failed (notification id %): %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_on_notification ON notifications;
CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON notifications
  FOR EACH ROW EXECUTE FUNCTION public.trigger_push_on_notification();

-- ---------- 3) New message → notify the recipient ----------
CREATE OR REPLACE FUNCTION public.notify_new_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient uuid;
  v_sender_name text;
BEGIN
  v_recipient := CASE WHEN NEW.sender_id = NEW.buyer_id THEN NEW.seller_id ELSE NEW.buyer_id END;
  SELECT COALESCE(store_name, full_name, 'Someone') INTO v_sender_name FROM profiles WHERE id = NEW.sender_id;

  INSERT INTO notifications (user_id, type, message, listing_id)
  VALUES (v_recipient, 'new_message', v_sender_name || ' sent you a message 💬', NEW.listing_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_message ON messages;
CREATE TRIGGER trg_notify_new_message
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();

-- ---------- 4) Order status changes → notify the relevant person ----------
CREATE OR REPLACE FUNCTION public.notify_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
BEGIN
  SELECT title INTO v_title FROM listings WHERE id = NEW.listing_id;
  v_title := COALESCE(v_title, 'your item');

  IF TG_OP = 'INSERT' AND NEW.status = 'confirmed' THEN
    INSERT INTO notifications (user_id, type, message, listing_id)
    VALUES (NEW.seller_id, 'new_order', 'New order for "' || v_title || '" 📬', NEW.listing_id);
  ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'completed' THEN
      INSERT INTO notifications (user_id, type, message, listing_id)
      VALUES (NEW.buyer_id, 'order_completed', 'Your order for "' || v_title || '" is complete — leave a review! ⭐', NEW.listing_id);
    ELSIF NEW.status = 'cancelled' THEN
      INSERT INTO notifications (user_id, type, message, listing_id)
      VALUES (NEW.seller_id, 'order_cancelled', 'An order for "' || v_title || '" was cancelled 🚫', NEW.listing_id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_order_status ON orders;
CREATE TRIGGER trg_notify_order_status
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_order_status();

-- ############################################################
-- # 7. LISTING REVIEWS (was: listing_reviews_migration.sql)
-- ############################################################

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

-- ############################################################
-- # 8. FIX: LISTING DELETE (was: fix_listing_delete_migration.sql)
-- ############################################################

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

-- ############################################################
-- # 9. RESTOCK ALERTS (was: restock_alerts_migration.sql)
-- ############################################################

-- ============================================================
-- RESTOCK ALERTS — run in MARKETPLACE Supabase SQL Editor
-- Safe to re-run.
--
-- Lets a buyer click "Notify me when back in stock" on any
-- out-of-stock listing WITHOUT having to favorite it first.
-- This is separate from the existing favorites-based back-in-stock
-- notice in setup.sql (notify_favoriters) — that one only fires
-- for people who favorited the listing; this one is opt-in per item.
-- ============================================================

CREATE TABLE IF NOT EXISTS restock_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

ALTER TABLE restock_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "restock_alerts_own_select" ON restock_alerts;
DROP POLICY IF EXISTS "restock_alerts_own_insert" ON restock_alerts;
DROP POLICY IF EXISTS "restock_alerts_own_delete" ON restock_alerts;

CREATE POLICY "restock_alerts_own_select" ON restock_alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "restock_alerts_own_insert" ON restock_alerts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "restock_alerts_own_delete" ON restock_alerts FOR DELETE USING (auth.uid() = user_id);

-- When a listing's quantity goes from 0 to >0, notify everyone who asked
-- to be told, then clear their alerts so they don't get repeat notices
-- next time it sells out and restocks again.
CREATE OR REPLACE FUNCTION public.notify_restock_alerts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.quantity > 0 AND OLD.quantity = 0 THEN
    INSERT INTO notifications (user_id, type, message, listing_id)
    SELECT user_id, 'back_in_stock', NEW.title || ' is back in stock! 🎉', NEW.id
    FROM restock_alerts WHERE listing_id = NEW.id;

    DELETE FROM restock_alerts WHERE listing_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_restock_alerts ON listings;
CREATE TRIGGER trg_notify_restock_alerts
  AFTER UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION public.notify_restock_alerts();

-- ############################################################
-- # 10. PERFORMANCE INDEXES (was: performance_indexes_migration.sql)
-- ############################################################

-- ============================================================
-- PERFORMANCE INDEXES — run in MARKETPLACE Supabase SQL Editor
-- Safe to re-run (IF NOT EXISTS on every index).
-- Speeds up the queries the app actually runs as data grows:
-- browsing/filtering listings, a seller's/buyer's own rows,
-- unread counts, and paginated feeds.
-- ============================================================

-- Listings: the homepage/browse feed filters on these together
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_category ON listings(category);
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_browse
  ON listings(is_draft, is_available, created_at DESC);
-- Composite, matching the listing rate-limit check's exact WHERE clause
CREATE INDEX IF NOT EXISTS idx_listings_seller_created ON listings(seller_id, created_at);

-- Price filtering needs to compare against the DISCOUNTED price (what the
-- buyer actually pays), not the raw listed price — this generated column
-- computes that once, server-side, instead of every browser doing the math
-- in JS after fetching the whole table (which stopped scaling once the
-- homepage feed moved to server-side filtering).
ALTER TABLE listings ADD COLUMN IF NOT EXISTS effective_price numeric
  GENERATED ALWAYS AS (price - price * COALESCE(discount_percent,0) / 100) STORED;
CREATE INDEX IF NOT EXISTS idx_listings_effective_price ON listings(effective_price);

-- Profiles: seller lookups
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- Orders: a seller's or buyer's own order history
CREATE INDEX IF NOT EXISTS idx_orders_seller_id ON orders(seller_id);
CREATE INDEX IF NOT EXISTS idx_orders_buyer_id ON orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_listing_id ON orders(listing_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);

-- Messages: loading a conversation thread + unread counts
CREATE INDEX IF NOT EXISTS idx_messages_buyer_id ON messages(buyer_id);
CREATE INDEX IF NOT EXISTS idx_messages_seller_id ON messages(seller_id);
CREATE INDEX IF NOT EXISTS idx_messages_listing_id ON messages(listing_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread
  ON messages(seller_id, is_read) WHERE is_read = false;
-- Composite, matching the rate-limit check's exact WHERE clause
-- (sender_id = X AND created_at > ...) — separate single-column indexes on
-- sender_id and created_at can't be combined as efficiently by the planner,
-- and this check runs on every single message insert.
CREATE INDEX IF NOT EXISTS idx_messages_sender_created ON messages(sender_id, created_at);

-- Notifications: a user's notification bell
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread
  ON notifications(user_id, is_read) WHERE is_read = false;

-- Favorites: a user's wishlist + "who favorited this listing"
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);

-- Saved searches (search_alerts): matched on every new listing insert
CREATE INDEX IF NOT EXISTS idx_search_alerts_user_id ON search_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_search_alerts_category ON search_alerts(category);

-- Restock alerts ("notify me when back in stock" — see restock_alerts_migration.sql)
CREATE INDEX IF NOT EXISTS idx_restock_alerts_listing_id ON restock_alerts(listing_id);
CREATE INDEX IF NOT EXISTS idx_restock_alerts_user_id ON restock_alerts(user_id);

-- Blocked users: checked on every message send
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked_id ON blocked_users(blocked_id);

-- Reports: a reporter's own report history
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
-- Composite, matching the rate-limit check's exact WHERE clause
CREATE INDEX IF NOT EXISTS idx_reports_reporter_created ON reports(reporter_id, created_at);

-- Reviews: a seller's rating lookup
CREATE INDEX IF NOT EXISTS idx_reviews_seller_id ON reviews(seller_id);
CREATE INDEX IF NOT EXISTS idx_reviews_buyer_id ON reviews(buyer_id);

-- ############################################################
-- # 11. RATE LIMITING (was: rate_limiting_migration.sql)
-- ############################################################

-- ============================================================
-- RATE LIMITING — run in MARKETPLACE Supabase SQL Editor
-- Requires setup.sql and growth_and_safety_migration.sql already applied.
-- Safe to re-run.
--
-- Enforced server-side (inside RLS WITH CHECK), so it can't be bypassed
-- by calling the API directly instead of going through the app UI.
-- Limits:
--   - Messages:  15 per minute per sender
--   - Reports:    5 per hour per reporter
--   - Listings:   8 per 5 minutes per seller
-- ============================================================

-- ---------- Messages: 15/min ----------
DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = (CASE WHEN sender_id = buyer_id THEN seller_id ELSE buyer_id END)
      AND blocked_id = sender_id
  )
  AND (
    SELECT count(*) FROM messages
    WHERE sender_id = auth.uid() AND created_at > now() - interval '1 minute'
  ) < 15
);

-- ---------- Reports: 5/hour ----------
DROP POLICY IF EXISTS "reports_insert" ON reports;
CREATE POLICY "reports_insert" ON reports FOR INSERT WITH CHECK (
  auth.uid() = reporter_id
  AND (
    SELECT count(*) FROM reports
    WHERE reporter_id = auth.uid() AND created_at > now() - interval '1 hour'
  ) < 5
);

-- ---------- Listings: 8/5min ----------
DROP POLICY IF EXISTS "listings_insert" ON listings;
CREATE POLICY "listings_insert" ON listings FOR INSERT WITH CHECK (
  auth.uid() = seller_id AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND COALESCE(is_blocked,false) = false
    AND (
      COALESCE(is_admin,false) = true
      OR (subscription_paid_until IS NOT NULL AND subscription_paid_until >= CURRENT_DATE)
    )
  )
  AND (
    SELECT count(*) FROM listings
    WHERE seller_id = auth.uid() AND created_at > now() - interval '5 minutes'
  ) < 8
);

-- ############################################################
-- # 12. FREE MODE (was: free_mode_migration.sql)
-- ############################################################

-- ============================================================
-- FREE MODE — run in MARKETPLACE Supabase SQL Editor
-- Lets ALL sellers post without an active paid subscription. Currently
-- ON, since there is no payment provider wired up. Turn OFF (set value
-- back to 'false') if/when paid seller plans are introduced —
-- everything else (plans, pricing, subscription_payments, the paywall
-- screen itself) stays fully intact and resumes normally.
-- Safe to re-run.
-- ============================================================

INSERT INTO settings (key, value) VALUES ('free_mode', 'true')
ON CONFLICT (key) DO UPDATE SET value = 'true';

-- Listings: allow insert when EITHER the seller has an active paid plan
-- (unchanged, normal path) OR free_mode is on (temporary bypass) OR
-- they're an admin. Keeps the existing rate limit (8/5min) in all cases.
DROP POLICY IF EXISTS "listings_insert" ON listings;
CREATE POLICY "listings_insert" ON listings FOR INSERT WITH CHECK (
  auth.uid() = seller_id AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND COALESCE(is_blocked,false) = false
    AND (
      COALESCE(is_admin,false) = true
      OR (subscription_paid_until IS NOT NULL AND subscription_paid_until >= CURRENT_DATE)
      OR EXISTS (SELECT 1 FROM settings WHERE key = 'free_mode' AND value = 'true')
    )
  )
  AND (
    SELECT count(*) FROM listings
    WHERE seller_id = auth.uid() AND created_at > now() - interval '5 minutes'
  ) < 8
);

-- ############################################################
-- # 13. ENABLE REALTIME (was: enable_realtime_migration.sql)
-- ############################################################

-- ============================================================
-- ENABLE REALTIME ON MESSAGES — run in MARKETPLACE Supabase SQL Editor
-- Required for messages.html's Realtime subscription to receive events;
-- without this, the subscribe() call succeeds but silently receives nothing.
-- Safe to re-run.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;
END $$;

-- ============================================================
-- DONE. All sections applied.
-- ============================================================
