-- Verification query to check archive feature setup

-- 1. Check if columns exist and their values
SELECT 
  id,
  buyer_id,
  seller_id,
  archived_by_buyer,
  archived_by_seller,
  created_at
FROM public.conversations
ORDER BY created_at DESC
LIMIT 10;

-- 2. Count conversations by archive status
SELECT 
  COUNT(*) as total_conversations,
  SUM(CASE WHEN archived_by_buyer = true THEN 1 ELSE 0 END) as archived_by_buyers,
  SUM(CASE WHEN archived_by_seller = true THEN 1 ELSE 0 END) as archived_by_sellers,
  SUM(CASE WHEN archived_by_buyer IS NULL THEN 1 ELSE 0 END) as null_buyer_flags,
  SUM(CASE WHEN archived_by_seller IS NULL THEN 1 ELSE 0 END) as null_seller_flags
FROM public.conversations;

-- 3. Find any NULL values that need to be fixed
SELECT 
  id,
  archived_by_buyer,
  archived_by_seller
FROM public.conversations
WHERE archived_by_buyer IS NULL 
   OR archived_by_seller IS NULL;

