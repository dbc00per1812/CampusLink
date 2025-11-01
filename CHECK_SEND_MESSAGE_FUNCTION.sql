-- ============================================
-- CHECK: Do you have send_message RPC functions?
-- ============================================

-- Check if these functions exist
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%send_message%';

-- If you see send_message or send_message_bypass functions,
-- those might be inserting messages WITHOUT firing the trigger!



