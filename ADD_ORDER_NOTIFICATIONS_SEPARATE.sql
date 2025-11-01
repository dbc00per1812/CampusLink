-- ============================================
-- ADD ORDER NOTIFICATIONS
-- This script ONLY touches orders table
-- NEVER touches messages table
-- Run this AFTER messages are working
-- ============================================

-- Clean up any existing order notification triggers
DROP TRIGGER IF EXISTS order_created_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_status_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_completed_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_cancelled_notification_trigger ON orders CASCADE;

DROP FUNCTION IF EXISTS notify_new_order() CASCADE;
DROP FUNCTION IF EXISTS notify_order_status_change() CASCADE;

-- ============================================
-- FUNCTION: Notify when new order is created
-- ============================================
CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_listing_title TEXT;
    v_buyer_name TEXT;
BEGIN
    -- Get listing title and buyer name
    SELECT l.title, u.name 
    INTO v_listing_title, v_buyer_name
    FROM listings l
    LEFT JOIN users u ON u.id = NEW.buyer_id
    WHERE l.id = NEW.listing_id;
    
    -- Create notification for seller
    INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        order_id,
        listing_id,
        related_user_id,
        created_at
    ) VALUES (
        NEW.seller_id,
        'order_placed',
        'New Order!',
        COALESCE(v_buyer_name, 'Someone') || ' placed an order for "' || COALESCE(v_listing_title, 'your item') || '"',
        jsonb_build_object('order_id', NEW.id::text, 'price_cents', NEW.price_cents),
        NEW.id,
        NEW.listing_id,
        NEW.buyer_id,
        NOW()
    );
    
    RETURN NEW;
END;
$$;

-- ============================================
-- FUNCTION: Notify when order status changes
-- ============================================
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_listing_title TEXT;
    v_buyer_name TEXT;
    v_seller_name TEXT;
BEGIN
    -- Only trigger if status actually changed
    IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
        
        -- Get names and title
        SELECT l.title, ub.name, us.name 
        INTO v_listing_title, v_buyer_name, v_seller_name
        FROM listings l
        LEFT JOIN users ub ON ub.id = NEW.buyer_id
        LEFT JOIN users us ON us.id = NEW.seller_id
        WHERE l.id = NEW.listing_id;
        
        -- Notify buyer when seller confirms delivery
        IF NEW.order_status = 'seller_confirmed' THEN
            INSERT INTO notifications (
                user_id, type, title, body, data, order_id, listing_id, related_user_id, created_at
            ) VALUES (
                NEW.buyer_id,
                'order_confirmed',
                'Order Ready!',
                COALESCE(v_seller_name, 'The seller') || ' marked your order for "' || COALESCE(v_listing_title, 'an item') || '" as ready',
                jsonb_build_object('order_id', NEW.id::text),
                NEW.id,
                NEW.listing_id,
                NEW.seller_id,
                NOW()
            );
        END IF;
        
        -- Notify seller when buyer completes order
        IF NEW.order_status = 'completed' THEN
            INSERT INTO notifications (
                user_id, type, title, body, data, order_id, listing_id, related_user_id, created_at
            ) VALUES (
                NEW.seller_id,
                'order_completed',
                'Order Completed!',
                COALESCE(v_buyer_name, 'The buyer') || ' confirmed receipt of "' || COALESCE(v_listing_title, 'your item') || '"',
                jsonb_build_object('order_id', NEW.id::text, 'amount_cents', NEW.price_cents),
                NEW.id,
                NEW.listing_id,
                NEW.buyer_id,
                NOW()
            );
        END IF;
        
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================
-- CREATE TRIGGERS
-- ============================================

-- Trigger for new orders
CREATE TRIGGER order_created_notification_trigger
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_order();

-- Trigger for order status changes
CREATE TRIGGER order_status_notification_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
    EXECUTE FUNCTION notify_order_status_change();

-- Grant permissions
GRANT EXECUTE ON FUNCTION notify_new_order() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_order_status_change() TO authenticated;

-- Verify
SELECT 'Order notification triggers installed' as status;

SELECT 
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'orders'
ORDER BY trigger_name;


