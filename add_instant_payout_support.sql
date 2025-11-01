-- Add support for instant payouts with debit cards
-- This migration adds tracking for users who have added debit cards

-- Add has_debit_card column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS has_debit_card BOOLEAN DEFAULT FALSE;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_has_debit_card ON users(has_debit_card) WHERE has_debit_card = true;

-- Add comment to document the column
COMMENT ON COLUMN users.has_debit_card IS 'Indicates if user has added a debit card for instant payouts';

-- Verify the column was added
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'has_debit_card';

-- Show users with debit cards (should be none initially)
SELECT 
    id,
    email,
    name,
    has_debit_card,
    stripe_connect_id
FROM users
WHERE has_debit_card = true;

