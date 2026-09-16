-- Adds temporary/permanent mute expiry, per-conversation archiving, and photo
-- attachments to chat. Safe to run even if you're not sure whether you already
-- have these — every statement is idempotent.

ALTER TABLE blocked_users ADD COLUMN IF NOT EXISTS muted_until timestamptz;
ALTER TABLE blocked_users ADD COLUMN IF NOT EXISTS is_archived boolean DEFAULT false;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS image_url text;

-- A temporary mute (muted_until in the future) should suppress new-message
-- notifications the same way a permanent mute (muted_until left null) already does.
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

  IF EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = v_recipient AND blocked_id = NEW.sender_id AND is_muted = true
      AND (muted_until IS NULL OR muted_until > now())
  ) THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(store_name, full_name, 'Someone') INTO v_sender_name FROM profiles WHERE id = NEW.sender_id;
  INSERT INTO notifications (user_id, type, message, listing_id)
  VALUES (v_recipient, 'new_message', v_sender_name || ' sent you a message 💬', NEW.listing_id);
  RETURN NEW;
END;
$$;

-- NOTE: Also create a bucket named "message-images" manually:
-- Storage -> New bucket -> name: message-images -> Public bucket: ON
-- The app uploads to <user_id>/<filename> — scope the policy to match, so one
-- user can't write into another's folder or overwrite someone else's photo.
DROP POLICY IF EXISTS "Authenticated upload message images" ON storage.objects;
CREATE POLICY "Authenticated upload message images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'message-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Public read message images" ON storage.objects;
CREATE POLICY "Public read message images"
ON storage.objects FOR SELECT
USING (bucket_id = 'message-images');

DROP POLICY IF EXISTS "Owner delete message images" ON storage.objects;
CREATE POLICY "Owner delete message images"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'message-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
