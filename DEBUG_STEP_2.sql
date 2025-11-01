-- ============================================
-- DEBUG STEP 2: Test the trigger manually
-- ============================================

-- First, find a conversation to test with
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

-- WRITE DOWN: 
-- - conversation_id: 
-- - buyer_id: 
-- - seller_id: 

-- Now insert a test message (replace the UUIDs with values from above)
-- Use buyer_id as sender_id, seller should receive notification

-- INSERT INTO messages (conversation_id, sender_id, content)
-- VALUES (
--     'PASTE_CONVERSATION_ID_HERE',
--     'PASTE_BUYER_ID_HERE',
--     'Test message - if you see notification, trigger works!'
-- );

-- After inserting, check if notification was created:
-- SELECT * FROM notifications 
-- WHERE type = 'new_message' 
-- ORDER BY created_at DESC 
-- LIMIT 1;

-- Tell me: Did a notification get created? YES or NO



