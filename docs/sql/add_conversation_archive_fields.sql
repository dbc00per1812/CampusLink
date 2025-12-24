-- Add archive fields to conversations table
-- This allows users to archive/delete conversations from their view without affecting the other participant

-- Add archived_by_buyer column (default false)
ALTER TABLE public.conversations 
ADD COLUMN IF NOT EXISTS archived_by_buyer BOOLEAN DEFAULT false;

-- Add archived_by_seller column (default false)
ALTER TABLE public.conversations 
ADD COLUMN IF NOT EXISTS archived_by_seller BOOLEAN DEFAULT false;

-- Ensure all existing rows have false instead of NULL
UPDATE public.conversations 
SET archived_by_buyer = false 
WHERE archived_by_buyer IS NULL;

UPDATE public.conversations 
SET archived_by_seller = false 
WHERE archived_by_seller IS NULL;

-- Set NOT NULL constraint after ensuring no nulls exist
ALTER TABLE public.conversations 
ALTER COLUMN archived_by_buyer SET NOT NULL;

ALTER TABLE public.conversations 
ALTER COLUMN archived_by_seller SET NOT NULL;

-- Add index for better query performance when filtering archived conversations
CREATE INDEX IF NOT EXISTS idx_conversations_archived_by_buyer 
ON public.conversations(buyer_id) 
WHERE archived_by_buyer = false;

CREATE INDEX IF NOT EXISTS idx_conversations_archived_by_seller 
ON public.conversations(seller_id) 
WHERE archived_by_seller = false;

-- Comment the columns for documentation
COMMENT ON COLUMN public.conversations.archived_by_buyer IS 'Whether the buyer has archived this conversation';
COMMENT ON COLUMN public.conversations.archived_by_seller IS 'Whether the seller has archived this conversation';

