-- Fix RLS policy to allow users to archive their own conversations
-- The issue: Users can SELECT conversations but cannot UPDATE them

-- First, check if RLS is enabled on conversations
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'conversations';

-- Drop existing update policy if it exists (won't error if it doesn't exist)
DROP POLICY IF EXISTS "Users can update own conversations" ON public.conversations;

-- Create policy allowing users to update conversations they are part of
CREATE POLICY "Users can update own conversations" 
ON public.conversations 
FOR UPDATE 
USING (
  auth.uid() = buyer_id OR auth.uid() = seller_id
)
WITH CHECK (
  auth.uid() = buyer_id OR auth.uid() = seller_id
);

-- Also ensure the update policy allows updating archive fields specifically
-- This is a more permissive version if the above doesn't work
DROP POLICY IF EXISTS "Users can archive own conversations" ON public.conversations;

CREATE POLICY "Users can archive own conversations"
ON public.conversations
FOR UPDATE
USING (
  auth.uid() = buyer_id OR auth.uid() = seller_id
);

-- Verify policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'conversations';

