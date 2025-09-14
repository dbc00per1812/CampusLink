-- Quick test to verify what's actually in the database right now

-- 1. Check if listings table exists and has data
SELECT COUNT(*) as total_listings FROM public.listings;

-- 2. Check what intent values exist
SELECT intent, COUNT(*) as count 
FROM public.listings 
GROUP BY intent 
ORDER BY intent;

-- 3. Check active listings specifically
SELECT 
    id,
    title,
    intent,
    price,
    status,
    archived,
    is_sold,
    created_at
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check if there are any NULL intents
SELECT COUNT(*) as null_intents 
FROM public.listings 
WHERE intent IS NULL;

-- 5. Double-check the filter query that should work
-- This is exactly what "Buying" filter should return
SELECT 
    id,
    title,
    intent,
    price
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
  AND intent = 'seek'
ORDER BY created_at DESC;
