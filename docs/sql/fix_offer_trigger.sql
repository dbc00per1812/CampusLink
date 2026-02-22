-- FIX: Update offer notification trigger to use correct column names
-- Run this in Supabase SQL Editor
-- 
-- Problem: The trigger was using columns that don't exist:
--   - full_name, username → should be 'name'
--   - buyer_id → should be 'offer_from_user_id'  
--   - seller_id → should be 'offer_to_user_id'
--   - offer_amount → should be 'price_cents'

-- First, drop the existing trigger
DROP TRIGGER IF EXISTS on_new_offer ON offers;

-- Create the fixed function
CREATE OR REPLACE FUNCTION notify_new_offer()
RETURNS TRIGGER AS $$
DECLARE
    buyer_name TEXT;
    listing_title TEXT;
    offer_amount_dollars TEXT;
BEGIN
    -- Get buyer name (using correct column 'name')
    SELECT COALESCE(name, 'A buyer') INTO buyer_name
    FROM users WHERE id = NEW.offer_from_user_id;
    
    -- Get listing title
    SELECT title INTO listing_title
    FROM listings WHERE id = NEW.listing_id;
    
    -- Format offer amount (using correct column 'price_cents')
    offer_amount_dollars := '$' || ROUND((COALESCE(NEW.price_cents, 0) / 100.0)::numeric, 2)::TEXT;
    
    -- Notify the offer recipient (seller for regular listings)
    PERFORM send_onesignal_notification(
        NEW.offer_to_user_id,
        'New Offer Received',
        buyer_name || ' offered ' || offer_amount_dollars || ' for "' || LEFT(listing_title, 30) || '"',
        jsonb_build_object(
            'type', 'new_offer',
            'offer_id', NEW.id,
            'listing_id', NEW.listing_id,
            'screen', 'OfferDetail'
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER on_new_offer
    AFTER INSERT ON offers
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_offer();

-- Verify the fix
SELECT 'Offer trigger updated successfully!' as status;
