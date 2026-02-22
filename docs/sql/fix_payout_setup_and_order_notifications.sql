-- ============================================================================
-- FIX PAYOUT SETUP COMPLETION & ORDER NOTIFICATIONS
-- ============================================================================
-- This script fixes two issues:
-- 1. Adds notification when payout setup is completed
-- 2. Ensures order notifications are working with proper error handling
-- ============================================================================

-- ============================================================================
-- STEP 1: CHECK CURRENT TRIGGER STATUS
-- ============================================================================
SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    CASE WHEN tgenabled = 'O' THEN '✅ ENABLED' ELSE '❌ DISABLED' END AS status
FROM pg_trigger 
WHERE tgname IN (
    'on_order_placed',
    'on_payout_setup_complete'
)
ORDER BY tgrelid::regclass::text;

-- ============================================================================
-- STEP 2: IMPROVE ORDER PLACED NOTIFICATION TRIGGER
-- ============================================================================
-- This ensures sellers get notified when someone buys from them
-- Added error handling to prevent silent failures

CREATE OR REPLACE FUNCTION notify_order_placed()
RETURNS TRIGGER AS $$
DECLARE
    buyer_name TEXT;
    listing_title TEXT;
    order_amount TEXT;
BEGIN
    -- Get buyer name (using 'name' column)
    SELECT COALESCE(name, 'A buyer') INTO buyer_name
    FROM users WHERE id = NEW.buyer_id;
    
    -- Get listing title
    SELECT COALESCE(title, 'an item') INTO listing_title
    FROM listings WHERE id = NEW.listing_id;
    
    -- Format amount (price_cents is the column name)
    order_amount := '$' || ROUND((NEW.price_cents / 100.0)::numeric, 2)::TEXT;
    
    -- Send notification with error handling
    BEGIN
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
    EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail the insert
        RAISE WARNING 'Failed to send order notification for order %: %', NEW.id, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_order_placed ON orders;
CREATE TRIGGER on_order_placed
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_placed();

-- ============================================================================
-- STEP 3: ADD PAYOUT SETUP COMPLETION NOTIFICATION TRIGGER
-- ============================================================================
-- Notifies user when they complete payout setup (stripe_payouts_enabled changes to true)

CREATE OR REPLACE FUNCTION notify_payout_setup_complete()
RETURNS TRIGGER AS $$
DECLARE
    pending_amount_cents BIGINT;
    pending_amount_text TEXT;
BEGIN
    -- Only trigger when payout setup is completed (changed from false to true)
    IF OLD.stripe_payouts_enabled = NEW.stripe_payouts_enabled THEN
        RETURN NEW;
    END IF;
    
    -- Only notify when becoming enabled (not when disabling)
    IF NOT NEW.stripe_payouts_enabled THEN
        RETURN NEW;
    END IF;
    
    -- Check if user has pending funds waiting
    SELECT COALESCE(SUM(amount_cents), 0) INTO pending_amount_cents
    FROM pending_seller_payouts
    WHERE seller_id = NEW.id AND status = 'pending';
    
    -- Format pending amount
    IF pending_amount_cents > 0 THEN
        pending_amount_text := '$' || ROUND((pending_amount_cents / 100.0)::numeric, 2)::TEXT;
    ELSE
        pending_amount_text := NULL;
    END IF;
    
    -- Send notification with error handling
    BEGIN
        IF pending_amount_text IS NOT NULL THEN
            -- User has pending funds
            PERFORM send_onesignal_notification(
                NEW.id,
                'Payout Setup Complete! 🎉',
                'Your payout account is ready! You have ' || pending_amount_text || ' waiting to be transferred.',
                jsonb_build_object(
                    'type', 'payout_setup_complete',
                    'pending_amount_cents', pending_amount_cents,
                    'screen', 'Wallet'
                )
            );
        ELSE
            -- No pending funds, just confirm setup
            PERFORM send_onesignal_notification(
                NEW.id,
                'Payout Setup Complete! 🎉',
                'Your payout account is ready! You can now receive payments from sales.',
                jsonb_build_object(
                    'type', 'payout_setup_complete',
                    'screen', 'Wallet'
                )
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail the update
        RAISE WARNING 'Failed to send payout setup notification for user %: %', NEW.id, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS on_payout_setup_complete ON users;
CREATE TRIGGER on_payout_setup_complete
    AFTER UPDATE OF stripe_payouts_enabled ON users
    FOR EACH ROW
    WHEN (OLD.stripe_payouts_enabled IS DISTINCT FROM NEW.stripe_payouts_enabled)
    EXECUTE FUNCTION notify_payout_setup_complete();

-- ============================================================================
-- STEP 4: VERIFICATION QUERIES
-- ============================================================================

-- Check all notification triggers
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
    'on_payout_setup_complete',
    'on_new_rating'
)
ORDER BY tgrelid::regclass::text;

-- Check recent orders and see if notifications were sent
SELECT 
    o.id AS order_id,
    o.buyer_id,
    o.seller_id,
    o.price_cents,
    o.created_at AS order_created_at,
    l.title AS listing_title,
    buyer.name AS buyer_name,
    seller.name AS seller_name,
    n.id AS notification_id,
    n.type AS notification_type,
    n.created_at AS notification_created_at
FROM orders o
LEFT JOIN listings l ON l.id = o.listing_id
LEFT JOIN users buyer ON buyer.id = o.buyer_id
LEFT JOIN users seller ON seller.id = o.seller_id
LEFT JOIN notifications n ON n.order_id = o.id AND n.type = 'order_placed'
ORDER BY o.created_at DESC
LIMIT 20;

-- Check users who recently completed payout setup
SELECT 
    u.id,
    u.name,
    u.email,
    u.stripe_payouts_enabled,
    u.stripe_details_submitted,
    u.created_at,
    COALESCE(SUM(p.amount_cents), 0) AS pending_amount_cents
FROM users u
LEFT JOIN pending_seller_payouts p ON p.seller_id = u.id AND p.status = 'pending'
WHERE u.stripe_payouts_enabled = true
GROUP BY u.id, u.name, u.email, u.stripe_payouts_enabled, u.stripe_details_submitted, u.created_at
ORDER BY u.created_at DESC
LIMIT 10;

-- ============================================================================
-- DONE!
-- ============================================================================
-- Fixed notifications:
-- ✅ Order placed notifications (with error handling)
-- ✅ Payout setup completion notifications (new)
-- ============================================================================
