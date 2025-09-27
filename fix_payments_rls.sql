-- Fix Row Level Security policies for payments table
-- This resolves the "new row violates row-level security policy for table 'payments'" error

-- Add INSERT policy for payments table to allow users to create payment records
-- when they are either the buyer or seller
-- Drop existing policy first if it exists
DROP POLICY IF EXISTS "Users can create payments for their transactions" ON public.payments;
CREATE POLICY "Users can create payments for their transactions" ON public.payments
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        buyer_id = auth.uid() OR seller_id = auth.uid()
    );

-- Update the existing SELECT policy to be more explicit
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.payments;
CREATE POLICY "Users can view their own transactions" ON public.payments
    FOR SELECT 
    TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Add UPDATE policy for payments table to allow status updates and confirmations
DROP POLICY IF EXISTS "Users can update payments for their transactions" ON public.payments;
CREATE POLICY "Users can update payments for their transactions" ON public.payments
    FOR UPDATE 
    TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid())
    WITH CHECK (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Add DELETE policy (though we likely won't use this, adding for completeness)
DROP POLICY IF EXISTS "Users can delete payments for their transactions" ON public.payments;
CREATE POLICY "Users can delete payments for their transactions" ON public.payments
    FOR DELETE 
    TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Ensure RLS is enabled on the payments table
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON public.payments TO authenticated;

-- Add comment to explain the fix
COMMENT ON POLICY "Users can create payments for their transactions" ON public.payments IS 
'Allows authenticated users to create payment records when they are either the buyer or seller - fixes offer payment creation';
