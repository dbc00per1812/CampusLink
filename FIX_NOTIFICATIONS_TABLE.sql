-- ============================================
-- FIX: Add missing updated_at column to notifications table
-- ============================================
-- This is why notifications aren't working!
-- The trigger tries to insert but the table is missing updated_at column
-- ============================================

-- Add the missing updated_at column
ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

-- Verify it was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'notifications' 
AND column_name IN ('created_at', 'updated_at');

-- Should show both created_at and updated_at

-- ============================================
-- NOW TEST: Send a message and it should work!
-- ============================================



