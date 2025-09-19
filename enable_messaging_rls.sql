-- Messaging RLS and helper function
-- Run this against your Supabase/Postgres instance (dev) to enable messaging
-- for authenticated participants and fix insert failures in the app.

-- 1) Optional: add read_at column for read receipts (safe if already exists)
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at timestamptz;

-- 2) Helper: check if a user participates in a conversation
CREATE OR REPLACE FUNCTION public.is_conversation_participant(_conversation_id uuid, _user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = _conversation_id
      AND (_user_id = c.buyer_id OR _user_id = c.seller_id)
  );
$$;

-- 10) Grant usage on schema (functions will be granted later after creation)
GRANT USAGE ON SCHEMA public TO authenticated;

-- 11) RPC: ensure_current_user_profile — ensures a row exists in public.users
--     for the authenticated user. Useful to satisfy FK on messages.sender_id.
CREATE OR REPLACE FUNCTION public.ensure_current_user_profile()
RETURNS public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _row public.users;
  _email text;
  _name text;
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
  END IF;

  -- Pull from auth.users
  SELECT email, coalesce(raw_user_meta_data->>'name', split_part(email, '@', 1))
  INTO _email, _name
  FROM auth.users
  WHERE id = _uid;

  -- Upsert minimal profile
  INSERT INTO public.users (id, email, name)
  VALUES (_uid, _email, _name)
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(EXCLUDED.name, public.users.name)
  RETURNING * INTO _row;

  RETURN _row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_current_user_profile() TO authenticated;

-- 3) Enable RLS on messages table
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 4) Allow participants to SELECT messages in their conversations
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND policyname = 'messages_select_participants'
  ) THEN
    CREATE POLICY messages_select_participants
    ON public.messages
    FOR SELECT TO authenticated
    USING (
      public.is_conversation_participant(conversation_id, auth.uid())
    );
  END IF;
END $$;

-- 8) Ensure conversations RLS allows participant reads (required for is_conversation_participant)
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'conversations'
      AND policyname = 'conversations_select_participants'
  ) THEN
    CREATE POLICY conversations_select_participants
    ON public.conversations
    FOR SELECT TO authenticated
    USING (
      buyer_id = auth.uid() OR seller_id = auth.uid()
    );
  END IF;
END $$;

-- 9) RPC: send_message — inserts a message for the current user if participant
--    SECURITY DEFINER so it can bypass RLS evaluation inside helper lookups,
--    but still enforces participant check and uses auth.uid() as sender.
CREATE OR REPLACE FUNCTION public.send_message(
  _conversation_id uuid,
  _content text,
  _message_type text DEFAULT 'text'
) RETURNS public.messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _msg public.messages;
BEGIN
  -- Ensure caller is authenticated
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
  END IF;

  -- Ensure user participates in the conversation
  IF NOT public.is_conversation_participant(_conversation_id, _uid) THEN
    RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.messages (conversation_id, sender_id, content, message_type)
  VALUES (_conversation_id, _uid, _content, COALESCE(_message_type, 'text'))
  RETURNING * INTO _msg;

  RETURN _msg;
END;
$$;

-- Grant execute permission on send_message function
GRANT EXECUTE ON FUNCTION public.send_message(uuid, text, text) TO authenticated;

-- 5) Allow participants to INSERT messages they send
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND policyname = 'messages_insert_by_sender'
  ) THEN
    CREATE POLICY messages_insert_by_sender
    ON public.messages
    FOR INSERT TO authenticated
    WITH CHECK (
      public.is_conversation_participant(conversation_id, auth.uid())
      AND sender_id = auth.uid()
    );
  END IF;
END $$;

-- 6) Allow recipients to UPDATE read_at only (mark as read)
--    Note: this policy permits updates by the recipient for messages not sent by themselves.
--    For stricter control (only read_at can change), add a trigger to enforce column-level updates.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND policyname = 'messages_mark_read_by_recipient'
  ) THEN
    CREATE POLICY messages_mark_read_by_recipient
    ON public.messages
    FOR UPDATE TO authenticated
    USING (
      public.is_conversation_participant(conversation_id, auth.uid())
      AND sender_id <> auth.uid()
    )
    WITH CHECK (
      public.is_conversation_participant(conversation_id, auth.uid())
      AND sender_id <> auth.uid()
    );
  END IF;
END $$;

-- 7) (Optional) Prevent DELETE except by sender; comment out if not desired
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND policyname = 'messages_delete_by_sender'
  ) THEN
    CREATE POLICY messages_delete_by_sender
    ON public.messages
    FOR DELETE TO authenticated
    USING (
      public.is_conversation_participant(conversation_id, auth.uid())
      AND sender_id = auth.uid()
    );
  END IF;
END $$;

-- Done. Verify by attempting to send a message from the app as a conversation participant.
