-- Check the create_notification function signature and parameters

-- 1. Get the exact function signature
SELECT 
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.pronargs AS num_args
FROM pg_proc p
WHERE p.proname = 'create_notification';

-- 2. Get detailed parameter info
SELECT 
    p.proname,
    p.proargnames AS parameter_names,
    p.proargtypes::regtype[] AS parameter_types
FROM pg_proc p
WHERE p.proname = 'create_notification';

-- 3. Check if there are multiple versions of the function (overloaded)
SELECT 
    p.proname,
    p.pronargs,
    pg_get_function_arguments(p.oid) AS full_signature
FROM pg_proc p
WHERE p.proname = 'create_notification';
