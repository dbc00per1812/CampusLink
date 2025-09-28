-- EMERGENCY FIX: Remove ALL notification triggers to restore messaging
-- This will completely disable notification triggers until we fix them properly

-- Step 1: Remove ALL triggers that could interfere with messages
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;
DROP TRIGGER IF EXISTS message_notification_trigger_safe ON messages;
DROP TRIGGER IF EXISTS notify_on_message_trigger ON messages;

-- Step 2: Remove ALL notification functions that might be broken
DROP FUNCTION IF EXISTS notify_on_message();
DROP FUNCTION IF EXISTS notify_on_message_safe();

-- Step 3: Check what triggers still exist on messages table
SELECT 'Current triggers on messages table:' as info;
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'messages'
ORDER BY trigger_name;

-- Step 4: Test message insertion manually to see exact error
SELECT 'Testing basic message insertion...' as test;

-- Get a real conversation ID to test with
SELECT 'Available conversations:' as info;
SELECT id, buyer_id, seller_id FROM conversations LIMIT 3;

-- Step 5: Instructions for manual test
SELECT 'To test message insertion manually, run:' as instruction;
SELECT '
-- Replace CONVERSATION_ID and SENDER_ID with real values from above
INSERT INTO messages (conversation_id, sender_id, content, created_at) 
VALUES (
  ''CONVERSATION_ID_HERE'', 
  ''SENDER_ID_HERE'', 
  ''Test message'', 
  NOW()
);
' as test_query;

-- Step 6: Check RLS policies on messages (might be blocking)
SELECT 'Messages table RLS policies:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'messages';

-- Step 7: Temporarily disable RLS if needed (EMERGENCY ONLY)
-- Uncomment if RLS is blocking:
-- ALTER TABLE messages DISABLE ROW LEVEL SECURITY;

SELECT 'All notification triggers removed from messages table' as status;
SELECT 'Try sending a message now - should work!' as result;
