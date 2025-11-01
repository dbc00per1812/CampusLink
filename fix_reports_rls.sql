-- ============================================
-- Fix Reports Table RLS Policies
-- ============================================
-- This script adds Row-Level Security policies for the reports table
-- to allow users to submit reports

-- Enable RLS on reports table (if not already enabled)
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can insert their own reports" ON public.reports;
DROP POLICY IF EXISTS "Users can view their own reports" ON public.reports;
DROP POLICY IF EXISTS "Users can update their own pending reports" ON public.reports;

-- Policy 1: Allow authenticated users to insert reports
-- Note: reporter_id must match the authenticated user
CREATE POLICY "Users can insert their own reports" 
ON public.reports 
FOR INSERT 
TO authenticated
WITH CHECK (
    reporter_id = auth.uid()
);

-- Policy 2: Allow users to view their own submitted reports
CREATE POLICY "Users can view their own reports" 
ON public.reports 
FOR SELECT 
TO authenticated
USING (
    reporter_id = auth.uid()
);

-- Policy 3: Allow users to update their own reports (only if still pending)
CREATE POLICY "Users can update their own pending reports" 
ON public.reports 
FOR UPDATE 
TO authenticated
USING (
    reporter_id = auth.uid() AND status = 'pending'
)
WITH CHECK (
    reporter_id = auth.uid() AND status = 'pending'
);

-- Verify the policies were created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command
FROM pg_policies
WHERE tablename = 'reports'
ORDER BY policyname;

