-- Add listing_id column to offers table
-- This is a critical missing piece from the unified offers migration

-- Step 1: Add the listing_id column (nullable first)
ALTER TABLE offers 
ADD COLUMN IF NOT EXISTS listing_id UUID;

-- Step 2: Populate listing_id from existing seek_listing_id 
-- (since all existing offers are seek offers)
UPDATE offers 
SET listing_id = seek_listing_id 
WHERE listing_id IS NULL;

-- Step 3: Add foreign key constraint
ALTER TABLE offers
ADD CONSTRAINT offers_listing_id_fkey 
FOREIGN KEY (listing_id) REFERENCES listings(id);

-- Step 4: Make listing_id NOT NULL now that it's populated
ALTER TABLE offers 
ALTER COLUMN listing_id SET NOT NULL;

-- Step 5: Make old columns nullable (for backward compatibility)
ALTER TABLE offers 
ALTER COLUMN seek_listing_id DROP NOT NULL;

ALTER TABLE offers 
ALTER COLUMN seeker_id DROP NOT NULL;

ALTER TABLE offers 
ALTER COLUMN seller_id DROP NOT NULL;

-- Verify the changes
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'offers' 
AND column_name IN ('listing_id', 'seek_listing_id', 'offer_from_user_id', 'offer_to_user_id')
ORDER BY column_name;

