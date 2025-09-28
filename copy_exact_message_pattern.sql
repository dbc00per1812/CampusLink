 -- Copy the EXACT working message trigger pattern for orders

-- First, let's see the exact message trigger that works
SELECT 'Working message trigger:' as info;
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE event_object_table = 'messages';

-- Get the exact message function code that works
SELECT 'Message function source:' as info;
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_name LIKE '%message%' 
AND routine_type = 'FUNCTION'
AND routine_definition IS NOT NULL;
