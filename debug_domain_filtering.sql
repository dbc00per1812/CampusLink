-- Debug domain filtering asymmetry
-- Why can IU user see Purdue posts but not vice versa?

-- 1. Check all user email domains in the database
SELECT 
  email,
  LOWER(SPLIT_PART(email, '@', 2)) as extracted_domain,
  campus_email_verified,
  created_at
FROM public.users 
WHERE email IS NOT NULL
ORDER BY email;

-- 2. Check current user who can see the wrong posts
SELECT 
  id,
  email,
  LOWER(SPLIT_PART(email, '@', 2)) as user_domain,
  name
FROM public.users 
WHERE email LIKE '%@iu.edu' 
   OR email LIKE '%@purdue.edu'
ORDER BY email;

-- 3. Check listing owners and their domains
SELECT 
  l.id,
  l.title,
  u.email as owner_email,
  LOWER(SPLIT_PART(u.email, '@', 2)) as owner_domain,
  l.created_at
FROM listings l
JOIN public.users u ON l.user_id::text = u.id
WHERE l.status = 'active' 
  AND l.archived = false
  AND l.is_sold = false
ORDER BY l.created_at DESC
LIMIT 10;

-- 4. Check for case sensitivity issues or extra whitespace
SELECT 
  email,
  LENGTH(email) as email_length,
  TRIM(email) as trimmed_email,
  email = TRIM(email) as is_trimmed
FROM public.users 
WHERE email LIKE '%@iu.edu' OR email LIKE '%@purdue.edu';

-- This will help identify if there are:
-- - Case sensitivity issues
-- - Whitespace problems  
-- - Invalid email formats
-- - Missing user records
