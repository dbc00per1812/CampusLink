-- ============================================
-- FIX AUTO-ARCHIVE SYSTEM (COMPLETE DEPLOYMENT)
-- ============================================
-- This script will deploy/redeploy the auto-archive system
-- Run this in Supabase SQL Editor to ensure posts archive after purchase

-- ============================================
-- PART 1: DROP EXISTING (if any)
-- ============================================

DROP TRIGGER IF EXISTS update_listing_quantity_after_order ON orders;
DROP TRIGGER IF EXISTS restore_listing_quantity_on_order_cancel ON orders;
DROP FUNCTION IF EXISTS update_listing_quantity_on_order();
DROP FUNCTION IF EXISTS restore_listing_quantity_on_cancel();

-- ============================================
-- PART 2: CREATE PURCHASE TRIGGER FUNCTION
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
        
        -- Update the listing quantity
        UPDATE listings
        SET 
            quantity_available = new_quantity_available,
            quantity_sold = COALESCE(quantity_sold, 0) + COALESCE(NEW.quantity, 1),
            archived = CASE 
                WHEN new_quantity_available <= 0 THEN true
                ELSE archived
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
-- PART 3: CREATE CANCELLATION TRIGGER FUNCTION
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
-- PART 4: CREATE TRIGGERS
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
-- PART 5: VERIFY DEPLOYMENT
-- ============================================

-- Check triggers were created
SELECT 
    '✅ TRIGGERS CREATED:' as status,
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel')
ORDER BY trigger_name;

-- Check functions were created
SELECT 
    '✅ FUNCTIONS CREATED:' as status,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name IN ('update_listing_quantity_on_order', 'restore_listing_quantity_on_cancel')
  AND routine_schema = 'public'
ORDER BY routine_name;

-- ============================================
-- PART 6: TEST THE SYSTEM (OPTIONAL)
-- ============================================

-- Uncomment below to test with a specific order
-- Replace the UUID with an actual order ID from your database

/*
-- First, get a test order
SELECT 
    o.id as order_id,
    o.listing_id,
    o.payment_status,
    o.order_status,
    o.quantity,
    l.title,
    l.quantity_available,
    l.quantity_sold,
    l.archived
FROM orders o
JOIN listings l ON l.id = o.listing_id
ORDER BY o.created_at DESC
LIMIT 5;

-- To manually test, update an order to trigger the archiving:
-- (Replace 'YOUR-ORDER-ID' with actual order ID)
-- UPDATE orders 
-- SET payment_status = 'succeeded', order_status = 'placed'
-- WHERE id = 'YOUR-ORDER-ID';

-- Then check if the listing was archived:
-- SELECT id, title, quantity_available, quantity_sold, archived
-- FROM listings
-- WHERE id = (SELECT listing_id FROM orders WHERE id = 'YOUR-ORDER-ID');
*/

-- ============================================
-- DONE! 🎉
-- ============================================

-- The auto-archive system is now deployed and ready.
-- New purchases will automatically:
-- 1. Decrement quantity_available
-- 2. Increment quantity_sold
-- 3. Set archived=true when quantity_available reaches 0

-- Cancellations will automatically:
-- 1. Restore quantity_available
-- 2. Decrement quantity_sold
-- 3. Set archived=false if quantity > 0

