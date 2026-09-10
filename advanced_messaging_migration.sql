-- ============================================================
-- ADVANCED MESSAGING MIGRATION
-- Run this once in the Supabase SQL Editor, after
-- rate_limiting_migration.sql. Safe to re-run.
--
-- Adds what the new messages.html needs:
--   1) Attachment columns on `messages` (images/files)
--   2) `last_seen_at` on `profiles` for "Active Xm ago" status
--   3) A `message-attachments` storage bucket + policies
--   4) Realtime enabled on `messages` (INSERT + UPDATE) so chat
--      updates instantly instead of polling every 10s
--   5) Nicer push/notification text when a message is a photo/file
-- ============================================================

-- ---------- 1) Attachment columns ----------
ALTER TABLE messages ADD COLUMN IF NOT EXISTS attachment_url text;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS attachment_type text; -- 'image' | 'file'
ALTER TABLE messages ADD COLUMN IF NOT EXISTS attachment_name text; -- original filename, for file downloads
ALTER TABLE messages ADD COLUMN IF NOT EXISTS attachment_size bigint; -- bytes

-- A message can now be an attachment with no caption, so `content`
-- can no longer be strictly NOT NULL — but every row must still have
-- either real text or an attachment.
ALTER TABLE messages ALTER COLUMN content DROP NOT NULL;
ALTER TABLE messages ALTER COLUMN content SET DEFAULT '';
UPDATE messages SET content = '' WHERE content IS NULL;

ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_content_or_attachment_check;
ALTER TABLE messages ADD CONSTRAINT messages_content_or_attachment_check
  CHECK (coalesce(length(trim(content)), 0) > 0 OR attachment_url IS NOT NULL);

-- ---------- 2) Presence / last-seen ----------
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

-- ---------- 3) Storage bucket for attachments ----------
-- If this INSERT fails due to permissions in your Supabase project,
-- create the bucket manually instead: Storage -> New bucket ->
-- name: message-attachments -> Public bucket: ON — then just run
-- the policy statements below.
INSERT INTO storage.buckets (id, name, public)
VALUES ('message-attachments', 'message-attachments', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Authenticated upload message attachments" ON storage.objects;
CREATE POLICY "Authenticated upload message attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'message-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Public read message attachments" ON storage.objects;
CREATE POLICY "Public read message attachments"
ON storage.objects FOR SELECT
USING (bucket_id = 'message-attachments');

DROP POLICY IF EXISTS "Owner delete message attachments" ON storage.objects;
CREATE POLICY "Owner delete message attachments"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'message-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------- 4) Enable Realtime on messages ----------
-- Lets the client subscribe to postgres_changes instead of polling.
-- RLS still applies to what each subscriber actually receives.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;
END $$;

-- ---------- 5) Nicer notification text for attachments ----------
CREATE OR REPLACE FUNCTION public.notify_new_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient uuid;
  v_sender_name text;
  v_body text;
BEGIN
  v_recipient := CASE WHEN NEW.sender_id = NEW.buyer_id THEN NEW.seller_id ELSE NEW.buyer_id END;
  SELECT COALESCE(store_name, full_name, 'Someone') INTO v_sender_name FROM profiles WHERE id = NEW.sender_id;

  v_body := CASE
    WHEN NEW.attachment_type = 'image' THEN v_sender_name || ' sent a photo 📷'
    WHEN NEW.attachment_url IS NOT NULL THEN v_sender_name || ' sent a file 📎'
    ELSE v_sender_name || ' sent you a message 💬'
  END;

  INSERT INTO notifications (user_id, type, message, listing_id)
  VALUES (v_recipient, 'new_message', v_body, NEW.listing_id);
  RETURN NEW;
END;
$$;
-- (trigger trg_notify_new_message already points at this function — no need to recreate it)
