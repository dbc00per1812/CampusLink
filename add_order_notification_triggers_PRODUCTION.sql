-- ============================================
-- ADD ORDER NOTIFICATION TRIGGERS - PRODUCTION READY
-- Matches the WORKING message notification pattern exactly
-- Run this in Supabase SQL Editor AFTER confirming Swift notifications work
-- ============================================

-- ============================================
-- STEP 1: Drop any existing order triggers (cleanup)
-- ============================================
DROP TRIGGER IF EXISTS order_created_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_status_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_completed_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_cancelled_notification_trigger ON orders CASCADE;

DROP FUNCTION IF EXISTS notify_new_order() CASCADE;
DROP FUNCTION IF EXISTS notify_order_delivered() CASCADE;
DROP FUNCTION IF EXISTS notify_order_completed() CASCADE;
DROP FUNCTION IF EXISTS notify_order_cancelled() CASCADE;

-- ============================================
-- STEP 2: Create notification functions
-- Pattern copied EXACTLY from working message notifications
-- ============================================

-- Function: Notify seller when new order is placed
CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS TRIGGER AS $$
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
    -- USER_ID and RELATED_USER_ID are UUID (no ::text casting!)
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
        NEW.seller_id,                                                 -- UUID directly
        'order_placed',
        'New Order!',
        COALESCE(v_buyer_name, 'Someone') || ' placed an order for "' || COALESCE(v_listing_title, 'your item') || '"',
        jsonb_build_object('order_id', NEW.id::text),                 -- Only ::text in JSONB
        NEW.id,
        NEW.listing_id,
        NEW.buyer_id,                                                  -- UUID directly
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Notify buyer when seller confirms delivery
CREATE OR REPLACE FUNCTION notify_order_delivered()
RETURNS TRIGGER AS $$
DECLARE
    v_listing_title TEXT;
    v_seller_name TEXT;
BEGIN
    -- Only trigger when status changes TO seller_confirmed
    IF NEW.order_status = 'seller_confirmed' AND (OLD.order_status IS NULL OR OLD.order_status != 'seller_confirmed') THEN
        -- Get listing title and seller name
        SELECT l.title, u.name 
        INTO v_listing_title, v_seller_name
        FROM listings l
        LEFT JOIN users u ON u.id = NEW.seller_id
        WHERE l.id = NEW.listing_id;
        
        -- Create notification for buyer
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
            NEW.buyer_id,                                              -- UUID directly
            'order_confirmed',
            'Order Ready!',
            COALESCE(v_seller_name, 'The seller') || ' marked your order for "' || COALESCE(v_listing_title, 'an item') || '" as ready',
            jsonb_build_object('order_id', NEW.id::text, 'has_delivery_photo', NEW.delivery_photo_url IS NOT NULL),
            NEW.id,
            NEW.listing_id,
            NEW.seller_id,                                             -- UUID directly
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Notify seller when buyer confirms receipt
CREATE OR REPLACE FUNCTION notify_order_completed()
RETURNS TRIGGER AS $$
DECLARE
    v_listing_title TEXT;
    v_buyer_name TEXT;
BEGIN
    -- Only trigger when status changes TO completed
    IF NEW.order_status = 'completed' AND (OLD.order_status IS NULL OR OLD.order_status != 'completed') THEN
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
            NEW.seller_id,                                             -- UUID directly
            'order_completed',
            'Order Completed!',
            COALESCE(v_buyer_name, 'The buyer') || ' confirmed receipt of "' || COALESCE(v_listing_title, 'your item') || '"',
            jsonb_build_object('order_id', NEW.id::text, 'amount_cents', NEW.price_cents),
            NEW.id,
            NEW.listing_id,
            NEW.buyer_id,                                              -- UUID directly
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Notify both parties when order is cancelled
CREATE OR REPLACE FUNCTION notify_order_cancelled()
RETURNS TRIGGER AS $$
DECLARE
    v_listing_title TEXT;
    v_buyer_name TEXT;
    v_seller_name TEXT;
BEGIN
    -- Only trigger when status changes TO cancelled
    IF NEW.order_status = 'cancelled' AND (OLD.order_status IS NULL OR OLD.order_status != 'cancelled') THEN
        -- Get listing title and user names
        SELECT l.title, ub.name, us.name 
        INTO v_listing_title, v_buyer_name, v_seller_name
        FROM listings l
        LEFT JOIN users ub ON ub.id = NEW.buyer_id
        LEFT JOIN users us ON us.id = NEW.seller_id
        WHERE l.id = NEW.listing_id;
        
        -- Create notification for buyer
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
            NEW.buyer_id,                                              -- UUID directly
            'order_cancelled',
            'Order Cancelled',
            'Your order for "' || COALESCE(v_listing_title, 'an item') || '" has been cancelled and refunded',
            jsonb_build_object('order_id', NEW.id::text, 'amount_cents', NEW.price_cents),
            NEW.id,
            NEW.listing_id,
            NEW.seller_id,                                             -- UUID directly
            NOW()
        );
        
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
            NEW.seller_id,                                             -- UUID directly
            'order_cancelled',
            'Order Cancelled',
            'The order for "' || COALESCE(v_listing_title, 'your item') || '" has been cancelled',
            jsonb_build_object('order_id', NEW.id::text, 'amount_cents', NEW.price_cents),
            NEW.id,
            NEW.listing_id,
            NEW.buyer_id,                                              -- UUID directly
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 3: Create triggers
-- ============================================

-- Trigger for new orders (AFTER INSERT)
CREATE TRIGGER order_created_notification_trigger
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_order();

-- Trigger for order status changes (AFTER UPDATE)
CREATE TRIGGER order_status_notification_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
    EXECUTE FUNCTION notify_order_delivered();

CREATE TRIGGER order_completed_notification_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
    EXECUTE FUNCTION notify_order_completed();

CREATE TRIGGER order_cancelled_notification_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
    EXECUTE FUNCTION notify_order_cancelled();

-- ============================================
-- STEP 4: Grant permissions
-- ============================================
GRANT EXECUTE ON FUNCTION notify_new_order() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_order_delivered() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_order_completed() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_order_cancelled() TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'orders'
ORDER BY trigger_name;

-- Should show 4 triggers

-- ============================================
-- TESTING INSTRUCTIONS
-- ============================================
/*
IMPORTANT: Keep Swift notification calls active during testing!
This way if triggers fail, notifications still work as backup.

Test 1: Place an order
- Check notifications table:
  SELECT * FROM notifications WHERE type = 'order_placed' ORDER BY created_at DESC LIMIT 1;
- Should see notification for seller

Test 2: Mark order as delivered
- UPDATE orders SET order_status = 'seller_confirmed', seller_confirmed_at = NOW() WHERE id = '[order-id]';
- Check: SELECT * FROM notifications WHERE type = 'order_confirmed' ORDER BY created_at DESC LIMIT 1;
- Should see notification for buyer

Test 3: Complete order
- UPDATE orders SET order_status = 'completed', completed_at = NOW() WHERE id = '[order-id]';
- Check: SELECT * FROM notifications WHERE type = 'order_completed' ORDER BY created_at DESC LIMIT 1;
- Should see notification for seller

IF ALL TESTS PASS:
You can optionally remove the Swift notification calls from OrderService.swift
But keeping both is fine - it just means you get notifications from both sources
(database triggers will fire first, Swift code becomes backup)
*/

