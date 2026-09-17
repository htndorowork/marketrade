-- ============================================================
-- ENABLE REALTIME ON MESSAGES — run in MARKETPLACE Supabase SQL Editor
-- Required for messages.html's Realtime subscription to receive events;
-- without this, the subscribe() call succeeds but silently receives nothing.
-- Safe to re-run.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;
END $$;
