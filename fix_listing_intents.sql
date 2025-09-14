-- Fix existing listings that may be missing proper intent values

-- First, let's check what intent values currently exist
SELECT intent, COUNT(*) 
FROM public.listings 
GROUP BY intent;

-- Update any listings that might have NULL or missing intent values
-- Since your "Used car" is a $2000 product, it should be an 'offer'
UPDATE public.listings 
SET intent = 'offer' 
WHERE intent IS NULL 
   OR intent = '';

-- Verify all listings now have proper intent values
SELECT 
    title,
    price,
    intent,
    created_at
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
ORDER BY created_at DESC;

-- Show count by intent to verify the fix
SELECT 
    intent, 
    COUNT(*) as count
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
GROUP BY intent;
