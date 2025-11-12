-- ========================================
-- Add accepts_offers field to listings
-- ========================================
-- Simpler standalone script if you just need to add the field

-- Add the field
ALTER TABLE listings ADD COLUMN IF NOT EXISTS accepts_offers BOOLEAN DEFAULT false;

-- Set all seek listings to accept offers
UPDATE listings SET accepts_offers = true WHERE intent = 'seek';

-- Add index
CREATE INDEX IF NOT EXISTS idx_listings_accepts_offers ON listings(accepts_offers) WHERE accepts_offers = true;

-- Verify
SELECT 
  intent,
  COUNT(*) as count,
  SUM(CASE WHEN accepts_offers THEN 1 ELSE 0 END) as accepts_offers_count
FROM listings
GROUP BY intent;

