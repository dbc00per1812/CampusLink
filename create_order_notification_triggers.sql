-- Order Notification Triggers
-- This creates the same automatic notification system for orders that messages use
-- Run this in Supabase SQL Editor

-- ============================================
-- FUNCTION: Create notification for new order
-- ============================================
CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS TRIGGER AS $$
DECLARE
    v_listing_title TEXT;
BEGIN
    -- Get listing title for notification
    SELECT title INTO v_listing_title
    FROM listings
    WHERE id = NEW.listing_id;
    
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
        NEW.seller_id::text,
        'order_placed',
        'New Order!',
        'You have a new order for "' || COALESCE(v_listing_title, 'an item') || '"',
        jsonb_build_object('order_id', NEW.id::text),
        NEW.id,
        NEW.listing_id,
        NEW.buyer_id::text,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Create notification when order marked delivered
-- ============================================
CREATE OR REPLACE FUNCTION notify_order_delivered()
RETURNS TRIGGER AS $$
DECLARE
    v_listing_title TEXT;
BEGIN
    -- Only trigger when status changes TO seller_confirmed
    IF NEW.order_status = 'seller_confirmed' AND OLD.order_status != 'seller_confirmed' THEN
        -- Get listing title
        SELECT title INTO v_listing_title
        FROM listings
        WHERE id = NEW.listing_id;
        
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
            NEW.buyer_id::text,
            'order_confirmed',
            'Order Confirmed!',
            'Your order for "' || COALESCE(v_listing_title, 'an item') || '" has been confirmed',
            jsonb_build_object('order_id', NEW.id::text),
            NEW.id,
            NEW.listing_id,
            NEW.seller_id::text,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Create notification when order completed
-- ============================================
CREATE OR REPLACE FUNCTION notify_order_completed()
RETURNS TRIGGER AS $$
DECLARE
    v_listing_title TEXT;
BEGIN
    -- Only trigger when status changes TO completed
    IF NEW.order_status = 'completed' AND OLD.order_status != 'completed' THEN
        -- Get listing title
        SELECT title INTO v_listing_title
        FROM listings
        WHERE id = NEW.listing_id;
        
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
            NEW.seller_id::text,
            'order_completed',
            'Order Completed!',
            'Your order for "' || COALESCE(v_listing_title, 'an item') || '" has been completed',
            jsonb_build_object('order_id', NEW.id::text),
            NEW.id,
            NEW.listing_id,
            NEW.buyer_id::text,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- DROP EXISTING TRIGGERS (if they exist)
-- ============================================
DROP TRIGGER IF EXISTS order_created_notification_trigger ON orders;
DROP TRIGGER IF EXISTS order_status_notification_trigger ON orders;

-- ============================================
-- CREATE TRIGGERS
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

-- Trigger for order completion (AFTER UPDATE)  
CREATE TRIGGER order_completed_notification_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
    EXECUTE FUNCTION notify_order_completed();

-- ============================================
-- TEST THE TRIGGERS (optional)
-- ============================================
-- After running the above, create a test order and check:
-- SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;

-- ============================================
-- CLEANUP (Remove app-level notification calls)
-- ============================================
-- After confirming triggers work, you can remove these lines from Swift code:
-- 1. OrderService.swift line ~98: await NotificationService.shared.createOrderNotification(...)
-- 2. OrderService.swift line ~201: await NotificationService.shared.createOrderNotification(...)
-- 3. OrderService.swift line ~291: await NotificationService.shared.createOrderNotification(...)


