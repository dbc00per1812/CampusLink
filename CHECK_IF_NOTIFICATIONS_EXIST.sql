-- ============================================
-- CHECK: Are notifications actually in the database?
-- ============================================

-- Check the most recent notifications
SELECT 
    n.id,
    n.type,
    n.title,
    n.body,
    n.created_at,
    n.is_read,
    n.user_id as recipient_id,
    n.related_user_id as sender_id,
    recipient.name as recipient_name,
    recipient.email as recipient_email,
    sender.name as sender_name
FROM notifications n
LEFT JOIN users recipient ON n.user_id = recipient.id
LEFT JOIN users sender ON n.related_user_id = sender.id
WHERE n.type = 'new_message'
ORDER BY n.created_at DESC
LIMIT 5;

-- Tell me:
-- 1. Do you see recent notifications (last few minutes)?
-- 2. What is the recipient_email?
-- 3. Is that the email you're logged in with in the app?



