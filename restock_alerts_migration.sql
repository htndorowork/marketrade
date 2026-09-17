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
