-- Debug listings - simplified approach to avoid JOIN issues
-- First check what data types we're working with

-- 1. Check listings table structure and sample data
SELECT 
  id,
  title,
  user_id,
  pg_typeof(user_id) as user_id_type,
  status,
  archived,
  is_sold,
  created_at
FROM listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false
ORDER BY created_at DESC
LIMIT 10;

-- 2. Check users table structure  
SELECT 
  id,
  pg_typeof(id) as id_type,
  email,
  name
FROM public.users
LIMIT 5;

-- 3. Try simple approach - just show all active listings first
SELECT 
  COUNT(*) as total_active_listings
FROM listings 
WHERE status = 'active' 
  AND archived = false 
  AND is_sold = false;
