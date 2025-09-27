-- Quick test to check if offers table has price_cents column

-- Check current offers table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'offers' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if price_cents column exists specifically
SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'offers' 
      AND column_name = 'price_cents' 
      AND table_schema = 'public'
) as price_cents_exists;

-- Show sample of current offers (if any)
SELECT COUNT(*) as total_offers FROM public.offers;
