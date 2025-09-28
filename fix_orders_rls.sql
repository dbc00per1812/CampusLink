-- Fix Row Level Security policies for orders table
-- This allows users to create orders when they are the buyer

-- Drop existing policies first
DROP POLICY IF EXISTS "Buyers can create orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view their orders" ON public.orders;
DROP POLICY IF EXISTS "Users can update their orders" ON public.orders;

-- Add INSERT policy for orders table
CREATE POLICY "Buyers can create orders" ON public.orders
    FOR INSERT 
    TO authenticated
    WITH CHECK (buyer_id = auth.uid());

-- Add SELECT policy for orders table
CREATE POLICY "Users can view their orders" ON public.orders
    FOR SELECT 
    TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Add UPDATE policy for orders table
CREATE POLICY "Users can update their orders" ON public.orders
    FOR UPDATE 
    TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid())
    WITH CHECK (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Ensure RLS is enabled on the orders table
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions to authenticated users
GRANT ALL ON public.orders TO authenticated;
