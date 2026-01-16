-- ============================================================================
-- ONESIGNAL NOTIFICATION TRIGGERS
-- ============================================================================
-- Run this in Supabase SQL Editor to enable automatic push notifications
-- via OneSignal for all key events.
--
-- Prerequisites:
-- 1. pg_net extension enabled (Dashboard > Database > Extensions > pg_net)
-- 2. send-push-onesignal edge function deployed
-- 3. OneSignal secrets set in Supabase
-- ============================================================================


-- ============================================================================
-- STEP 1: Enable pg_net extension (if not already enabled)
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;


-- ============================================================================
-- STEP 2: Create the main notification sender function
-- ============================================================================
-- This function calls the send-push-onesignal edge function

CREATE OR REPLACE FUNCTION send_onesignal_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS void AS $$
BEGIN
    -- Call the OneSignal edge function asynchronously
    PERFORM net.http_post(
        url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-onesignal',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw'
        ),
        body := jsonb_build_object(
            'user_id', p_user_id,
            'title', p_title,
            'body', p_body,
            'data', p_data
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- TRIGGER 1: NEW MESSAGE NOTIFICATIONS
-- ============================================================================
-- Notifies recipient when they receive a new message

CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    sender_name TEXT;
    recipient_id UUID;
BEGIN
    -- Get sender name
    SELECT COALESCE(full_name, username, 'Someone') INTO sender_name
    FROM users WHERE id = NEW.sender_id;
    
    -- Get recipient (the other participant in the conversation)
    SELECT 
        CASE 
            WHEN c.user1_id = NEW.sender_id THEN c.user2_id 
            ELSE c.user1_id 
        END INTO recipient_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    -- Don't notify if recipient is the sender
    IF recipient_id IS NOT NULL AND recipient_id != NEW.sender_id THEN
        PERFORM send_onesignal_notification(
            recipient_id,
            sender_name,
            LEFT(NEW.content, 100),
            jsonb_build_object(
                'type', 'new_message',
                'conversation_id', NEW.conversation_id,
                'message_id', NEW.id,
                'screen', 'Chat'
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_message ON messages;
CREATE TRIGGER on_new_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();


-- ============================================================================
-- TRIGGER 2: NEW OFFER NOTIFICATIONS
-- ============================================================================
-- Notifies seller when they receive a new offer

CREATE OR REPLACE FUNCTION notify_new_offer()
RETURNS TRIGGER AS $$
DECLARE
    buyer_name TEXT;
    listing_title TEXT;
    offer_amount_dollars TEXT;
BEGIN
    -- Get buyer name
    SELECT COALESCE(full_name, username, 'A buyer') INTO buyer_name
    FROM users WHERE id = NEW.buyer_id;
    
    -- Get listing title
    SELECT title INTO listing_title
    FROM listings WHERE id = NEW.listing_id;
    
    -- Format offer amount
    offer_amount_dollars := '$' || (NEW.offer_amount / 100.0)::TEXT;
    
    -- Notify seller
    PERFORM send_onesignal_notification(
        NEW.seller_id,
        'New Offer Received',
        buyer_name || ' offered ' || offer_amount_dollars || ' for "' || LEFT(listing_title, 30) || '"',
        jsonb_build_object(
            'type', 'new_offer',
            'offer_id', NEW.id,
            'listing_id', NEW.listing_id,
            'screen', 'ListingDetail'
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_offer ON offers;
CREATE TRIGGER on_new_offer
    AFTER INSERT ON offers
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_offer();


-- ============================================================================
-- TRIGGER 3: OFFER STATUS CHANGE NOTIFICATIONS
-- ============================================================================
-- Notifies buyer when their offer is accepted/rejected

CREATE OR REPLACE FUNCTION notify_offer_status_change()
RETURNS TRIGGER AS $$
DECLARE
    listing_title TEXT;
    notification_title TEXT;
    notification_body TEXT;
BEGIN
    -- Only trigger on status change
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- Get listing title
    SELECT title INTO listing_title
    FROM listings WHERE id = NEW.listing_id;
    
    -- Set notification content based on status
    IF NEW.status = 'accepted' THEN
        notification_title := 'Offer Accepted! 🎉';
        notification_body := 'Your offer for "' || LEFT(listing_title, 30) || '" was accepted! Complete your purchase now.';
    ELSIF NEW.status = 'rejected' THEN
        notification_title := 'Offer Declined';
        notification_body := 'Your offer for "' || LEFT(listing_title, 30) || '" was not accepted.';
    ELSIF NEW.status = 'countered' THEN
        notification_title := 'Counter Offer Received';
        notification_body := 'The seller sent a counter offer for "' || LEFT(listing_title, 30) || '"';
    ELSE
        RETURN NEW;
    END IF;
    
    -- Notify buyer
    PERFORM send_onesignal_notification(
        NEW.buyer_id,
        notification_title,
        notification_body,
        jsonb_build_object(
            'type', 'offer_' || NEW.status,
            'offer_id', NEW.id,
            'listing_id', NEW.listing_id,
            'screen', 'ListingDetail'
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_offer_status_change ON offers;
CREATE TRIGGER on_offer_status_change
    AFTER UPDATE ON offers
    FOR EACH ROW
    EXECUTE FUNCTION notify_offer_status_change();


-- ============================================================================
-- TRIGGER 4: ORDER PLACED NOTIFICATION (to seller)
-- ============================================================================
-- Notifies seller when a new order is placed

CREATE OR REPLACE FUNCTION notify_order_placed()
RETURNS TRIGGER AS $$
DECLARE
    buyer_name TEXT;
    listing_title TEXT;
    order_amount TEXT;
BEGIN
    -- Get buyer name
    SELECT COALESCE(full_name, username, 'A buyer') INTO buyer_name
    FROM users WHERE id = NEW.buyer_id;
    
    -- Get listing title
    SELECT title INTO listing_title
    FROM listings WHERE id = NEW.listing_id;
    
    -- Format amount
    order_amount := '$' || (NEW.total_amount / 100.0)::TEXT;
    
    -- Notify seller
    PERFORM send_onesignal_notification(
        NEW.seller_id,
        'New Order! 💰',
        buyer_name || ' purchased "' || LEFT(listing_title, 25) || '" for ' || order_amount,
        jsonb_build_object(
            'type', 'order_placed',
            'order_id', NEW.id,
            'listing_id', NEW.listing_id,
            'screen', 'OrderDetail'
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_placed ON orders;
CREATE TRIGGER on_order_placed
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_placed();


-- ============================================================================
-- TRIGGER 5: ORDER STATUS UPDATE NOTIFICATIONS
-- ============================================================================
-- Notifies buyer/seller on order status changes

CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    listing_title TEXT;
    other_party_name TEXT;
    notify_user_id UUID;
    notification_title TEXT;
    notification_body TEXT;
BEGIN
    -- Only trigger on status change
    IF OLD.order_status = NEW.order_status THEN
        RETURN NEW;
    END IF;
    
    -- Get listing title
    SELECT title INTO listing_title
    FROM listings WHERE id = NEW.listing_id;
    
    -- Handle different status changes
    CASE NEW.order_status
        WHEN 'seller_confirmed' THEN
            -- Notify buyer that seller confirmed
            SELECT COALESCE(full_name, username, 'Seller') INTO other_party_name
            FROM users WHERE id = NEW.seller_id;
            
            notify_user_id := NEW.buyer_id;
            notification_title := 'Order Confirmed';
            notification_body := other_party_name || ' confirmed your order for "' || LEFT(listing_title, 25) || '"';
            
        WHEN 'in_progress' THEN
            -- Notify buyer
            notify_user_id := NEW.buyer_id;
            notification_title := 'Order In Progress';
            notification_body := 'Your order for "' || LEFT(listing_title, 25) || '" is being prepared';
            
        WHEN 'delivered' THEN
            -- Notify buyer to confirm receipt
            notify_user_id := NEW.buyer_id;
            notification_title := 'Order Delivered! 📦';
            notification_body := 'Please confirm you received "' || LEFT(listing_title, 25) || '"';
            
        WHEN 'completed' THEN
            -- Notify seller that payment is released
            notify_user_id := NEW.seller_id;
            notification_title := 'Payment Released! 💵';
            notification_body := 'Your payment for "' || LEFT(listing_title, 25) || '" has been released';
            
        WHEN 'cancelled' THEN
            -- Notify both parties
            -- First notify buyer
            PERFORM send_onesignal_notification(
                NEW.buyer_id,
                'Order Cancelled',
                'Your order for "' || LEFT(listing_title, 25) || '" has been cancelled',
                jsonb_build_object(
                    'type', 'order_cancelled',
                    'order_id', NEW.id,
                    'screen', 'OrderDetail'
                )
            );
            -- Then notify seller
            notify_user_id := NEW.seller_id;
            notification_title := 'Order Cancelled';
            notification_body := 'Order for "' || LEFT(listing_title, 25) || '" has been cancelled';
            
        ELSE
            RETURN NEW;
    END CASE;
    
    -- Send notification
    IF notify_user_id IS NOT NULL THEN
        PERFORM send_onesignal_notification(
            notify_user_id,
            notification_title,
            notification_body,
            jsonb_build_object(
                'type', 'order_' || NEW.order_status,
                'order_id', NEW.id,
                'screen', 'OrderDetail'
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_status_change ON orders;
CREATE TRIGGER on_order_status_change
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_status_change();


-- ============================================================================
-- TRIGGER 6: PAYOUT NOTIFICATIONS
-- ============================================================================
-- Notifies seller when payout is processed

CREATE OR REPLACE FUNCTION notify_payout_status()
RETURNS TRIGGER AS $$
DECLARE
    payout_amount TEXT;
    notification_title TEXT;
    notification_body TEXT;
BEGIN
    -- Only trigger on status change
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- Format amount
    payout_amount := '$' || (NEW.amount / 100.0)::TEXT;
    
    -- Handle different statuses
    CASE NEW.status
        WHEN 'completed' THEN
            notification_title := 'Payout Complete! 🎉';
            notification_body := payout_amount || ' has been sent to your bank account';
        WHEN 'failed' THEN
            notification_title := 'Payout Failed';
            notification_body := 'Your ' || payout_amount || ' payout could not be processed. Please check your bank details.';
        WHEN 'processing' THEN
            notification_title := 'Payout Processing';
            notification_body := payout_amount || ' is being transferred to your bank (1-3 business days)';
        ELSE
            RETURN NEW;
    END CASE;
    
    -- Notify seller
    PERFORM send_onesignal_notification(
        NEW.user_id,
        notification_title,
        notification_body,
        jsonb_build_object(
            'type', 'payout_' || NEW.status,
            'payout_id', NEW.id,
            'screen', 'Wallet'
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_payout_status ON payouts;
CREATE TRIGGER on_payout_status
    AFTER UPDATE ON payouts
    FOR EACH ROW
    EXECUTE FUNCTION notify_payout_status();


-- ============================================================================
-- TRIGGER 7: NEW RATING NOTIFICATION
-- ============================================================================
-- Notifies user when they receive a new rating

CREATE OR REPLACE FUNCTION notify_new_rating()
RETURNS TRIGGER AS $$
DECLARE
    rater_name TEXT;
    stars_text TEXT;
BEGIN
    -- Get rater name
    SELECT COALESCE(full_name, username, 'Someone') INTO rater_name
    FROM users WHERE id = NEW.rater_id;
    
    -- Format stars
    stars_text := NEW.rating || ' star' || CASE WHEN NEW.rating > 1 THEN 's' ELSE '' END;
    
    -- Notify rated user
    PERFORM send_onesignal_notification(
        NEW.rated_user_id,
        'New Review ⭐',
        rater_name || ' gave you ' || stars_text || CASE WHEN NEW.comment IS NOT NULL THEN ': "' || LEFT(NEW.comment, 50) || '"' ELSE '' END,
        jsonb_build_object(
            'type', 'new_rating',
            'rating_id', NEW.id,
            'order_id', NEW.order_id,
            'screen', 'Profile'
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_rating ON ratings;
CREATE TRIGGER on_new_rating
    AFTER INSERT ON ratings
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_rating();


-- ============================================================================
-- VERIFICATION: List all notification triggers
-- ============================================================================

SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    CASE WHEN tgenabled = 'O' THEN '✅ ENABLED' ELSE '❌ DISABLED' END AS status
FROM pg_trigger 
WHERE tgname IN (
    'on_new_message',
    'on_new_offer', 
    'on_offer_status_change',
    'on_order_placed',
    'on_order_status_change',
    'on_payout_status',
    'on_new_rating'
)
ORDER BY tgrelid::regclass::text;


-- ============================================================================
-- DONE! 
-- ============================================================================
-- Push notifications are now enabled for:
-- ✅ New messages
-- ✅ New offers
-- ✅ Offer accepted/rejected/countered
-- ✅ Order placed
-- ✅ Order status changes (confirmed, in_progress, delivered, completed, cancelled)
-- ✅ Payout status (processing, completed, failed)
-- ✅ New ratings
-- ============================================================================
