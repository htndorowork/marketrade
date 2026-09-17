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
