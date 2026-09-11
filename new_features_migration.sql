-- ============================================================
-- MARKETRADE — NEW FEATURES MIGRATION
-- Run this once in the Supabase SQL Editor, after setup.sql.
-- Safe to re-run. Adds:
--   1) Saved searches with price/search alerts (notifies buyers
--      when a new listing matches a search they saved)
--   2) Block & mute between users in Messages
--   3) Invite / referral program (referral codes + reward)
-- ============================================================

-- ============================================================
-- PART 1 — SAVED SEARCHES / PRICE ALERTS
-- ============================================================
CREATE TABLE IF NOT EXISTS saved_searches (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  keyword text,
  category text,
  max_price numeric,
  area_only boolean DEFAULT false,
  created_at timestamp DEFAULT now()
);

ALTER TABLE saved_searches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "saved_searches_all" ON saved_searches;
CREATE POLICY "saved_searches_all" ON saved_searches FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Fire when a new listing is posted: notify everyone whose saved
-- search matches it (keyword in title, category, and max price).
CREATE OR REPLACE FUNCTION public.notify_saved_search_matches()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seller profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_seller FROM profiles WHERE id = NEW.seller_id;

  INSERT INTO notifications (user_id, type, message, listing_id)
  SELECT ss.user_id, 'search_alert',
    '🔔 New match for your alert: ' || NEW.title || ' — R' || NEW.price,
    NEW.id
  FROM saved_searches ss
  JOIN profiles p ON p.id = ss.user_id
  WHERE (ss.keyword IS NULL OR ss.keyword = '' OR NEW.title ILIKE '%' || ss.keyword || '%')
    AND (ss.category IS NULL OR ss.category = 'All' OR ss.category = NEW.category)
    AND (ss.max_price IS NULL OR NEW.price <= ss.max_price)
    AND (
      ss.area_only IS NOT TRUE
      OR v_seller.deliver_all_areas IS TRUE
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(v_seller.seller_areas, '[]'::jsonb)) elem
        WHERE elem->>'city' = p.city AND elem->>'district' = p.district
      )
    )
    AND ss.user_id <> NEW.seller_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_saved_search_matches ON listings;
CREATE TRIGGER trg_notify_saved_search_matches
  AFTER INSERT ON listings
  FOR EACH ROW EXECUTE FUNCTION public.notify_saved_search_matches();

-- ============================================================
-- PART 2 — BLOCK & MUTE (Messages)
-- ============================================================
CREATE TABLE IF NOT EXISTS blocked_users (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  blocker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_blocked boolean DEFAULT false,
  is_muted boolean DEFAULT false,
  created_at timestamp DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "blocked_users_all" ON blocked_users;
CREATE POLICY "blocked_users_all" ON blocked_users FOR ALL
  USING (auth.uid() = blocker_id) WITH CHECK (auth.uid() = blocker_id);
-- Let the OTHER party check whether they themselves are blocked (needed for the
-- messages_insert check below, and so the UI can explain why sending failed).
DROP POLICY IF EXISTS "blocked_users_read_as_target" ON blocked_users;
CREATE POLICY "blocked_users_read_as_target" ON blocked_users FOR SELECT
  USING (auth.uid() = blocked_id);

-- Stop a blocked user from messaging the person who blocked them.
DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (auth.uid() = buyer_id OR auth.uid() = seller_id)
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users bu
    WHERE bu.is_blocked = true
      AND bu.blocked_id = sender_id
      AND bu.blocker_id = (CASE WHEN sender_id = buyer_id THEN seller_id ELSE buyer_id END)
  )
);

-- Don't create a "new message" notification for a thread the recipient muted.
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

  IF EXISTS (SELECT 1 FROM blocked_users WHERE blocker_id = v_recipient AND blocked_id = NEW.sender_id AND is_muted = true) THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(store_name, full_name, 'Someone') INTO v_sender_name FROM profiles WHERE id = NEW.sender_id;
  INSERT INTO notifications (user_id, type, message, listing_id)
  VALUES (v_recipient, 'new_message', v_sender_name || ' sent you a message 💬', NEW.listing_id);
  RETURN NEW;
END;
$$;

-- ============================================================
-- PART 3 — INVITE / REFERRAL PROGRAM
-- ============================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_code text;
UPDATE profiles SET referral_code = upper(substr(id::text, 1, 8)) WHERE referral_code IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_referral_code_idx ON profiles(referral_code);

-- Give every new profile a code automatically going forward.
CREATE OR REPLACE FUNCTION public.set_referral_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.referral_code IS NULL THEN
    NEW.referral_code := upper(substr(NEW.id::text, 1, 8));
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_set_referral_code ON profiles;
CREATE TRIGGER trg_set_referral_code
  BEFORE INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_referral_code();

CREATE TABLE IF NOT EXISTS referrals (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  referrer_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  referred_id uuid NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamp DEFAULT now()
);

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "referrals_read" ON referrals;
CREATE POLICY "referrals_read" ON referrals FOR SELECT
  USING (auth.uid() = referrer_id OR auth.uid() = referred_id);
DROP POLICY IF EXISTS "referrals_insert" ON referrals;
CREATE POLICY "referrals_insert" ON referrals FOR INSERT
  WITH CHECK (auth.uid() = referred_id AND referrer_id <> referred_id);

-- Reward: +3 days of active subscription for the referrer, and notify them,
-- the moment a friend they invited signs up.
CREATE OR REPLACE FUNCTION public.reward_referrer()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE profiles
  SET subscription_paid_until = GREATEST(COALESCE(subscription_paid_until, CURRENT_DATE), CURRENT_DATE) + 3
  WHERE id = NEW.referrer_id;

  INSERT INTO notifications (user_id, type, message)
  VALUES (NEW.referrer_id, 'referral', '🎉 A friend joined using your invite link — you earned 3 free selling days!');
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_reward_referrer ON referrals;
CREATE TRIGGER trg_reward_referrer
  AFTER INSERT ON referrals
  FOR EACH ROW EXECUTE FUNCTION public.reward_referrer();

-- No extra policy needed here: profiles already has a public "profiles_read"
-- SELECT policy (USING (true)) from setup.sql, so looking up a referral_code
-- to resolve who invited a new signup already works.
