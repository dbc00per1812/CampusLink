-- ========================================
-- Offer Notification Triggers
-- ========================================
-- Creates triggers to send notifications when offers are created/updated

-- Function to notify about offer activity
CREATE OR REPLACE FUNCTION notify_offer_activity()
RETURNS TRIGGER AS $$
DECLARE
    v_listing_title TEXT;
    v_from_user_name TEXT;
    v_to_user_name TEXT;
    v_from_user_id UUID;
    v_to_user_id UUID;
    v_conversation_id UUID;
    v_message_content TEXT;
    v_notification_type TEXT;
    v_notification_title TEXT;
    v_notification_body TEXT;
BEGIN
    -- Get listing title
    SELECT title INTO v_listing_title
    FROM listings
    WHERE id = NEW.listing_id;
    
    -- Get user names
    SELECT name INTO v_from_user_name
    FROM users
    WHERE id = NEW.offer_from_user_id;
    
    SELECT name INTO v_to_user_name
    FROM users
    WHERE id = NEW.offer_to_user_id;
    
    v_from_user_id := NEW.offer_from_user_id;
    v_to_user_id := NEW.offer_to_user_id;
    
    -- Determine notification type and message based on operation
    IF TG_OP = 'INSERT' THEN
        IF NEW.parent_offer_id IS NULL THEN
            -- New offer created
            v_notification_type := 'offer_received';
            v_notification_title := 'New Offer Received';
            v_notification_body := COALESCE(v_from_user_name, 'Someone') || ' made an offer on "' || v_listing_title || '"';
            v_message_content := '💰 New Offer: $' || (NEW.price_cents::FLOAT / 100)::TEXT;
            
            IF NEW.message IS NOT NULL THEN
                v_message_content := v_message_content || E'\n\nMessage: ' || NEW.message;
            END IF;
        ELSE
            -- Counter-offer created
            v_notification_type := 'offer_countered';
            v_notification_title := 'Counter-Offer Received';
            v_notification_body := COALESCE(v_from_user_name, 'Someone') || ' sent you a counter-offer';
            v_message_content := '🔄 Counter-Offer: $' || (NEW.price_cents::FLOAT / 100)::TEXT;
            
            IF NEW.message IS NOT NULL THEN
                v_message_content := v_message_content || E'\n\nMessage: ' || NEW.message;
            END IF;
        END IF;
    ELSIF TG_OP = 'UPDATE' AND OLD.status <> NEW.status THEN
        -- Status changed
        IF NEW.status = 'accepted' THEN
            v_notification_type := 'offer_accepted';
            v_notification_title := 'Offer Accepted';
            v_notification_body := 'Your offer on "' || v_listing_title || '" was accepted!';
            v_message_content := '✅ Offer Accepted: $' || (NEW.price_cents::FLOAT / 100)::TEXT;
            -- Swap to/from for acceptance notification (goes back to offerer)
            v_to_user_id := NEW.offer_from_user_id;
            v_from_user_id := NEW.offer_to_user_id;
        ELSIF NEW.status = 'declined' THEN
            v_notification_type := 'offer_rejected';
            v_notification_title := 'Offer Declined';
            v_notification_body := 'Your offer on "' || v_listing_title || '" was declined';
            v_message_content := '❌ Offer Declined: $' || (NEW.price_cents::FLOAT / 100)::TEXT;
            -- Swap to/from for rejection notification (goes back to offerer)
            v_to_user_id := NEW.offer_from_user_id;
            v_from_user_id := NEW.offer_to_user_id;
        ELSE
            -- Other status changes, don't notify
            RETURN NEW;
        END IF;
    ELSE
        -- No notification needed
        RETURN NEW;
    END IF;
    
    -- Find or create conversation between the two users
    SELECT id INTO v_conversation_id
    FROM conversations
    WHERE (participant1_id = v_from_user_id AND participant2_id = v_to_user_id)
       OR (participant1_id = v_to_user_id AND participant2_id = v_from_user_id)
    LIMIT 1;
    
    -- Create conversation if it doesn't exist
    IF v_conversation_id IS NULL THEN
        INSERT INTO conversations (participant1_id, participant2_id, listing_id, created_at, updated_at)
        VALUES (v_from_user_id, v_to_user_id, NEW.listing_id, NOW(), NOW())
        RETURNING id INTO v_conversation_id;
    END IF;
    
    -- Insert message into conversation
    INSERT INTO messages (conversation_id, sender_id, content, message_type, created_at)
    VALUES (v_conversation_id, v_from_user_id, v_message_content, 'offer_notification', NOW());
    
    -- Queue push notification
    INSERT INTO push_notification_queue (user_id, notification_type, title, body, data, created_at)
    VALUES (
        v_to_user_id,
        v_notification_type,
        v_notification_title,
        v_notification_body,
        jsonb_build_object(
            'offer_id', NEW.id,
            'listing_id', NEW.listing_id,
            'listing_title', v_listing_title,
            'amount_cents', NEW.price_cents,
            'conversation_id', v_conversation_id
        ),
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS offer_activity_trigger ON offers;

-- Create trigger for offer activity
CREATE TRIGGER offer_activity_trigger
AFTER INSERT OR UPDATE ON offers
FOR EACH ROW
EXECUTE FUNCTION notify_offer_activity();

-- Verification query
SELECT 'Offer notification trigger created successfully' AS status;

