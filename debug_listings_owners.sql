-- Debug listings and their owners - FIXED JOIN
-- Check which users own which listings and their domains

SELECT 
  l.id,
  l.title,
  l.user_id as listing_user_id,
  u.id as user_table_id,
  u.email as owner_email,
  LOWER(SPLIT_PART(u.email, '@', 2)) as owner_domain,
  l.created_at
FROM listings l
LEFT JOIN public.users u ON l.user_id = u.id::text  -- Fixed the JOIN condition
WHERE l.status = 'active' 
  AND l.archived = false
  AND l.is_sold = false
ORDER BY l.created_at DESC
LIMIT 15;

-- Also check for listings with missing user references
SELECT 
  COUNT(*) as total_active_listings,
  COUNT(u.id) as listings_with_valid_users,
  COUNT(*) - COUNT(u.id) as listings_with_missing_users
FROM listings l
LEFT JOIN public.users u ON l.user_id = u.id::text
WHERE l.status = 'active' 
  AND l.archived = false
  AND l.is_sold = false;
