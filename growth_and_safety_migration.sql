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
