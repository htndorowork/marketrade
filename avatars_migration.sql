-- ============================================================
-- MARKETRADE — PROFILE PICTURES
-- Run once in the Supabase SQL Editor. Safe to re-run.
--
-- Manual step first (SQL alone can't create a Storage bucket on every
-- Supabase plan): Dashboard → Storage → New bucket → name it exactly
-- "avatars" → toggle Public ON → Create. Then run this file.
-- ============================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url text;

-- Same "own folder" pattern as listing-images / message-images: a user may
-- only upload/delete inside a folder named after their own auth.uid(), and
-- anyone may read (avatars are public-facing, like a listing photo).
DROP POLICY IF EXISTS "Authenticated upload avatar" ON storage.objects;
CREATE POLICY "Authenticated upload avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Public read avatars" ON storage.objects;
CREATE POLICY "Public read avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Owner delete avatar" ON storage.objects;
CREATE POLICY "Owner delete avatar"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Lets a user replace their own avatar file in place (upsert) rather than
-- only ever creating new ones.
DROP POLICY IF EXISTS "Owner update avatar" ON storage.objects;
CREATE POLICY "Owner update avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
