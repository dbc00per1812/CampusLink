-- ========================================
-- Unified Offers System - Database Migration
-- ========================================
-- This migration enhances the existing offers table to support bidirectional offers:
-- 1. Seek mode: Sellers make offers on buyer "wanted" posts (existing)
-- 2. Negotiation mode: Buyers make offers on seller listings (new)

-- Add new columns for bidirectional support
ALTER TABLE offers ADD COLUMN IF NOT EXISTS listing_type TEXT DEFAULT 'seek';
ALTER TABLE offers ADD COLUMN IF NOT EXISTS offer_from_user_id UUID;
ALTER TABLE offers ADD COLUMN IF NOT EXISTS offer_to_user_id UUID;
ALTER TABLE offers ADD COLUMN IF NOT EXISTS parent_offer_id UUID;

-- Add foreign key constraint for parent_offer_id (counter-offers)
ALTER TABLE offers ADD CONSTRAINT offers_parent_offer_id_fkey 
  FOREIGN KEY (parent_offer_id) REFERENCES offers(id) ON DELETE SET NULL;

-- Add foreign key constraints for new user columns
ALTER TABLE offers ADD CONSTRAINT offers_offer_from_user_id_fkey 
  FOREIGN KEY (offer_from_user_id) REFERENCES users(id);
  
ALTER TABLE offers ADD CONSTRAINT offers_offer_to_user_id_fkey 
  FOREIGN KEY (offer_to_user_id) REFERENCES users(id);

-- Migrate existing data (all current offers are seek-type)
-- In seek mode: seller_id is the one making the offer, seeker_id is receiving
UPDATE offers SET
  listing_type = 'seek',
  offer_from_user_id = seller_id,
  offer_to_user_id = seeker_id
WHERE listing_type IS NULL OR offer_from_user_id IS NULL;

-- Add constraints after migration
ALTER TABLE offers 
  ALTER COLUMN listing_type SET NOT NULL;

-- Add check constraint for listing_type
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'offers_listing_type_check'
  ) THEN
    ALTER TABLE offers 
      ADD CONSTRAINT offers_listing_type_check 
      CHECK (listing_type IN ('seek', 'regular'));
  END IF;
END $$;

-- Add index for counter-offer chains
CREATE INDEX IF NOT EXISTS idx_offers_parent ON offers(parent_offer_id);

-- Add indexes for new user columns
CREATE INDEX IF NOT EXISTS idx_offers_from_user ON offers(offer_from_user_id);
CREATE INDEX IF NOT EXISTS idx_offers_to_user ON offers(offer_to_user_id);

-- Drop old RLS policies
DROP POLICY IF EXISTS "Users can view their own offers" ON offers;
DROP POLICY IF EXISTS "Seekers can view offers on their seek listings" ON offers;
DROP POLICY IF EXISTS "Sellers can create offers on seek listings" ON offers;
DROP POLICY IF EXISTS "Offer participants can update offers" ON offers;

-- Create new bidirectional RLS policies
CREATE POLICY "Offer participants can view"
  ON offers FOR SELECT
  USING (auth.uid() = offer_from_user_id OR auth.uid() = offer_to_user_id);

CREATE POLICY "Users can create offers"
  ON offers FOR INSERT
  WITH CHECK (auth.uid() = offer_from_user_id);

CREATE POLICY "Participants can update offers"
  ON offers FOR UPDATE
  USING (auth.uid() = offer_from_user_id OR auth.uid() = offer_to_user_id);

-- Add accepts_offers field to listings table
ALTER TABLE listings ADD COLUMN IF NOT EXISTS accepts_offers BOOLEAN DEFAULT false;

-- All seek listings should accept offers (that's how seek mode works)
UPDATE listings SET accepts_offers = true WHERE intent = 'seek';

-- Add index for querying listings that accept offers
CREATE INDEX IF NOT EXISTS idx_listings_accepts_offers ON listings(accepts_offers) WHERE accepts_offers = true;

-- Create updated_at trigger for offers if it doesn't exist
CREATE OR REPLACE FUNCTION update_offers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS offers_updated_at_trigger ON offers;
CREATE TRIGGER offers_updated_at_trigger
  BEFORE UPDATE ON offers
  FOR EACH ROW
  EXECUTE FUNCTION update_offers_updated_at();

-- Verification queries (comment out for production deployment)
-- SELECT COUNT(*) as total_offers, listing_type, COUNT(DISTINCT offer_from_user_id) as unique_senders 
-- FROM offers 
-- GROUP BY listing_type;

-- SELECT COUNT(*) as listings_accepting_offers FROM listings WHERE accepts_offers = true;

