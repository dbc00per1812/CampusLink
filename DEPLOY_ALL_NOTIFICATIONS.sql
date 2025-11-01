-- ============================================
-- DEPLOY ALL NOTIFICATION TRIGGERS - PRODUCTION READY
-- ============================================
-- This script creates database triggers for ALL notifications
-- Following the proven message notification pattern
-- Run this entire script in Supabase SQL Editor
-- ============================================

-- ============================================
-- STEP 1: Clean up any existing triggers
-- ============================================

-- Drop existing message triggers (we'll recreate them)
DROP TRIGGER IF EXISTS message_notification_trigger ON messages CASCADE;
DROP TRIGGER IF EXISTS new_message_notification_trigger ON messages CASCADE;

-- Drop existing order triggers
DROP TRIGGER IF EXISTS order_created_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_status_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_completed_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_cancelled_notification_trigger ON orders CASCADE;

-- Drop existing offer triggers
DROP TRIGGER IF EXISTS offer_created_notification_trigger ON offers CASCADE;
DROP TRIGGER IF EXISTS offer_status_notification_trigger ON offers CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS notify_new_message() CASCADE;
DROP FUNCTION IF EXISTS notify_new_order() CASCADE;
DROP FUNCTION IF EXISTS notify_order_delivered() CASCADE;
DROP FUNCTION IF EXISTS notify_order_completed() CASCADE;
DROP FUNCTION IF EXISTS notify_order_cancelled() CASCADE;
DROP FUNCTION IF EXISTS notify_new_offer() CASCADE;
DROP FUNCTION IF EXISTS notify_offer_status_change() CASCADE;

-- ============================================
-- STEP 2: MESSAGE NOTIFICATION FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_message_preview TEXT;
BEGIN
    -- Get sender's name from users table
    SELECT name INTO v_sender_name
    FROM users
    WHERE id = NEW.sender_id;
    
    -- Determine recipient: the conversation participant who is NOT the sender
    SELECT 
        CASE 
            WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
            ELSE c.buyer_id
        END INTO v_recipient_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    -- Create preview (first 50 chars of message)
    v_message_preview := SUBSTRING(NEW.content, 1, 50);
    IF LENGTH(NEW.content) > 50 THEN
        v_message_preview := v_message_preview || '...';
    END IF;
    
    -- Create notification for the RECIPIENT
    INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        message_id,
        related_user_id,
        created_at
    ) VALUES (
        v_recipient_id,
        'new_message',
        'New Message',
        COALESCE(v_sender_name, 'Someone') || ': ' || v_message_preview,
        jsonb_build_object('message_id', NEW.id::text, 'conversation_id', NEW.conversation_id::text),
        NEW.id,
        NEW.sender_id,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 3: ORDER NOTIFICATION FUNCTIONS
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
            NEW.buyer_id,
            'order_confirmed',
            'Order Ready!',
            COALESCE(v_seller_name, 'The seller') || ' marked your order for "' || COALESCE(v_listing_title, 'an item') || '" as ready',
            jsonb_build_object('order_id', NEW.id::text, 'has_delivery_photo', (NEW.delivery_photo_url IS NOT NULL)),
            NEW.id,
            NEW.listing_id,
            NEW.seller_id,
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
            NEW.buyer_id,
            'order_cancelled',
            'Order Cancelled',
            'Your order for "' || COALESCE(v_listing_title, 'an item') || '" has been cancelled and refunded',
            jsonb_build_object('order_id', NEW.id::text, 'amount_cents', NEW.price_cents),
            NEW.id,
            NEW.listing_id,
            NEW.seller_id,
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
            NEW.seller_id,
            'order_cancelled',
            'Order Cancelled',
            'The order for "' || COALESCE(v_listing_title, 'your item') || '" has been cancelled',
            jsonb_build_object('order_id', NEW.id::text, 'amount_cents', NEW.price_cents),
            NEW.id,
            NEW.listing_id,
            NEW.buyer_id,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 4: OFFER NOTIFICATION FUNCTIONS
-- ============================================

-- Function: Notify seeker when new offer is made
CREATE OR REPLACE FUNCTION notify_new_offer()
RETURNS TRIGGER AS $$
DECLARE
    v_seek_title TEXT;
    v_price_formatted TEXT;
BEGIN
    -- Get seek listing title
    SELECT title INTO v_seek_title
    FROM listings
    WHERE id = NEW.seek_listing_id;
    
    -- Format price
    v_price_formatted := '$' || TRIM(TO_CHAR(NEW.price_cents::float / 100, '999999.99'));
    
    -- Create notification for seeker
    INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        listing_id,
        related_user_id,
        created_at
    ) VALUES (
        NEW.seeker_id,
        'listing_interest',
        'New Offer!',
        'Someone offered ' || v_price_formatted || ' for your post "' || COALESCE(v_seek_title, 'an item') || '"',
        jsonb_build_object('offer_id', NEW.id::text, 'price_cents', NEW.price_cents),
        NEW.seek_listing_id,
        NEW.seller_id,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Notify offer maker when status changes
CREATE OR REPLACE FUNCTION notify_offer_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_seek_title TEXT;
    v_price_formatted TEXT;
BEGIN
    -- Only trigger when status actually changes
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        -- Get seek listing title
        SELECT title INTO v_seek_title
        FROM listings
        WHERE id = NEW.seek_listing_id;
        
        -- Format price
        v_price_formatted := '$' || TRIM(TO_CHAR(NEW.price_cents::float / 100, '999999.99'));
        
        -- Notify offer maker when accepted
        IF NEW.status = 'accepted' THEN
            INSERT INTO notifications (
                user_id,
                type,
                title,
                body,
                data,
                listing_id,
                related_user_id,
                created_at
            ) VALUES (
                NEW.seller_id,
                'marketplace_activity',
                'Offer Accepted!',
                'Your offer of ' || v_price_formatted || ' was accepted. Complete payment to proceed.',
                jsonb_build_object('offer_id', NEW.id::text, 'price_cents', NEW.price_cents),
                NEW.seek_listing_id,
                NEW.seeker_id,
                NOW()
            );
        END IF;
        
        -- Notify offer maker when declined
        IF NEW.status = 'declined' THEN
            INSERT INTO notifications (
                user_id,
                type,
                title,
                body,
                data,
                listing_id,
                related_user_id,
                created_at
            ) VALUES (
                NEW.seller_id,
                'marketplace_activity',
                'Offer Declined',
                'Your offer of ' || v_price_formatted || ' was declined.' || 
                CASE WHEN NEW.decline_reason IS NOT NULL 
                     THEN ' Reason: ' || NEW.decline_reason 
                     ELSE '' END,
                jsonb_build_object('offer_id', NEW.id::text, 'price_cents', NEW.price_cents),
                NEW.seek_listing_id,
                NEW.seeker_id,
                NOW()
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: CREATE ALL TRIGGERS
-- ============================================

-- Message trigger
CREATE TRIGGER message_notification_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

-- Order triggers
CREATE TRIGGER order_created_notification_trigger
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_order();

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

-- Offer triggers
CREATE TRIGGER offer_created_notification_trigger
    AFTER INSERT ON offers
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_offer();

CREATE TRIGGER offer_status_notification_trigger
    AFTER UPDATE ON offers
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION notify_offer_status_change();

-- ============================================
-- STEP 6: Grant permissions
-- ============================================
GRANT EXECUTE ON FUNCTION notify_new_message() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_order() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_order_delivered() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_order_completed() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_order_cancelled() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_offer() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_offer_status_change() TO authenticated;

-- ============================================
-- STEP 7: VERIFICATION QUERIES
-- ============================================

-- Check all triggers are created
SELECT 
    trigger_name,
    event_object_table as table_name,
    action_timing,
    event_manipulation as event
FROM information_schema.triggers
WHERE event_object_table IN ('messages', 'orders', 'offers')
AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Expected results:
-- messages: 1 trigger (message_notification_trigger)
-- orders: 4 triggers (created, status, completed, cancelled)
-- offers: 2 triggers (created, status)
-- TOTAL: 7 triggers

-- Check all functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'notify_%'
ORDER BY routine_name;

-- Expected: 7 functions

-- ============================================
-- DEPLOYMENT COMPLETE!
-- ============================================
-- All notification triggers are now installed
-- Messages, Orders, and Offers will now generate notifications automatically
-- No app-level notification code is required (but can stay as backup)
-- ============================================



