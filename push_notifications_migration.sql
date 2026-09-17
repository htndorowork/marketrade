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
