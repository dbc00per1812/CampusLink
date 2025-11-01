-- Remove all location tracking from the database
-- This script removes location-related columns and indices from the users table

-- Drop the location index
DROP INDEX IF EXISTS public.idx_users_location_lat_lng;

-- Remove location columns from users table
ALTER TABLE public.users 
DROP COLUMN IF EXISTS location_address,
DROP COLUMN IF EXISTS location_lat,
DROP COLUMN IF EXISTS location_lng,
DROP COLUMN IF EXISTS location_privacy,
DROP COLUMN IF EXISTS location_updated_at;

-- Success message
SELECT 'Location tracking removed successfully from users table!' AS status;


