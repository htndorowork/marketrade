-- ============================================================
-- PROFILE PICTURES + ONLINE/OFFLINE STATUS
-- Run in the MARKETPLACE Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- ---------- 1) Profile pictures ----------
-- Every user (buyer or seller) can have one. Files are uploaded to the existing
-- `listing-images` bucket under <user_id>/avatar-<timestamp>.jpg, which the
-- existing storage policies already allow (own-folder uploads, public read,
-- owner delete) — so no new storage policy is required.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url text;

-- ---------- 2) Presence (last seen) ----------
-- Kept in its own table rather than on `profiles` so a heartbeat every minute
-- doesn't fire the profile update triggers or bloat the profiles table.
-- RLS is on with NO policies: nobody can read/write the table directly. All
-- access goes through the SECURITY DEFINER functions below, which only ever
-- expose "seconds since last seen" (never a raw timestamp).
CREATE TABLE IF NOT EXISTS user_presence (
  user_id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  last_seen_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE user_presence ENABLE ROW LEVEL SECURITY;

-- Heartbeat: the signed-in user marks themselves as seen "now" (server clock).
CREATE OR REPLACE FUNCTION public.touch_presence()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  INSERT INTO user_presence (user_id, last_seen_at)
  VALUES (auth.uid(), now())
  ON CONFLICT (user_id) DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at;
END;
$$;

-- Lookup: how many seconds ago was each of these users last seen?
-- Returning a relative value computed on the server means a visitor's wrong
-- device clock can never make someone look permanently offline. Capped at 50
-- ids per call. Users who have never been seen simply have no row.
CREATE OR REPLACE FUNCTION public.get_presence(p_user_ids uuid[])
RETURNS TABLE (user_id uuid, seconds_ago integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT up.user_id,
         GREATEST(0, EXTRACT(EPOCH FROM (now() - up.last_seen_at))::integer)
  FROM user_presence up
  WHERE up.user_id = ANY (p_user_ids[1:50]);
$$;

REVOKE ALL ON FUNCTION public.touch_presence() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_presence(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.touch_presence() TO authenticated;
-- anon may look up status too, so signed-out visitors browsing a listing can see
-- whether the seller is online.
GRANT EXECUTE ON FUNCTION public.get_presence(uuid[]) TO anon, authenticated;
