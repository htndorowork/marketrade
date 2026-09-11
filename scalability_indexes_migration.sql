-- ============================================================
-- MARKETRADE — INDEXES MIGRATION (scalability)
-- Run this once in the Supabase SQL Editor. Safe to re-run
-- (IF NOT EXISTS on everything). Doesn't change any behavior —
-- purely speeds up the exact queries the app already runs, which
-- matters more and more as the number of rows grows.
-- ============================================================

-- Listings: the homepage/browse feed filters on is_available + is_draft
-- and sorts by renewed_at on almost every request — this composite index
-- covers that exact pattern in one lookup instead of a full table scan.
CREATE INDEX IF NOT EXISTS idx_listings_browse
  ON listings (is_available, is_draft, renewed_at DESC);

CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings (seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_category ON listings (category);

-- Profiles: every listing query joins profiles and checks subscription
-- status; referral code lookups happen on every signup with ?ref=.
CREATE INDEX IF NOT EXISTS idx_profiles_subscription ON profiles (subscription_paid_until);
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles (referral_code);

-- Orders: seller dashboard order lists, and the verified-seller badge
-- calculation, both filter by seller_id (+status for the badge).
CREATE INDEX IF NOT EXISTS idx_orders_seller_id ON orders (seller_id);
CREATE INDEX IF NOT EXISTS idx_orders_buyer_id ON orders (buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status);

-- Messages: thread lookups filter by buyer_id/seller_id constantly, and
-- the rate-limit check added earlier filters by sender_id + created_at.
CREATE INDEX IF NOT EXISTS idx_messages_buyer_id ON messages (buyer_id);
CREATE INDEX IF NOT EXISTS idx_messages_seller_id ON messages (seller_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_created ON messages (sender_id, created_at);

-- Notifications: the bell icon queries unread notifications per user
-- constantly (polled or on every page load).
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications (user_id, is_read);

-- Favorites: loaded on every signed-in homepage visit.
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites (user_id);

-- Saved searches / restock alerts / blocked users: matched against on
-- every new listing insert / listing update / message insert respectively.
CREATE INDEX IF NOT EXISTS idx_saved_searches_user_id ON saved_searches (user_id);
CREATE INDEX IF NOT EXISTS idx_restock_alerts_listing_id ON restock_alerts (listing_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_lookup ON blocked_users (blocker_id, blocked_id);

-- Reviews already has an index on listing_id from setup.sql; add seller_id
-- since the verified-badge / store page also filter by it.
CREATE INDEX IF NOT EXISTS idx_reviews_seller_id ON reviews (seller_id);
