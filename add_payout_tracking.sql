-- Add Stripe payout tracking to payouts table
-- This column stores the Stripe payout ID (po_xxxxx) for tracking actual Stripe payouts

-- Add stripe_payout_id column if it doesn't exist
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS stripe_payout_id TEXT;

-- Add index for faster lookups by Stripe payout ID (useful for webhooks)
CREATE INDEX IF NOT EXISTS idx_payouts_stripe_payout_id ON payouts(stripe_payout_id);

-- Add comment to document the column
COMMENT ON COLUMN payouts.stripe_payout_id IS 'Stripe payout ID (po_xxxxx) from Stripe Connect API';

-- Verify the column was added
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'payouts' 
AND column_name = 'stripe_payout_id';

