-- ============================================
-- PRODUCTION FIX: Posts Not Disappearing After Sale
-- ============================================
-- This is a complete backend solution that fixes the issue
-- Run this entire script in Supabase SQL Editor
-- No app changes needed - this is 100% database-side

-- ============================================
-- PART 1: Clean Up Any Existing Triggers/Functions
-- ============================================

DROP TRIGGER IF EXISTS update_listing_quantity_after_order ON orders;
DROP TRIGGER IF EXISTS restore_listing_quantity_on_order_cancel ON orders;
DROP FUNCTION IF EXISTS update_listing_quantity_on_order();
DROP FUNCTION IF EXISTS restore_listing_quantity_on_cancel();

-- ============================================
-- PART 2: Create Auto-Archive Function (Triggered on Order Insert)
-- ============================================

CREATE OR REPLACE FUNCTION update_listing_quantity_on_order()
RETURNS TRIGGER AS $$
DECLARE
    listing_record RECORD;
    new_quantity_available INTEGER;
BEGIN
    -- Log the trigger firing
    RAISE NOTICE '🔔 Auto-archive trigger fired for order: %', NEW.id;
    RAISE NOTICE '   Payment status: %, Order status: %', NEW.payment_status, NEW.order_status;
    
    -- Only process if order is successfully placed (payment succeeded)
    IF NEW.payment_status = 'succeeded' AND NEW.order_status IN ('placed', 'confirmed') THEN
        
        RAISE NOTICE '✅ Conditions met - processing order %', NEW.id;
        RAISE NOTICE '   Listing ID: %, Quantity: %', NEW.listing_id, NEW.quantity;
        
        -- Get current listing state
        SELECT 
            id, 
            title,
            quantity_available, 
            quantity_sold,
            archived
        INTO listing_record
        FROM listings
        WHERE id = NEW.listing_id;
        
        IF NOT FOUND THEN
            RAISE WARNING '❌ Listing not found: %', NEW.listing_id;
            RETURN NEW;
        END IF;
        
        RAISE NOTICE '📦 Current listing state:';
        RAISE NOTICE '   Title: %', listing_record.title;
        RAISE NOTICE '   Available: %, Sold: %, Archived: %', 
            listing_record.quantity_available, listing_record.quantity_sold, listing_record.archived;
        
        -- Calculate new quantity
        new_quantity_available := GREATEST(0, COALESCE(listing_record.quantity_available, 1) - COALESCE(NEW.quantity, 1));
        
        RAISE NOTICE '🔢 New quantity_available will be: %', new_quantity_available;
        
        -- Update the listing quantity AND mark as sold
        UPDATE listings
        SET 
            quantity_available = new_quantity_available,
            quantity_sold = COALESCE(quantity_sold, 0) + COALESCE(NEW.quantity, 1),
            archived = CASE 
                WHEN new_quantity_available <= 0 THEN true
                ELSE archived
            END,
            is_sold = CASE 
                WHEN new_quantity_available <= 0 THEN true
                ELSE is_sold
            END
        WHERE id = NEW.listing_id;
        
        -- Verify the update
        SELECT archived INTO listing_record
        FROM listings
        WHERE id = NEW.listing_id;
        
        IF new_quantity_available <= 0 THEN
            RAISE NOTICE '✅ Listing % archived (sold out)', NEW.listing_id;
        ELSE
            RAISE NOTICE '✅ Listing % updated - % units remaining', NEW.listing_id, new_quantity_available;
        END IF;
        
    ELSE
        RAISE NOTICE '⏭️  Skipping - conditions not met (payment_status=%s, order_status=%s)', 
            NEW.payment_status, NEW.order_status;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PART 3: Create Restore Function (Triggered on Order Cancellation)
-- ============================================

CREATE OR REPLACE FUNCTION restore_listing_quantity_on_cancel()
RETURNS TRIGGER AS $$
DECLARE
    listing_record RECORD;
    new_quantity_available INTEGER;
BEGIN
    -- Log the trigger firing
    RAISE NOTICE '🔔 Restore quantity trigger fired for order: %', NEW.id;
    
    -- If order is being cancelled and was previously successful
    IF NEW.order_status = 'cancelled' 
       AND OLD.order_status != 'cancelled' 
       AND OLD.payment_status = 'succeeded' THEN
        
        RAISE NOTICE '✅ Restoring quantity for cancelled order %', NEW.id;
        RAISE NOTICE '   Listing ID: %, Quantity: %', NEW.listing_id, NEW.quantity;
        
        -- Get current listing state
        SELECT 
            id,
            title,
            quantity_available,
            quantity_sold,
            archived
        INTO listing_record
        FROM listings
        WHERE id = NEW.listing_id;
        
        IF NOT FOUND THEN
            RAISE WARNING '❌ Listing not found: %', NEW.listing_id;
            RETURN NEW;
        END IF;
        
        RAISE NOTICE '📦 Current listing state:';
        RAISE NOTICE '   Title: %', listing_record.title;
        RAISE NOTICE '   Available: %, Sold: %, Archived: %',
            listing_record.quantity_available, listing_record.quantity_sold, listing_record.archived;
        
        -- Calculate new quantity
        new_quantity_available := COALESCE(listing_record.quantity_available, 0) + COALESCE(NEW.quantity, 1);
        
        RAISE NOTICE '🔢 New quantity_available will be: %', new_quantity_available;
        
        -- Restore the listing quantity and unarchive if needed
        UPDATE listings
        SET 
            quantity_available = new_quantity_available,
            quantity_sold = GREATEST(0, COALESCE(quantity_sold, 0) - COALESCE(NEW.quantity, 1)),
            archived = CASE 
                WHEN new_quantity_available > 0 THEN false
                ELSE archived
            END,
            is_sold = CASE 
                WHEN new_quantity_available > 0 THEN false
                ELSE is_sold
            END
        WHERE id = NEW.listing_id;
        
        IF new_quantity_available > 0 THEN
            RAISE NOTICE '✅ Listing % unarchived and restored', NEW.listing_id;
        ELSE
            RAISE NOTICE '✅ Listing % quantity restored but still archived (0 units)', NEW.listing_id;
        END IF;
        
    ELSE
        RAISE NOTICE '⏭️  Skipping restore - conditions not met';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PART 4: Create Triggers
-- ============================================

-- Trigger for new orders (purchases)
CREATE TRIGGER update_listing_quantity_after_order
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_listing_quantity_on_order();

-- Trigger for order cancellations
CREATE TRIGGER restore_listing_quantity_on_order_cancel
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (NEW.order_status = 'cancelled' AND OLD.order_status != 'cancelled')
    EXECUTE FUNCTION restore_listing_quantity_on_cancel();

-- ============================================
-- PART 5: Retroactive Fix - Archive Old Sold-Out Listings
-- ============================================

-- First, let's see what needs fixing
DO $$
DECLARE
    fix_count INTEGER;
BEGIN
    -- Count how many listings need to be archived
    SELECT COUNT(*) INTO fix_count
    FROM listings
    WHERE quantity_available <= 0 AND archived = false;
    
    RAISE NOTICE '============================================';
    RAISE NOTICE '🔍 RETROACTIVE FIX: Found % listings that should be archived', fix_count;
    RAISE NOTICE '============================================';
    
    IF fix_count > 0 THEN
        -- Archive them AND mark as sold
        UPDATE listings
        SET 
            archived = true,
            is_sold = true
        WHERE quantity_available <= 0
          AND archived = false;
        
        RAISE NOTICE '✅ Archived and marked as sold % listings', fix_count;
    ELSE
        RAISE NOTICE 'ℹ️  No retroactive fixes needed';
    END IF;
END $$;

-- ============================================
-- PART 6: Verification
-- ============================================

-- Check triggers were created
SELECT 
    '✅ TRIGGER VERIFICATION' as check_type,
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel')
ORDER BY trigger_name;

-- Check functions were created
SELECT 
    '✅ FUNCTION VERIFICATION' as check_type,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name IN ('update_listing_quantity_on_order', 'restore_listing_quantity_on_cancel')
  AND routine_schema = 'public'
ORDER BY routine_name;

-- Check current state of sold-out listings
SELECT 
    '✅ LISTING STATE VERIFICATION' as check_type,
    COUNT(*) FILTER (WHERE quantity_available <= 0 AND archived = true) as correctly_archived,
    COUNT(*) FILTER (WHERE quantity_available <= 0 AND archived = false) as incorrectly_visible,
    COUNT(*) FILTER (WHERE quantity_available > 0) as still_available
FROM listings;

-- ============================================
-- DONE! 🎉
-- ============================================

-- Summary of what was deployed:
SELECT '
============================================
✅ DEPLOYMENT COMPLETE
============================================

What was deployed:
1. ✅ Auto-archive trigger for new orders
2. ✅ Auto-restore trigger for order cancellations
3. ✅ Retroactive fix for old sold-out listings

What happens now:
- New purchases → quantity decreases → auto-archives at 0
- Order cancellations → quantity restores → auto-unarchives
- Old sold-out listings → now archived
- App will hide all archived listings automatically

Test it:
1. Create a test listing with quantity = 1
2. Buy it with another account
3. Check the listing is archived and hidden

Notes:
- No app rebuild needed
- Frontend already filters archived listings
- This is a pure backend fix
============================================
' as deployment_summary;

