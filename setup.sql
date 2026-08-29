-- ============================================================
-- MARKETRADE — FULL DATABASE SETUP (single file, run once)
-- Run this whole file in the Supabase SQL Editor for a fresh
-- project. It merges, in the correct dependency order:
--   1) setup.sql                       (core schema, RLS, storage)
--   2) security_hardening.sql          (privilege guards, admin fns, order flow)
--   3) seller_plans_migration.sql      (plan tiers: flash/quicklister/.../semester)
--   4) setup_payments.sql              (subscription_payments table — Paystack)
--   5) listing_reviews_migration.sql   (auto-fill review listing_id)
--   6) push_notifications_migration.sql(web push subscriptions + triggers)
-- Every statement below is written to be safe to re-run.
-- ============================================================

-- ============================================================
-- PART 1 — CORE SCHEMA (originally setup.sql)
-- ============================================================
-- ============================================================
-- MARKETRADE — FULL DATABASE SETUP
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
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS university text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS delivery_campuses text[] DEFAULT '{}';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_campuses boolean DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_paid_until date;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_blocked boolean DEFAULT false;
-- Institution/campus support (universities, TVET colleges, private higher-ed institutions)
-- SUPERSEDED — see the "Area (Province > City > District > Suburb)" migration below.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS institution_type text; -- 'university' | 'tvet' | 'private' — buyer's own institution type
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS campus text; -- buyer's own campus (university/institution name reuses the existing `university` column)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_universities boolean DEFAULT false; -- seller sells to every university, any campus
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_tvet boolean DEFAULT false; -- seller sells to every TVET college, any campus
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_private boolean DEFAULT false; -- seller sells to every private higher-ed institution, any campus
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS seller_institutions jsonb DEFAULT '[]'::jsonb; -- [{type,name,campuses:[...]}, ...] specific institutions a seller delivers to (beyond the "all X" toggles above)

-- ============================================================
-- AREA SELECTOR MIGRATION (Province > City > District > Town/Suburb)
-- Replaces the institution/campus selector above. Run this once;
-- it's safe to re-run. The old institution_type/campus/university/
-- deliver_all_universities/deliver_all_tvet/deliver_all_private/
-- seller_institutions columns are left in place (unused) in case
-- you need to roll back — drop them later with the commented
-- statements at the bottom once you've confirmed the new columns
-- are populated correctly.
-- ============================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS province text;   -- buyer's own area: e.g. 'Gauteng Province'
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS city text;       -- buyer's own area: e.g. 'City of Johannesburg Metropolitan Municipality'
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS district text;   -- buyer's own area: e.g. 'Sandton & Far North'
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS suburb text;     -- buyer's own area: e.g. 'Sandown'
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deliver_all_areas boolean DEFAULT false; -- seller delivers anywhere in South Africa
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS seller_areas jsonb DEFAULT '[]'::jsonb;  -- [{province,city,district,suburbs:[...]}, ...] specific areas a seller delivers to

-- Once you've confirmed the app is fully on the new area columns,
-- you can drop the old institution/campus columns:
-- ALTER TABLE profiles DROP COLUMN IF EXISTS institution_type;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS campus;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS deliver_all_universities;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS deliver_all_tvet;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS deliver_all_private;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS seller_institutions;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS university;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS delivery_campuses;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS deliver_all_campuses;

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
  events_subcategory text,
  plants_subcategory text,
  decor_subcategory text,
  baby_subcategory text,
  data_subcategory text,
  health_subcategory text,
  career_subcategory text,
  vehicles_subcategory text,
  hardware_subcategory text,
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
ALTER TABLE listings ADD COLUMN IF NOT EXISTS events_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS plants_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS decor_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS baby_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS data_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS health_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS career_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicles_subcategory text;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS hardware_subcategory text;
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
INSERT INTO settings (key, value) VALUES ('free_mode_active', 'false')
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
CREATE POLICY "profiles_read" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_delete_admin" ON profiles FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- LISTINGS policies
CREATE POLICY "listings_read" ON listings FOR SELECT USING (true);
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
CREATE POLICY "listings_update_seller" ON listings FOR UPDATE USING (
  auth.uid() = seller_id
) WITH CHECK (
  auth.uid() = seller_id
);
CREATE POLICY "listings_update_admin" ON listings FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
CREATE POLICY "listings_delete_seller" ON listings FOR DELETE USING (auth.uid() = seller_id);
CREATE POLICY "listings_delete_admin" ON listings FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- ORDERS policies
CREATE POLICY "orders_insert" ON orders FOR INSERT WITH CHECK (true);
CREATE POLICY "orders_read" ON orders FOR SELECT USING (
  auth.uid() = buyer_id OR auth.uid() = seller_id OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
CREATE POLICY "orders_update" ON orders FOR UPDATE USING (
  auth.uid() = seller_id OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- CART policies
CREATE POLICY "cart_manage" ON cart_items
FOR ALL USING (auth.uid() = buyer_id) WITH CHECK (auth.uid() = buyer_id);

-- SETTINGS policies
CREATE POLICY "settings_read" ON settings FOR SELECT USING (true);
CREATE POLICY "settings_write" ON settings FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- REVIEWS policies
CREATE POLICY "reviews_read" ON reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert" ON reviews FOR INSERT WITH CHECK (
  auth.uid() = buyer_id AND
  EXISTS (SELECT 1 FROM orders WHERE id = order_id AND buyer_id = auth.uid() AND status = 'completed')
);
CREATE POLICY "reviews_update_dispute" ON reviews FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);

-- BUYER_REVIEWS policies (seller rates the buyer)
CREATE POLICY "buyer_reviews_read" ON buyer_reviews FOR SELECT USING (true);
CREATE POLICY "buyer_reviews_insert" ON buyer_reviews FOR INSERT WITH CHECK (
  auth.uid() = seller_id AND
  EXISTS (SELECT 1 FROM orders WHERE id = order_id AND seller_id = auth.uid() AND status = 'completed')
);

-- FAVORITES policies (fully private to the user)
CREATE POLICY "favorites_manage" ON favorites FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- REPORTS policies
CREATE POLICY "reports_insert" ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "reports_read_admin" ON reports FOR SELECT USING (
  auth.uid() = reporter_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
CREATE POLICY "reports_update_admin" ON reports FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- ADMIN AUDIT LOG policies
CREATE POLICY "audit_log_read_admin" ON admin_audit_log FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
CREATE POLICY "audit_log_insert_admin" ON admin_audit_log FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);

-- MESSAGES policies
CREATE POLICY "messages_read" ON messages FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
);
CREATE POLICY "messages_update" ON messages FOR UPDATE USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

-- NOTIFICATIONS policies (inserted only by the trigger below, which bypasses RLS)
CREATE POLICY "notifications_read" ON notifications FOR SELECT USING (auth.uid() = user_id);
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
-- Admin access is granted via the guarded block at the very
-- bottom of this file (search "OPTIONAL — grant a specific
-- account"), which sets app.bypass_profile_guard first so it
-- works safely whether this is your first run or a re-run.
-- IMPORTANT: that account must SIGN UP on the site first.

-- ============================================================
-- DONE! After running this:
-- 1. Create the "listing-images" storage bucket (public) if not done
-- 2. Make sure both admin emails have signed up
-- 3. Re-run the ADMIN SETUP section above to confirm admin access
-- ============================================================

-- ============================================================
-- PART 2 — SECURITY HARDENING (originally security_hardening.sql)
-- ============================================================
-- ============================================================
-- SECURITY HARDENING — run in MARKETPLACE Supabase SQL Editor
-- Project: spupfdclswjlpwiebwlq
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
    IF v_seller.subscription_paid_until IS NULL OR v_seller.subscription_paid_until < CURRENT_DATE THEN
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
     OR (NEW.listing_id IS DISTINCT FROM OLD.listing_id AND NEW.listing_id IS NOT NULL) THEN
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

-- ============================================================
-- PART 3 — SELLER PLAN TIERS (originally seller_plans_migration.sql)
-- ============================================================
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

-- ============================================================
-- PART 4 — SUBSCRIPTION PAYMENTS (originally setup_payments.sql)
-- ============================================================
-- ============================================================
-- Seller subscription payments, processed via Paystack — run in the
-- MARKETPLACE Supabase SQL Editor
-- Project: spupfdclswjlpwiebwlq
-- ============================================================

-- Payment records (created when seller clicks Pay, completed by the
-- Paystack webhook). pf_payment_id is a legacy column retained only for
-- historical rows from the retired PayFast integration.
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

-- Require an active paid subscription to post (no free / NULL access),
-- unless the admin has switched on Free Mode via the settings table
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
      OR EXISTS (SELECT 1 FROM settings WHERE key = 'free_mode_active' AND value = 'true')
    )
  )
);

-- ============================================================
-- PART 5 — LISTING REVIEWS (originally listing_reviews_migration.sql)
-- ============================================================
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

-- ============================================================
-- PART 6 — PUSH NOTIFICATIONS (originally push_notifications_migration.sql)
-- ============================================================
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
-- NOTE: replace YOUR_PROJECT below with your actual Supabase project ref
-- (same one used in PAYSTACK_FN in seller.html), and PUSH_SHARED_SECRET
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
  BEGIN
    PERFORM net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-push-secret', 'PUSH_SHARED_SECRET'
      ),
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', 'Marketrade',
        'body', NEW.message,
        'listing_id', NEW.listing_id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- Never let a push-delivery failure (extension not enabled, function
    -- down, network hiccup) roll back whatever action created this
    -- notification (an order, a message, a saved-search match, ...).
    NULL;
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

-- ============================================================
-- Grant htndorowork@gmail.com full admin + a seller semester
-- pass. Safe to re-run — silently updates 0 rows if that
-- account hasn't signed up yet.
-- ============================================================
SET LOCAL app.bypass_profile_guard = 'on';
UPDATE profiles
SET subscription_paid_until = CURRENT_DATE + 180,
    seller_plan = 'semester',
    is_blocked = false,
    role = 'seller',
    is_admin = true
WHERE id = (SELECT id FROM auth.users WHERE email = 'htndorowork@gmail.com');
