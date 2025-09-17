-- Add multiple photos support to listings table
-- This script adds a photos array column to store multiple photo URLs

-- Add the photos column as an array of text
ALTER TABLE public.listings 
ADD COLUMN photos text[] DEFAULT '{}';

-- Migrate existing single photo data to the new photos array
-- This will move the existing photo URL to the first position in the photos array
UPDATE public.listings 
SET photos = CASE 
    WHEN photo IS NOT NULL AND photo != '' THEN ARRAY[photo]
    ELSE '{}'::text[]
END;

-- Create an index on the photos array for better query performance
CREATE INDEX idx_listings_photos ON public.listings USING GIN (photos);

-- Optional: Add a constraint to ensure photos array is not null (it can be empty)
ALTER TABLE public.listings 
ADD CONSTRAINT check_photos_not_null CHECK (photos IS NOT NULL);

-- Optional: Add a constraint to limit the number of photos (e.g., max 10 photos per listing)
ALTER TABLE public.listings 
ADD CONSTRAINT check_photos_limit CHECK (array_length(photos, 1) <= 10);

-- Note: The old 'photo' column is kept for backward compatibility
-- You can drop it later after ensuring all clients are updated:
-- ALTER TABLE public.listings DROP COLUMN photo;
