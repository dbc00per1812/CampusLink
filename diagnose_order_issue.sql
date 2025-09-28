-- Diagnostic queries to find the order creation issue

-- 1. Check if the stripe_payment_intent_fkey constraint still exists
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname = 'orders_stripe_payment_intent_fkey';

-- 2. Check ALL constraints on the orders table
SELECT 
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'orders'
ORDER BY con.conname;

-- 3. Check if there are any triggers that might be interfering
SELECT 
    tgname AS trigger_name,
    pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgrelid = 'public.orders'::regclass
AND tgisinternal = false;

-- 4. Check the current RLS policies on orders
SELECT 
    pol.polname AS policy_name,
    pol.polcmd AS command,
    pg_get_expr(pol.polqual, pol.polrelid) AS using_expression,
    pg_get_expr(pol.polwithcheck, pol.polrelid) AS check_expression
FROM pg_policy pol
JOIN pg_class rel ON rel.oid = pol.polrelid
WHERE rel.relname = 'orders';

-- 5. Check if RLS is enabled
SELECT 
    relname,
    relrowsecurity AS rls_enabled,
    relforcerowsecurity AS force_rls
FROM pg_class
WHERE relname = 'orders';

-- 6. Test a simple insert with hardcoded values
-- Replace these UUIDs with actual ones from your database
INSERT INTO public.orders (
    listing_id,
    buyer_id,
    seller_id,
    price_cents,
    payment_method,
    payment_status,
    order_status,
    created_at,
    updated_at
) VALUES (
    'YOUR_LISTING_ID'::uuid,  -- Replace with actual listing ID
    'YOUR_BUYER_ID'::uuid,    -- Replace with actual user ID
    'YOUR_SELLER_ID'::uuid,   -- Replace with actual user ID
    500,
    'card',
    'succeeded',
    'placed',
    now(),
    now()
);

-- 7. Check what columns are NOT NULL in orders table
SELECT 
    column_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'orders'
  AND is_nullable = 'NO'
ORDER BY ordinal_position;
