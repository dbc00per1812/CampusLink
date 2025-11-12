-- Fix offer notification trigger to use correct conversation field names
-- The conversations table uses buyer_id/seller_id, not participant1_id/participant2_id

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
    v_buyer_id UUID;
    v_seller_id UUID;
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
    
    -- Determine buyer_id and seller_id based on listing type
    IF NEW.listing_type = 'seek' THEN
        -- For seek listings: offer_to_user_id is the seeker (buyer), offer_from_user_id is seller
        v_buyer_id := NEW.offer_to_user_id;
        v_seller_id := NEW.offer_from_user_id;
    ELSE
        -- For regular listings: offer_from_user_id is buyer, offer_to_user_id is seller
        v_buyer_id := NEW.offer_from_user_id;
        v_seller_id := NEW.offer_to_user_id;
    END IF;
    
    -- Find or create conversation between the two users
    -- Conversations use buyer_id and seller_id, not participant fields
    SELECT id INTO v_conversation_id
    FROM conversations
    WHERE (buyer_id = v_buyer_id AND seller_id = v_seller_id)
       OR (buyer_id = v_seller_id AND seller_id = v_buyer_id)
    LIMIT 1;
    
    -- Create conversation if it doesn't exist
    IF v_conversation_id IS NULL THEN
        INSERT INTO conversations (buyer_id, seller_id, listing_id, created_at, last_message_at)
        VALUES (v_buyer_id, v_seller_id, NEW.listing_id, NOW(), NOW())
        RETURNING id INTO v_conversation_id;
    ELSE
        -- Update last_message_at
        UPDATE conversations 
        SET last_message_at = NOW()
        WHERE id = v_conversation_id;
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

-- Recreate trigger
DROP TRIGGER IF EXISTS offer_activity_trigger ON offers;

CREATE TRIGGER offer_activity_trigger
AFTER INSERT OR UPDATE ON offers
FOR EACH ROW
EXECUTE FUNCTION notify_offer_activity();

