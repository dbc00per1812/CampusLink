-- Offer Notification Triggers
-- This creates automatic notifications for offer events (same as messages)
-- Run this in Supabase SQL Editor

-- ============================================
-- FUNCTION: Create notification for new offer
-- ============================================
CREATE OR REPLACE FUNCTION notify_new_offer()
RETURNS TRIGGER AS $$
DECLARE
    v_seek_title TEXT;
BEGIN
    -- Get seek listing title
    SELECT title INTO v_seek_title
    FROM listings
    WHERE id = NEW.seek_listing_id;
    
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
        'Someone offered $' || COALESCE((NEW.price_cents::float / 100)::text, '?') || ' for your post "' || COALESCE(v_seek_title, 'an item') || '"',
        jsonb_build_object(
            'offer_id', NEW.id::text,
            'price_cents', NEW.price_cents
        ),
        NEW.seek_listing_id,
        NEW.seller_id,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Create notification for offer status changes
-- ============================================
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
        v_price_formatted := '$' || COALESCE((NEW.price_cents::float / 100)::text, '?');
        
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
                jsonb_build_object('offer_id', NEW.id::text),
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
                'Your offer of ' || v_price_formatted || ' was declined.',
                jsonb_build_object('offer_id', NEW.id::text),
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
-- DROP EXISTING TRIGGERS (if they exist)
-- ============================================
DROP TRIGGER IF EXISTS offer_created_notification_trigger ON offers;
DROP TRIGGER IF EXISTS offer_status_notification_trigger ON offers;

-- ============================================
-- CREATE TRIGGERS
-- ============================================

-- Trigger for new offers (AFTER INSERT)
CREATE TRIGGER offer_created_notification_trigger
    AFTER INSERT ON offers
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_offer();

-- Trigger for offer status changes (AFTER UPDATE)
CREATE TRIGGER offer_status_notification_trigger
    AFTER UPDATE ON offers
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION notify_offer_status_change();

-- ============================================
-- TEST THE TRIGGERS (optional)
-- ============================================
-- After running the above, create a test offer and check:
-- SELECT * FROM notifications WHERE type IN ('listing_interest', 'marketplace_activity') 
-- ORDER BY created_at DESC LIMIT 5;

-- ============================================
-- CLEANUP (Remove app-level notification calls)
-- ============================================
-- After confirming triggers work, you can remove these lines from Swift code:
-- 1. OfferComposeView.swift line ~347-360: await NotificationService.shared.createNotification(...)
-- 2. OfferService.swift line ~58-71: await NotificationService.shared.createNotification(...)
-- 3. OfferService.swift line ~119-132: await NotificationService.shared.createNotification(...)


