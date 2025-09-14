-- Test filter queries to verify they work as expected

-- Test 1: Show all active listings
SELECT 
    id,
    title,
    price,
    intent,
    status,
    archived,
    is_sold
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
ORDER BY created_at DESC;

-- Test 2: Show only 'seek' listings (Buying filter)
SELECT 
    id,
    title,
    price,
    intent,
    status
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
  AND intent = 'seek'
ORDER BY created_at DESC;

-- Test 3: Show only 'offer' listings (Selling filter)  
SELECT 
    id,
    title,
    price,
    intent,
    status
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
  AND intent = 'offer'
ORDER BY created_at DESC;

-- Count by intent
SELECT 
    intent,
    COUNT(*) as count
FROM public.listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
GROUP BY intent;
