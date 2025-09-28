-- Check what triggers exist that might be blocking order creation

SELECT 'All active triggers:' as info;
SELECT 
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers 
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Check if there are any failed trigger logs
SELECT 'Recent trigger debug logs (if any):' as logs;
SELECT message_id, message_content, created_at 
FROM trigger_debug_log 
WHERE created_at >= NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 5;
