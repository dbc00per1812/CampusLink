-- ============================================
-- DEBUG STEP 1: Is the trigger actually installed?
-- ============================================

SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'message_notification_trigger';

-- Copy the result and tell me:
-- Does it show a row? YES or NO



