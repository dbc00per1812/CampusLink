-- Add student verification fields to users table
-- This allows students to upload their student IDs for manual verification

-- Add verification status field
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'unverified' 
CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected'));

-- Add student ID image URL field
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS student_id_image_url TEXT;

-- Add verification submission date
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMP WITH TIME ZONE;

-- Add verification approval/rejection date
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS verification_reviewed_at TIMESTAMP WITH TIME ZONE;

-- Add reviewer notes (for rejection reasons or admin notes)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS verification_notes TEXT;

-- Create index for querying pending verifications
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users(verification_status);

-- Add comments for documentation
COMMENT ON COLUMN public.users.verification_status IS 'Student verification status: unverified, pending, verified, or rejected';
COMMENT ON COLUMN public.users.student_id_image_url IS 'URL to uploaded student ID image for verification';
COMMENT ON COLUMN public.users.verification_submitted_at IS 'Timestamp when student submitted verification request';
COMMENT ON COLUMN public.users.verification_reviewed_at IS 'Timestamp when admin reviewed the verification';
COMMENT ON COLUMN public.users.verification_notes IS 'Admin notes about verification (e.g., rejection reason)';

