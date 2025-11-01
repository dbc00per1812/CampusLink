-- ============================================
-- User Blocking System - Performance & Security Enhancements
-- ============================================
-- Run this in Supabase SQL Editor to add indexes, constraints, RLS policies, and helper functions

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON blocked_users(blocked_id);

-- Add unique constraint to prevent duplicate blocks
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'blocked_users_unique'
  ) THEN
    ALTER TABLE blocked_users ADD CONSTRAINT blocked_users_unique 
      UNIQUE(blocker_id, blocked_id);
  END IF;
END $$;

-- Add check constraint to prevent self-blocking
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'blocked_users_no_self_block'
  ) THEN
    ALTER TABLE blocked_users ADD CONSTRAINT blocked_users_no_self_block 
      CHECK (blocker_id != blocked_id);
  END IF;
END $$;

-- Enable RLS policies
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own blocks" ON blocked_users;
DROP POLICY IF EXISTS "Users can create blocks" ON blocked_users;
DROP POLICY IF EXISTS "Users can remove their own blocks" ON blocked_users;

-- Policy: Users can view their own blocks
CREATE POLICY "Users can view their own blocks"
ON blocked_users FOR SELECT
TO authenticated
USING (blocker_id = auth.uid());

-- Policy: Users can create blocks
CREATE POLICY "Users can create blocks"
ON blocked_users FOR INSERT
TO authenticated
WITH CHECK (blocker_id = auth.uid());

-- Policy: Users can remove their own blocks
CREATE POLICY "Users can remove their own blocks"
ON blocked_users FOR DELETE
TO authenticated
USING (blocker_id = auth.uid());

-- Helper function: Check if two users have blocking relationship
CREATE OR REPLACE FUNCTION is_blocked(user_a UUID, user_b UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = user_a AND blocked_id = user_b)
       OR (blocker_id = user_b AND blocked_id = user_a)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function: Get all blocked user IDs for a user
CREATE OR REPLACE FUNCTION get_blocked_user_ids(user_id UUID)
RETURNS TABLE(blocked_user_id UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT blocked_id FROM blocked_users WHERE blocker_id = user_id
  UNION
  SELECT blocker_id FROM blocked_users WHERE blocked_id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update message policy to prevent messaging blocked users
DROP POLICY IF EXISTS "Users can send messages in their conversations" ON messages;
CREATE POLICY "Users can send messages in their conversations"
ON messages FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
    AND (c.buyer_id = auth.uid() OR c.seller_id = auth.uid())
    AND NOT is_blocked(c.buyer_id, c.seller_id)
  )
  AND sender_id = auth.uid()
);

-- Verify the setup
SELECT 'Indexes created' as status;
SELECT 'RLS policies created' as status;
SELECT 'Helper functions created' as status;

