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
