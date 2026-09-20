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
