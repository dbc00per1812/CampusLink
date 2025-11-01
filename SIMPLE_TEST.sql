-- ============================================
-- SIMPLE TEST: Send a message and check if notification is created
-- ============================================

-- Step 1: Check if trigger exists
SELECT 
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'message_notification_trigger';

-- Should show 1 row. If not, trigger isn't installed.

-- Step 2: Find a test conversation
SELECT 
    c.id as conversation_id,
    c.buyer_id,
    c.seller_id,
    buyer.name as buyer_name,
    seller.name as seller_name
FROM conversations c
LEFT JOIN users buyer ON c.buyer_id = buyer.id
LEFT JOIN users seller ON c.seller_id = seller.id
LIMIT 1;

-- Pick one of these IDs for testing

-- Step 3: Insert a test message (REPLACE THE IDs BELOW)
-- INSERT INTO messages (conversation_id, sender_id, content)
-- VALUES (
--     'YOUR_CONVERSATION_ID_HERE',
--     'YOUR_SENDER_ID_HERE',  -- Use buyer_id or seller_id from above
--     'Test message to check notifications'
-- );

-- Step 4: Check if notification was created
SELECT 
    n.id,
    n.type,
    n.body,
    n.user_id as recipient_id,
    n.created_at,
    recipient.name as recipient_name
FROM notifications n
LEFT JOIN users recipient ON n.user_id = recipient.id
WHERE n.type = 'new_message'
ORDER BY n.created_at DESC
LIMIT 1;

-- Should show a notification created within the last few seconds
-- If not, the trigger isn't firing



