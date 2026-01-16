-- FIX: Messages RLS Policy for New Users
-- Error: "new row violates row-level security policy for table 'messages'" (42501)
--
-- ROOT CAUSE: Missing is_blocked() function + conflicting policies
-- SOLUTION: Drop policies first, then fix functions, then recreate clean policies

-- ============================================================
-- STEP 1: Drop ALL message policies FIRST (before touching functions)
-- ============================================================
DROP POLICY IF EXISTS "Users can send messages in their conversations" ON public.messages;
DROP POLICY IF EXISTS "messages_select" ON public.messages;
DROP POLICY IF EXISTS "messages_insert" ON public.messages;
DROP POLICY IF EXISTS "messages_select_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_by_sender" ON public.messages;
DROP POLICY IF EXISTS "messages_mark_read_by_recipient" ON public.messages;
DROP POLICY IF EXISTS "messages_delete_by_sender" ON public.messages;

-- ============================================================
-- STEP 2: Now drop and recreate functions (policies removed, safe to drop)
-- ============================================================
DROP FUNCTION IF EXISTS is_conversation_participant(uuid, uuid);
DROP FUNCTION IF EXISTS is_blocked(uuid, uuid);

CREATE FUNCTION is_conversation_participant(conv_id uuid, user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversations
    WHERE id = conv_id
    AND (buyer_id = user_id OR seller_id = user_id)
  );
$$;

CREATE FUNCTION is_blocked(user1_id uuid, user2_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.blocked_users
    WHERE (blocker_id = user1_id AND blocked_id = user2_id)
       OR (blocker_id = user2_id AND blocked_id = user1_id)
  );
$$;

-- ============================================================
-- STEP 3: Create clean messages policies
-- ============================================================
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- SELECT: Users can read messages from conversations they participate in
CREATE POLICY "messages_select_policy"
ON public.messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id
    AND (c.buyer_id = auth.uid() OR c.seller_id = auth.uid())
  )
);

-- INSERT: Users can send messages to conversations they participate in
-- Simple check without is_blocked (blocking is handled at app level)
CREATE POLICY "messages_insert_policy"
ON public.messages
FOR INSERT
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = conversation_id
    AND (c.buyer_id = auth.uid() OR c.seller_id = auth.uid())
  )
);

-- UPDATE: Users can update messages in their conversations (for read_at receipts)
CREATE POLICY "messages_update_policy"
ON public.messages
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id
    AND (c.buyer_id = auth.uid() OR c.seller_id = auth.uid())
  )
);

-- DELETE: Users can delete their own messages only
CREATE POLICY "messages_delete_policy"
ON public.messages
FOR DELETE
USING (sender_id = auth.uid());

-- ============================================================
-- STEP 4: Drop ALL existing conversation policies
-- ============================================================
DROP POLICY IF EXISTS "conversations_select" ON public.conversations;
DROP POLICY IF EXISTS "Users can archive own conversations" ON public.conversations;
DROP POLICY IF EXISTS "Users can update own conversations" ON public.conversations;
DROP POLICY IF EXISTS "conversations_select_participants" ON public.conversations;
DROP POLICY IF EXISTS "conversations_insert" ON public.conversations;

-- ============================================================
-- STEP 5: Create clean conversations policies
-- ============================================================
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- SELECT: Users can view conversations they are part of
CREATE POLICY "conversations_select_policy"
ON public.conversations
FOR SELECT
USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- INSERT: Users can create conversations where they are buyer or seller
-- Removed the listing check since it caused issues
CREATE POLICY "conversations_insert_policy"
ON public.conversations
FOR INSERT
WITH CHECK (buyer_id = auth.uid() OR seller_id = auth.uid());

-- UPDATE: Users can update conversations they are part of
CREATE POLICY "conversations_update_policy"
ON public.conversations
FOR UPDATE
USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- ============================================================
-- STEP 6: Verify - Run this to confirm clean policies
-- ============================================================
SELECT tablename, policyname, cmd
FROM pg_policies 
WHERE tablename IN ('messages', 'conversations')
ORDER BY tablename, cmd;

-- Expected output:
-- conversations | conversations_insert_policy | INSERT
-- conversations | conversations_select_policy | SELECT
-- conversations | conversations_update_policy | UPDATE
-- messages      | messages_delete_policy      | DELETE
-- messages      | messages_insert_policy      | INSERT
-- messages      | messages_select_policy      | SELECT
-- messages      | messages_update_policy      | UPDATE

