-- ============================================
-- Archive Listing When Offer is Accepted
-- ============================================
-- This script creates a trigger to automatically archive a listing
-- when an offer is accepted, preventing duplicate sales

-- ============================================
-- PART 1: Create Archive Function
-- ============================================

CREATE OR REPLACE FUNCTION archive_listing_on_offer_accept()
RETURNS TRIGGER AS $$
DECLARE
    listing_record RECORD;
    listing_id_to_archive UUID;
BEGIN
    -- Only process when offer status changes to 'accepted'
    IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
        
        RAISE NOTICE '🎯 Offer accepted! Offer ID: %', NEW.id;
        RAISE NOTICE '   Listing type: %, Status change: % -> %', NEW.listing_type, OLD.status, NEW.status;
        
        -- Determine which listing to archive based on offer type
        -- For SEEK listings: archive the seek_listing_id (the request)
        -- For REGULAR listings: archive the offer_listing_id if it exists, otherwise seek_listing_id
        IF NEW.listing_type = 'seek' THEN
            listing_id_to_archive := NEW.seek_listing_id;
            RAISE NOTICE '   Archiving SEEK listing: %', listing_id_to_archive;
        ELSE
            -- For regular listings, prefer offer_listing_id if it exists
            listing_id_to_archive := COALESCE(NEW.offer_listing_id, NEW.seek_listing_id);
            RAISE NOTICE '   Archiving REGULAR listing: %', listing_id_to_archive;
        END IF;
        
        -- Verify listing exists
        SELECT 
            id, 
            title,
            archived,
            is_sold,
            quantity_available
        INTO listing_record
        FROM listings
        WHERE id = listing_id_to_archive;
        
        IF NOT FOUND THEN
            RAISE WARNING '❌ Listing not found: %', listing_id_to_archive;
            RETURN NEW;
        END IF;
        
        RAISE NOTICE '📦 Current listing state:';
        RAISE NOTICE '   Title: %', listing_record.title;
        RAISE NOTICE '   Archived: %, Sold: %, Quantity: %', 
            listing_record.archived, listing_record.is_sold, listing_record.quantity_available;
        
        -- Archive the listing and mark as sold
        UPDATE listings
        SET 
            archived = true,
            is_sold = true,
            quantity_available = 0
        WHERE id = listing_id_to_archive;
        
        RAISE NOTICE '✅ Listing % archived (offer accepted)', listing_id_to_archive;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PART 2: Create Trigger
-- ============================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS archive_listing_after_offer_accept ON offers;

-- Create trigger that fires after offer update
CREATE TRIGGER archive_listing_after_offer_accept
    AFTER UPDATE ON offers
    FOR EACH ROW
    EXECUTE FUNCTION archive_listing_on_offer_accept();

-- ============================================
-- PART 3: Verification
-- ============================================

-- Verify trigger was created
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'archive_listing_after_offer_accept';

RAISE NOTICE '✅ Trigger created successfully!';
RAISE NOTICE '   Listings will now be archived automatically when offers are accepted';

