-- Add campus field to users table
-- This allows users to select their campus during signup

ALTER TABLE public.users 
ADD COLUMN campus TEXT;

-- Add a check constraint to ensure only valid campuses
ALTER TABLE public.users 
ADD CONSTRAINT users_campus_check 
CHECK (campus IS NULL OR campus IN ('Indiana University Bloomington', 'Purdue University'));

-- Create an index for faster campus-based queries (for future features like campus-specific searches)
CREATE INDEX idx_users_campus ON public.users(campus);

-- Optional: Add comment for documentation
COMMENT ON COLUMN public.users.campus IS 'The campus the user is affiliated with. Users select this during signup.';

