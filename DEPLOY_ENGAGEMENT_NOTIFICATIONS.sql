-- ============================================
-- DEPLOY ENGAGEMENT NOTIFICATION SYSTEM
-- ============================================
-- This script creates 5 recurring engagement notifications
-- to increase daily active users and transaction completion
-- Following the proven pattern from DEPLOY_ALL_NOTIFICATIONS.sql
-- ============================================

-- ============================================
-- STEP 1: Update notification types CHECK constraint
-- ============================================

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
CHECK (type = ANY (ARRAY[
    -- Existing types (keep all)
    'order_placed'::text, 'order_confirmed'::text, 'order_in_progress'::text, 
    'order_completed'::text, 'order_cancelled'::text, 'payment_succeeded'::text, 
    'payment_failed'::text, 'new_message'::text, 'rating_received'::text, 
    'rating_reminder'::text, 'payout_completed'::text, 'listing_interest'::text, 
    'marketplace_activity'::text,
    -- New engagement types
    'idle_listing_reminder'::text, 'message_reminder'::text, 'first_sale_milestone'::text
]));

-- ============================================
-- STEP 2: REAL-TIME TRIGGER - First Sale Milestone
-- ============================================

CREATE OR REPLACE FUNCTION notify_first_sale_milestone()
RETURNS TRIGGER AS $$
DECLARE
    v_seller_completed_orders INTEGER;
    v_listing_title TEXT;
    v_amount_dollars TEXT;
BEGIN
    -- Only trigger when order status changes to 'completed'
    IF NEW.order_status = 'completed' AND (OLD.order_status IS NULL OR OLD.order_status != 'completed') THEN
        
        -- Count how many completed orders this seller has
        SELECT COUNT(*) INTO v_seller_completed_orders
        FROM orders
        WHERE seller_id = NEW.seller_id
        AND order_status = 'completed';
        
        -- If this is their FIRST completed sale
        IF v_seller_completed_orders = 1 THEN
            
            -- Get listing title
            SELECT title INTO v_listing_title
            FROM listings
            WHERE id = NEW.listing_id;
            
            -- Format amount as dollars
            v_amount_dollars := '$' || ROUND(NEW.price_cents / 100.0, 2)::TEXT;
            
            -- Create milestone notification
            INSERT INTO notifications (
                user_id,
                type,
                title,
                body,
                data,
                order_id,
                listing_id,
                created_at
            ) VALUES (
                NEW.seller_id,
                'first_sale_milestone',
                '🎉 First Sale Complete!',
                'Congratulations on your first sale! You earned ' || v_amount_dollars || ' from "' || COALESCE(v_listing_title, 'your item') || '"',
                jsonb_build_object(
                    'order_id', NEW.id::text,
                    'amount_cents', NEW.price_cents,
                    'milestone', 'first_sale'
                ),
                NEW.id,
                NEW.listing_id,
                NOW()
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 3: REAL-TIME TRIGGER - Payout Success
-- ============================================

CREATE OR REPLACE FUNCTION notify_payout_success()
RETURNS TRIGGER AS $$
DECLARE
    v_amount_dollars TEXT;
    v_payout_method TEXT;
BEGIN
    -- Only trigger when status changes to indicate successful payout
    -- Common success statuses: 'paid', 'completed', 'in_transit'
    IF (NEW.status IN ('paid', 'completed', 'in_transit') OR NEW.paid_at IS NOT NULL)
       AND (OLD.status IS NULL OR OLD.status NOT IN ('paid', 'completed', 'in_transit'))
       AND (OLD.paid_at IS NULL AND NEW.paid_at IS NOT NULL OR OLD.paid_at IS NULL) THEN
        
        -- Format amount as dollars
        v_amount_dollars := '$' || ROUND(NEW.amount_cents / 100.0, 2)::TEXT;
        
        -- Get payout method
        v_payout_method := CASE 
            WHEN NEW.payout_type = 'instant' THEN 'Instant Payout'
            ELSE 'Standard Payout'
        END;
        
        -- Create payout success notification
        INSERT INTO notifications (
            user_id,
            type,
            title,
            body,
            data,
            created_at
        ) VALUES (
            NEW.seller_id,
            'payout_completed',
            '💰 Payout On The Way!',
            'Your ' || v_amount_dollars || ' payout is on the way! (' || v_payout_method || ')',
            jsonb_build_object(
                'payout_id', NEW.id::text,
                'amount_cents', NEW.amount_cents,
                'payout_type', NEW.payout_type,
                'payout_method', NEW.payout_method
            ),
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 4: SCHEDULED FUNCTION - Idle Listing Reminders
-- ============================================

CREATE OR REPLACE FUNCTION send_idle_listing_reminders()
RETURNS void AS $$
DECLARE
    v_listing RECORD;
    v_last_reminder_sent TIMESTAMP;
BEGIN
    -- Find active listings with no orders in past 7 days
    -- that haven't received a reminder in the past 7 days
    FOR v_listing IN
        SELECT 
            l.id,
            l.user_id,
            l.title,
            l.created_at,
            COALESCE(MAX(o.created_at), l.created_at) as last_activity
        FROM listings l
        LEFT JOIN orders o ON o.listing_id = l.id
        WHERE l.is_sold = false
        AND l.archived = false
        AND l.status = 'active'
        AND l.created_at < NOW() - INTERVAL '7 days'
        GROUP BY l.id, l.user_id, l.title, l.created_at
        HAVING COALESCE(MAX(o.created_at), l.created_at) < NOW() - INTERVAL '7 days'
    LOOP
        -- Check if we've sent a reminder in the past 7 days
        SELECT MAX(created_at) INTO v_last_reminder_sent
        FROM notifications
        WHERE user_id = v_listing.user_id
        AND listing_id = v_listing.id
        AND type = 'idle_listing_reminder';
        
        -- Only send if no reminder sent in past 7 days
        IF v_last_reminder_sent IS NULL OR v_last_reminder_sent < NOW() - INTERVAL '7 days' THEN
            INSERT INTO notifications (
                user_id,
                type,
                title,
                body,
                data,
                listing_id,
                created_at
            ) VALUES (
                v_listing.user_id,
                'idle_listing_reminder',
                'Boost Your Listing',
                'Your listing "' || v_listing.title || '" has been quiet. Add photos or update it to boost visibility!',
                jsonb_build_object(
                    'listing_id', v_listing.id::text,
                    'days_since_activity', EXTRACT(DAY FROM NOW() - v_listing.last_activity)
                ),
                v_listing.id,
                NOW()
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: SCHEDULED FUNCTION - Rating Reminders
-- ============================================

CREATE OR REPLACE FUNCTION send_rating_reminders()
RETURNS void AS $$
DECLARE
    v_order RECORD;
    v_existing_buyer_rating UUID;
    v_existing_seller_rating UUID;
    v_last_buyer_reminder TIMESTAMP;
    v_last_seller_reminder TIMESTAMP;
    v_days_since_completion INTEGER;
    v_reminder_intervals INTEGER[] := ARRAY[1, 3, 7]; -- Days after completion
    v_buyer_name TEXT;
    v_seller_name TEXT;
BEGIN
    -- Find completed orders without ratings
    FOR v_order IN
        SELECT 
            o.id,
            o.buyer_id,
            o.seller_id,
            o.completed_at,
            EXTRACT(DAY FROM NOW() - o.completed_at)::INTEGER as days_completed
        FROM orders o
        WHERE o.order_status = 'completed'
        AND o.completed_at IS NOT NULL
        AND o.completed_at < NOW() - INTERVAL '1 day' -- At least 1 day old
        AND o.completed_at > NOW() - INTERVAL '14 days' -- Not too old
    LOOP
        v_days_since_completion := v_order.days_completed;
        
        -- Get user names for personalized messages
        SELECT name INTO v_buyer_name FROM users WHERE id = v_order.buyer_id;
        SELECT name INTO v_seller_name FROM users WHERE id = v_order.seller_id;
        
        -- Check if buyer has rated seller
        SELECT id INTO v_existing_buyer_rating
        FROM ratings
        WHERE order_id = v_order.id
        AND rater_id = v_order.buyer_id
        AND rating_type = 'buyer_to_seller';
        
        -- If buyer hasn't rated, send reminder at appropriate intervals
        IF v_existing_buyer_rating IS NULL THEN
            SELECT MAX(created_at) INTO v_last_buyer_reminder
            FROM notifications
            WHERE user_id = v_order.buyer_id
            AND order_id = v_order.id
            AND type = 'rating_reminder';
            
            -- Send if we're at a reminder interval and haven't sent in past 2 days
            IF v_days_since_completion = ANY(v_reminder_intervals)
               AND (v_last_buyer_reminder IS NULL OR v_last_buyer_reminder < NOW() - INTERVAL '2 days') THEN
                INSERT INTO notifications (
                    user_id,
                    type,
                    title,
                    body,
                    data,
                    order_id,
                    related_user_id,
                    created_at
                ) VALUES (
                    v_order.buyer_id,
                    'rating_reminder',
                    'Rate Your Experience',
                    'How was your experience with ' || COALESCE(v_seller_name, 'the seller') || '? Leave a rating to build trust.',
                    jsonb_build_object(
                        'order_id', v_order.id::text,
                        'rating_type', 'buyer_to_seller',
                        'days_since_completion', v_days_since_completion
                    ),
                    v_order.id,
                    v_order.seller_id,
                    NOW()
                );
            END IF;
        END IF;
        
        -- Check if seller has rated buyer
        SELECT id INTO v_existing_seller_rating
        FROM ratings
        WHERE order_id = v_order.id
        AND rater_id = v_order.seller_id
        AND rating_type = 'seller_to_buyer';
        
        -- If seller hasn't rated, send reminder at appropriate intervals
        IF v_existing_seller_rating IS NULL THEN
            SELECT MAX(created_at) INTO v_last_seller_reminder
            FROM notifications
            WHERE user_id = v_order.seller_id
            AND order_id = v_order.id
            AND type = 'rating_reminder';
            
            -- Send if we're at a reminder interval and haven't sent in past 2 days
            IF v_days_since_completion = ANY(v_reminder_intervals)
               AND (v_last_seller_reminder IS NULL OR v_last_seller_reminder < NOW() - INTERVAL '2 days') THEN
                INSERT INTO notifications (
                    user_id,
                    type,
                    title,
                    body,
                    data,
                    order_id,
                    related_user_id,
                    created_at
                ) VALUES (
                    v_order.seller_id,
                    'rating_reminder',
                    'Rate Your Experience',
                    'How was your experience with ' || COALESCE(v_buyer_name, 'the buyer') || '? Leave a rating to build trust.',
                    jsonb_build_object(
                        'order_id', v_order.id::text,
                        'rating_type', 'seller_to_buyer',
                        'days_since_completion', v_days_since_completion
                    ),
                    v_order.id,
                    v_order.buyer_id,
                    NOW()
                );
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 6: SCHEDULED FUNCTION - Message Reminders
-- ============================================

CREATE OR REPLACE FUNCTION send_message_reminders()
RETURNS void AS $$
DECLARE
    v_message RECORD;
    v_recipient_id UUID;
    v_sender_name TEXT;
    v_listing_title TEXT;
    v_reminder_count INTEGER;
    v_last_reminder TIMESTAMP;
BEGIN
    -- Find unread messages older than 24 hours
    FOR v_message IN
        SELECT 
            m.id,
            m.sender_id,
            m.conversation_id,
            m.created_at,
            c.buyer_id,
            c.seller_id,
            c.listing_id
        FROM messages m
        JOIN conversations c ON c.id = m.conversation_id
        WHERE m.read_at IS NULL
        AND m.created_at < NOW() - INTERVAL '24 hours'
        AND m.created_at > NOW() - INTERVAL '14 days' -- Don't remind on very old messages
    LOOP
        -- Determine recipient (person who didn't send the message)
        v_recipient_id := CASE 
            WHEN v_message.sender_id = v_message.buyer_id THEN v_message.seller_id
            ELSE v_message.buyer_id
        END;
        
        -- Count how many reminders we've sent for this message
        SELECT COUNT(*) INTO v_reminder_count
        FROM notifications
        WHERE user_id = v_recipient_id
        AND message_id = v_message.id
        AND type = 'message_reminder';
        
        -- Max 3 reminders per message
        IF v_reminder_count < 3 THEN
            -- Check when we last sent a reminder
            SELECT MAX(created_at) INTO v_last_reminder
            FROM notifications
            WHERE user_id = v_recipient_id
            AND message_id = v_message.id
            AND type = 'message_reminder';
            
            -- Send reminder if:
            -- - First reminder: 24h after message
            -- - Subsequent: Every 3 days
            IF (v_reminder_count = 0 AND v_message.created_at < NOW() - INTERVAL '24 hours')
               OR (v_reminder_count > 0 AND v_last_reminder < NOW() - INTERVAL '3 days') THEN
                
                -- Get sender name and listing title
                SELECT name INTO v_sender_name FROM users WHERE id = v_message.sender_id;
                SELECT title INTO v_listing_title FROM listings WHERE id = v_message.listing_id;
                
                INSERT INTO notifications (
                    user_id,
                    type,
                    title,
                    body,
                    data,
                    message_id,
                    related_user_id,
                    listing_id,
                    created_at
                ) VALUES (
                    v_recipient_id,
                    'message_reminder',
                    'Unanswered Message',
                    'You have an unanswered message from ' || COALESCE(v_sender_name, 'someone') || 
                    CASE WHEN v_listing_title IS NOT NULL THEN ' about "' || v_listing_title || '"' ELSE '' END,
                    jsonb_build_object(
                        'message_id', v_message.id::text,
                        'conversation_id', v_message.conversation_id::text,
                        'reminder_count', v_reminder_count + 1
                    ),
                    v_message.id,
                    v_message.sender_id,
                    v_message.listing_id,
                    NOW()
                );
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 7: SCHEDULED FUNCTION - Campus Activity Digest
-- ============================================

CREATE OR REPLACE FUNCTION send_campus_activity_digest()
RETURNS void AS $$
DECLARE
    v_campus_record RECORD;
    v_new_listings_count INTEGER;
    v_user RECORD;
    v_last_digest TIMESTAMP;
BEGIN
    -- For each campus
    FOR v_campus_record IN
        SELECT DISTINCT campus
        FROM users
        WHERE campus IS NOT NULL
    LOOP
        -- Count new listings in past 24 hours for this campus
        SELECT COUNT(*) INTO v_new_listings_count
        FROM listings l
        JOIN users u ON u.id = l.user_id
        WHERE u.campus = v_campus_record.campus
        AND l.created_at > NOW() - INTERVAL '24 hours'
        AND l.status = 'active'
        AND l.archived = false;
        
        -- Only send if there are at least 3 new listings
        IF v_new_listings_count >= 3 THEN
            -- Send to all users on this campus who have marketplace notifications enabled
            FOR v_user IN
                SELECT u.id
                FROM users u
                LEFT JOIN user_notification_preferences unp ON unp.user_id = u.id
                WHERE u.campus = v_campus_record.campus
                AND (unp.marketplace_notifications = true OR unp.marketplace_notifications IS NULL)
            LOOP
                -- Check if we sent a digest in past 20 hours (prevent duplicates)
                SELECT MAX(created_at) INTO v_last_digest
                FROM notifications
                WHERE user_id = v_user.id
                AND type = 'marketplace_activity'
                AND body LIKE '%new items posted on your campus%';
                
                IF v_last_digest IS NULL OR v_last_digest < NOW() - INTERVAL '20 hours' THEN
                    INSERT INTO notifications (
                        user_id,
                        type,
                        title,
                        body,
                        data,
                        created_at
                    ) VALUES (
                        v_user.id,
                        'marketplace_activity',
                        'Campus Marketplace Update',
                        '🔥 ' || v_new_listings_count || ' new items posted on your campus today! Check out what''s new.',
                        jsonb_build_object(
                            'campus', v_campus_record.campus,
                            'new_listings_count', v_new_listings_count,
                            'period_hours', 24
                        ),
                        NOW()
                    );
                END IF;
            END LOOP;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 8: CREATE REAL-TIME TRIGGERS
-- ============================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS first_sale_milestone_trigger ON orders;
DROP TRIGGER IF EXISTS payout_success_trigger ON payouts;

-- First sale milestone trigger
CREATE TRIGGER first_sale_milestone_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (NEW.order_status = 'completed')
    EXECUTE FUNCTION notify_first_sale_milestone();

-- Payout success trigger
CREATE TRIGGER payout_success_trigger
    AFTER UPDATE ON payouts
    FOR EACH ROW
    EXECUTE FUNCTION notify_payout_success();

-- ============================================
-- STEP 9: SCHEDULE CRON JOBS
-- ============================================

-- Note: pg_cron extension must be enabled first
-- You may have already done this for push notifications

-- Unschedule existing jobs if they exist (to avoid duplicates)
SELECT cron.unschedule('send-idle-listing-reminders') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'send-idle-listing-reminders'
);
SELECT cron.unschedule('send-rating-reminders') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'send-rating-reminders'
);
SELECT cron.unschedule('send-message-reminders') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'send-message-reminders'
);
SELECT cron.unschedule('send-campus-activity-digest') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'send-campus-activity-digest'
);

-- Schedule idle listing reminders (every 6 hours)
SELECT cron.schedule(
    'send-idle-listing-reminders',
    '0 */6 * * *',  -- Every 6 hours at minute 0
    'SELECT send_idle_listing_reminders();'
);

-- Schedule rating reminders (daily at 10am UTC)
SELECT cron.schedule(
    'send-rating-reminders',
    '0 10 * * *',  -- Daily at 10:00 UTC
    'SELECT send_rating_reminders();'
);

-- Schedule message reminders (every 6 hours)
SELECT cron.schedule(
    'send-message-reminders',
    '0 */6 * * *',  -- Every 6 hours at minute 0
    'SELECT send_message_reminders();'
);

-- Schedule campus activity digest (daily at 6pm UTC / 1pm EST / 11am PST)
SELECT cron.schedule(
    'send-campus-activity-digest',
    '0 18 * * *',  -- Daily at 18:00 UTC (6pm)
    'SELECT send_campus_activity_digest();'
);

-- ============================================
-- STEP 10: GRANT PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION notify_first_sale_milestone() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_payout_success() TO authenticated;
GRANT EXECUTE ON FUNCTION send_idle_listing_reminders() TO authenticated;
GRANT EXECUTE ON FUNCTION send_rating_reminders() TO authenticated;
GRANT EXECUTE ON FUNCTION send_message_reminders() TO authenticated;
GRANT EXECUTE ON FUNCTION send_campus_activity_digest() TO authenticated;

-- ============================================
-- STEP 11: VERIFICATION QUERIES
-- ============================================

-- Check all new triggers are created
SELECT 
    trigger_name,
    event_object_table as table_name,
    action_timing,
    event_manipulation as event
FROM information_schema.triggers
WHERE trigger_name IN ('first_sale_milestone_trigger', 'payout_success_trigger')
AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Check all new functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'notify_first_sale_milestone',
    'notify_payout_success',
    'send_idle_listing_reminders',
    'send_rating_reminders',
    'send_message_reminders',
    'send_campus_activity_digest'
)
ORDER BY routine_name;

-- Check scheduled cron jobs
SELECT 
    jobid,
    jobname,
    schedule,
    active,
    command
FROM cron.job
WHERE jobname IN (
    'send-idle-listing-reminders',
    'send-rating-reminders',
    'send-message-reminders',
    'send-campus-activity-digest'
)
ORDER BY jobname;

-- Expected results:
-- - 2 new triggers (first_sale_milestone, payout_success)
-- - 6 new functions (2 trigger functions + 4 scheduled functions)
-- - 4 cron jobs (all active)

-- ============================================
-- DEPLOYMENT COMPLETE!
-- ============================================
-- Engagement notifications are now live:
-- ✅ First sale milestone (real-time)
-- ✅ Payout success (real-time)
-- ✅ Idle listing reminders (every 6 hours)
-- ✅ Rating reminders (daily at 10am UTC)
-- ✅ Message reminders (every 6 hours)
-- ✅ Campus activity digest (daily at 6pm UTC)
-- ============================================

