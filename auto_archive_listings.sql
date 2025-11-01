-- Auto-Archive Listings When Sold Out
-- This script creates triggers to automatically manage listing quantities and archive them when sold out

-- Function to update listing quantity after order creation
CREATE OR REPLACE FUNCTION update_listing_quantity_on_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if order is successfully placed (payment succeeded)
    IF NEW.payment_status = 'succeeded' AND NEW.order_status IN ('placed', 'confirmed') THEN
        -- Update the listing quantity
        UPDATE listings
        SET 
            quantity_available = GREATEST(0, COALESCE(quantity_available, 1) - COALESCE(NEW.quantity, 1)),
            quantity_sold = COALESCE(quantity_sold, 0) + COALESCE(NEW.quantity, 1),
            archived = CASE 
                WHEN (COALESCE(quantity_available, 1) - COALESCE(NEW.quantity, 1)) <= 0 THEN true
                ELSE archived
            END
        WHERE id = NEW.listing_id;
        
        RAISE NOTICE 'Updated listing % quantity: available decreased by %, archived if out of stock', 
            NEW.listing_id, NEW.quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_listing_quantity_after_order ON orders;

-- Create trigger that fires after order insert
CREATE TRIGGER update_listing_quantity_after_order
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_listing_quantity_on_order();

-- Function to handle order cancellations (restore quantity)
CREATE OR REPLACE FUNCTION restore_listing_quantity_on_cancel()
RETURNS TRIGGER AS $$
BEGIN
    -- If order is being cancelled and was previously successful
    IF NEW.order_status = 'cancelled' AND OLD.order_status != 'cancelled' 
       AND OLD.payment_status = 'succeeded' THEN
        
        -- Restore the listing quantity and unarchive if needed
        UPDATE listings
        SET 
            quantity_available = COALESCE(quantity_available, 0) + COALESCE(NEW.quantity, 1),
            quantity_sold = GREATEST(0, COALESCE(quantity_sold, 0) - COALESCE(NEW.quantity, 1)),
            archived = CASE 
                WHEN (COALESCE(quantity_available, 0) + COALESCE(NEW.quantity, 1)) > 0 THEN false
                ELSE archived
            END
        WHERE id = NEW.listing_id;
        
        RAISE NOTICE 'Restored listing % quantity: available increased by %, unarchived if back in stock', 
            NEW.listing_id, NEW.quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS restore_listing_quantity_on_order_cancel ON orders;

-- Create trigger that fires after order update (for cancellations)
CREATE TRIGGER restore_listing_quantity_on_order_cancel
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (NEW.order_status = 'cancelled' AND OLD.order_status != 'cancelled')
    EXECUTE FUNCTION restore_listing_quantity_on_cancel();

-- Verify the triggers were created
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel')
ORDER BY trigger_name;

