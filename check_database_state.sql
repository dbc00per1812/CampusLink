-- Check what's actually in the database that could be causing issues

-- 1. Check all constraints on orders table
SELECT 
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'orders'
ORDER BY con.conname;

-- 2. Check all triggers on orders table
SELECT 
    tg.tgname AS trigger_name,
    pg_get_triggerdef(tg.oid) AS trigger_definition
FROM pg_trigger tg
JOIN pg_class rel ON rel.oid = tg.tgrelid
WHERE rel.relname = 'orders'
AND tg.tgisinternal = false;

-- 3. Check if there are any rules on orders table
SELECT 
    r.rulename,
    pg_get_ruledef(r.oid) AS rule_definition
FROM pg_rewrite r
JOIN pg_class c ON c.oid = r.ev_class
WHERE c.relname = 'orders'
AND r.rulename != '_RETURN';

-- 4. Check the actual column definitions
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'orders'
ORDER BY ordinal_position;

-- 5. Check if there are any active RLS policies
SELECT 
    pol.polname AS policy_name,
    pol.polcmd AS command,
    pg_get_expr(pol.polqual, pol.polrelid) AS using_expression,
    pg_get_expr(pol.polwithcheck, pol.polrelid) AS check_expression
FROM pg_policy pol
JOIN pg_class rel ON rel.oid = pol.polrelid
WHERE rel.relname = 'orders';
