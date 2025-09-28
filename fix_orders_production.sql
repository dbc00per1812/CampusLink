-- Production fix for orders table
-- This ensures proper RLS policies and handles all edge cases

-- 1. Ensure RLS is enabled
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 2. Drop ALL existing policies to start fresh
DROP POLICY IF EXISTS "Buyers can create orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view their orders" ON public.orders;
DROP POLICY IF EXISTS "Users can update their orders" ON public.orders;
DROP POLICY IF EXISTS "Orders are viewable by buyer or seller" ON public.orders;
DROP POLICY IF EXISTS "Orders are updatable by buyer or seller" ON public.orders;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.orders;

-- 3. Create comprehensive RLS policies
-- Allow authenticated users to create orders when they are the buyer
CREATE POLICY "Authenticated users can create orders as buyer" ON public.orders
    FOR INSERT 
    TO authenticated
    WITH CHECK (buyer_id = auth.uid());

-- Allow users to view orders where they are buyer or seller
CREATE POLICY "Users can view their own orders" ON public.orders
    FOR SELECT 
    TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Allow users to update orders where they are buyer or seller
CREATE POLICY "Users can update their own orders" ON public.orders
    FOR UPDATE 
    TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid())
    WITH CHECK (buyer_id = auth.uid() OR seller_id = auth.uid());

-- 4. Grant necessary permissions
GRANT ALL ON public.orders TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 5. Ensure timestamp columns have proper defaults
ALTER TABLE public.orders 
    ALTER COLUMN created_at SET DEFAULT now(),
    ALTER COLUMN updated_at SET DEFAULT now();

-- 6. Drop any problematic triggers that might interfere
DROP TRIGGER IF EXISTS create_payment_on_order_insert ON public.orders;
DROP TRIGGER IF EXISTS update_payment_on_order_update ON public.orders;
DROP FUNCTION IF EXISTS create_payment_for_order() CASCADE;
DROP FUNCTION IF EXISTS update_payment_for_order() CASCADE;

-- 7. Verify the table structure
-- This is just for verification, not execution
/*
SELECT 
    column_name, 
    data_type, 
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
    AND table_name = 'orders'
ORDER BY ordinal_position;
*/
