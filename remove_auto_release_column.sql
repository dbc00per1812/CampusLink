-- Remove auto_release_at column from orders table
-- This removes the 3-day auto-release functionality

ALTER TABLE public.orders 
DROP COLUMN IF EXISTS auto_release_at;

-- Verify the column has been removed
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND table_schema = 'public'
ORDER BY ordinal_position;
