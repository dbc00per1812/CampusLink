-- DIAGNOSE AND FIX SEARCH FUNCTIONS
-- This will first show what exists, then clean it up

-- Step 1: Check what search functions currently exist
SELECT 
    routine_name,
    specific_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND (routine_name LIKE '%search%' OR routine_name LIKE '%suggestion%')
ORDER BY routine_name, specific_name;

-- Step 2: Get the exact function signatures that need to be dropped
SELECT 
    'DROP FUNCTION public.' || r.routine_name || '(' || 
    COALESCE(
        string_agg(
            p.parameter_name || ' ' || p.data_type,
            ', '
            ORDER BY p.ordinal_position
        ),
        ''
    ) || ') CASCADE;' as drop_statement
FROM information_schema.routines r
LEFT JOIN information_schema.parameters p ON r.specific_name = p.specific_name
WHERE r.routine_schema = 'public' 
AND r.routine_name IN ('search_listings', 'get_search_suggestions')
GROUP BY r.routine_name, r.specific_name
ORDER BY r.routine_name;
