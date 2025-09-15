-- Debug: Check the "Used car" listing's intent
SELECT 
    id,
    title,
    intent,
    status,
    archived,
    is_sold,
    created_at
FROM public.listings 
WHERE title ILIKE '%used car%' 
OR title ILIKE '%car%'
ORDER BY created_at DESC;

-- Also check all listings to see what we have
SELECT 
    id,
    title,
    intent,
    status,
    archived,
    is_sold,
    created_at
FROM public.listings 
ORDER BY created_at DESC
LIMIT 10;
