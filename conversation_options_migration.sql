-- ============================================================
-- CHAT OPTIONS: pin / mute / archive a conversation
-- Run in the MARKETPLACE Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- ---------- 1) Per-user settings for each conversation ----------
-- A "conversation" is one row in the chat list = you + ONE other person, no matter
-- how many listings you've talked about. thread_key is that other person's user id
-- (lower-case text), which is exactly how messages.html and notify_new_message()
-- identify a conversation. These settings belong to ONE user: muting or archiving
-- a chat never affects the other person.
CREATE TABLE IF NOT EXISTS conversation_settings (
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  thread_key text NOT NULL CHECK (char_length(thread_key) <= 120),
  pinned_at timestamptz,                          -- set = pinned to the top of the list
  muted_until timestamptz,                        -- "Mute for 24 hours"
  muted_always boolean NOT NULL DEFAULT false,    -- "Mute always"
  archived_at timestamptz,                        -- set = archived
  archived_incoming_count integer NOT NULL DEFAULT 0, -- how many messages THEY had sent (across all listings) when archived;
                                                  -- a newer message from them brings the chat back (unless muted)
  PRIMARY KEY (user_id, thread_key)
);

-- ---------- 1b) Upgrade: one chat per person (was one chat per listing) ----------
-- Any settings saved under the old  '<buyer>|<seller>|<listing>'  keys are merged into one
-- row per person. Pinned/muted if ANY of that person's old chats was; archived only if
-- EVERY one of them was. Does nothing (and is safe to re-run) once no old-style keys remain.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM conversation_settings WHERE thread_key LIKE '%|%') THEN
    CREATE TEMP TABLE _cs_old ON COMMIT DROP AS
    SELECT cs.*,
           lower(CASE WHEN split_part(cs.thread_key, '|', 1) = cs.user_id::text
                      THEN split_part(cs.thread_key, '|', 2)
                      ELSE split_part(cs.thread_key, '|', 1) END) AS other_id
    FROM conversation_settings cs
    WHERE cs.thread_key LIKE '%|%';

    CREATE TEMP TABLE _cs_new ON COMMIT DROP AS
    SELECT o.user_id,
           o.other_id AS thread_key,
           max(o.pinned_at) AS pinned_at,
           bool_or(o.muted_always) AS muted_always,
           max(o.muted_until) AS muted_until,
           max(o.archived_at) AS archived_at,
           (count(*) FILTER (WHERE o.archived_at IS NOT NULL) >= (
              SELECT count(DISTINCT COALESCE(m.listing_id::text, 'none')) FROM messages m
              WHERE (m.buyer_id = o.user_id AND m.seller_id::text = o.other_id)
                 OR (m.seller_id = o.user_id AND m.buyer_id::text = o.other_id)
           )) AS all_archived
    FROM _cs_old o
    GROUP BY o.user_id, o.other_id;

    DELETE FROM conversation_settings WHERE thread_key LIKE '%|%';

    INSERT INTO conversation_settings
      (user_id, thread_key, pinned_at, muted_always, muted_until, archived_at, archived_incoming_count)
    SELECT n.user_id, n.thread_key, n.pinned_at, n.muted_always, n.muted_until,
           CASE WHEN n.all_archived THEN n.archived_at END,
           CASE WHEN n.all_archived THEN (
                SELECT count(*) FROM messages m
                WHERE m.sender_id::text = n.thread_key
                  AND (m.buyer_id = n.user_id OR m.seller_id = n.user_id)
           )::int ELSE 0 END
    FROM _cs_new n
    ON CONFLICT (user_id, thread_key) DO UPDATE SET
      pinned_at    = GREATEST(conversation_settings.pinned_at, EXCLUDED.pinned_at),
      muted_always = conversation_settings.muted_always OR EXCLUDED.muted_always,
      muted_until  = GREATEST(conversation_settings.muted_until, EXCLUDED.muted_until);
  END IF;
END $$;

ALTER TABLE conversation_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conv_settings_own_select" ON conversation_settings;
DROP POLICY IF EXISTS "conv_settings_own_insert" ON conversation_settings;
DROP POLICY IF EXISTS "conv_settings_own_update" ON conversation_settings;
DROP POLICY IF EXISTS "conv_settings_own_delete" ON conversation_settings;

CREATE POLICY "conv_settings_own_select" ON conversation_settings FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "conv_settings_own_insert" ON conversation_settings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "conv_settings_own_update" ON conversation_settings FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "conv_settings_own_delete" ON conversation_settings FOR DELETE USING (auth.uid() = user_id);

-- ---------- 2) Muting is enforced on the SERVER ----------
-- Every push notification and bell notification for a new message starts as a row
-- inserted here, so if the recipient has muted their conversation with the sender we don't
-- create one. (Just hiding it in the app would still buzz their phone.)
-- The guard on to_regclass() means this function keeps working even if it's ever
-- created before the table exists, so it can never break sending a message.
CREATE OR REPLACE FUNCTION public.notify_new_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient uuid;
  v_sender_name text;
  v_muted boolean := false;
BEGIN
  v_recipient := CASE WHEN NEW.sender_id = NEW.buyer_id THEN NEW.seller_id ELSE NEW.buyer_id END;

  IF to_regclass('public.conversation_settings') IS NOT NULL THEN
    SELECT (cs.muted_always OR (cs.muted_until IS NOT NULL AND cs.muted_until > now()))
      INTO v_muted
      FROM conversation_settings cs
     WHERE cs.user_id = v_recipient
       AND cs.thread_key = lower(NEW.sender_id::text);   -- the recipient's conversation with the sender
  END IF;

  IF COALESCE(v_muted, false) THEN
    RETURN NEW;   -- muted: the message is delivered, but no notification / push is created
  END IF;

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
