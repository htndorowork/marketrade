-- ============================================================
-- MARKETRADE — BUGFIXES + RESTOCK ALERTS MIGRATION
-- Run this once in the Supabase SQL Editor, after setup.sql and
-- new_features_migration.sql. Safe to re-run. Fixes:
--   1) "Order failed: schema "net" does not exist" at checkout
--   2) "Delete failed: Cannot modify message content" when deleting
--      a listing that has messages attached to it
-- Adds:
--   3) "Notify me when back in stock" alerts on individual listings
-- ============================================================

-- ============================================================
-- FIX 1 — Checkout failing because the push-notification trigger
-- errors out (pg_net's "net" schema isn't enabled on this project).
-- A notification failing to reach a phone should never block the
-- order/message/etc. that caused it — so wrap the network call in
-- its own exception handler.
-- ============================================================
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
    -- Swallow any push-delivery error (extension not enabled, function
    -- down, network hiccup, etc.) so it can never roll back whatever
    -- action created this notification (an order, a message, ...).
    NULL;
  END;
  RETURN NEW;
END;
$$;

-- ============================================================
-- FIX 2 — Deleting a listing needs to null out messages.listing_id
-- (ON DELETE SET NULL), but the message-immutability trigger was
-- blocking that legitimate system update along with real edits.
-- Now it only blocks changing listing_id to a DIFFERENT listing,
-- not clearing it to NULL.
-- ============================================================
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
-- (trigger itself is unchanged — it already points at this function)

-- ============================================================
-- FEATURE — Restock alerts ("notify me when back in stock")
-- ============================================================
CREATE TABLE IF NOT EXISTS restock_alerts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamp DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

ALTER TABLE restock_alerts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "restock_alerts_all" ON restock_alerts;
CREATE POLICY "restock_alerts_all" ON restock_alerts FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Fires when a listing's stock/availability changes back on. Notifies
-- everyone who asked, then clears those alerts so they don't fire again.
CREATE OR REPLACE FUNCTION public.notify_restock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (COALESCE(OLD.quantity,0) <= 0 AND COALESCE(NEW.quantity,0) > 0)
     OR (OLD.is_available IS DISTINCT FROM NEW.is_available AND NEW.is_available = true AND COALESCE(NEW.quantity,0) > 0) THEN
    INSERT INTO notifications (user_id, type, message, listing_id)
    SELECT ra.user_id, 'restock', '🔔 Back in stock: ' || NEW.title, NEW.id
    FROM restock_alerts ra
    WHERE ra.listing_id = NEW.id;

    DELETE FROM restock_alerts WHERE listing_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_restock ON listings;
CREATE TRIGGER trg_notify_restock
  AFTER UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION public.notify_restock();
