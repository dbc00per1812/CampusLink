-- Create Offer Notifications
-- This file sets up automatic notifications for offer-related events

-- Function to create notification when offer is made on a seek post
CREATE OR REPLACE FUNCTION create_offer_made_notification()
RETURNS TRIGGER AS $$
DECLARE
  seek_title text;
BEGIN
  -- Only trigger on new offers with 'pending' status
  IF NEW.status = 'pending' THEN
    -- Get the seek listing title for the notification
    SELECT title INTO seek_title
    FROM listings
    WHERE id = NEW.seek_listing_id;
    
    -- Create notification for seeker (person who posted the seek)
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      listing_id,
      related_user_id,
      is_read,
      is_delivered
    ) VALUES (
      NEW.seeker_id,
      'listing_interest',
      'New Offer on Your Seek!',
      COALESCE('Someone made an offer on "' || seek_title || '"', 'You have a new offer'),
      jsonb_build_object(
        'offer_id', NEW.id,
        'seller_id', NEW.seller_id,
        'price_cents', NEW.price_cents,
        'seek_listing_id', NEW.seek_listing_id,
        'offer_listing_id', NEW.offer_listing_id
      ),
      NEW.seek_listing_id,
      NEW.seller_id,
      false,
      false
    );
    
    -- Check if seeker has push notifications enabled and send push
    IF EXISTS (
      SELECT 1 FROM user_notification_preferences 
      WHERE user_id = NEW.seeker_id 
      AND push_enabled = true 
      AND marketplace_notifications = true
    ) THEN
      -- Queue push notification for processing
      INSERT INTO push_notification_queue (
        user_id,
        notification_type,
        title,
        body,
        data
      ) VALUES (
        NEW.seeker_id,
        'listing_interest',
        'New Offer on Your Seek!',
        COALESCE('Someone made an offer on "' || seek_title || '"', 'You have a new offer'),
        jsonb_build_object(
          'offer_id', NEW.id,
          'type', 'new_offer',
          'seek_listing_id', NEW.seek_listing_id
        )
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create notification when offer status changes
CREATE OR REPLACE FUNCTION create_offer_status_notification()
RETURNS TRIGGER AS $$
DECLARE
  notification_title text;
  notification_body text;
  notification_type text;
BEGIN
  -- Only trigger when status actually changes
  IF OLD.status != NEW.status THEN
    -- Determine notification content based on status change
    CASE NEW.status
      WHEN 'accepted' THEN
        notification_title := 'Offer Accepted!';
        notification_body := 'Your offer has been accepted';
        notification_type := 'marketplace_activity';
      WHEN 'declined' THEN
        notification_title := 'Offer Declined';
        notification_body := 'Your offer has been declined';
        notification_type := 'marketplace_activity';
      WHEN 'withdrawn' THEN
        -- Skip notification for withdrawn offers (user did it themselves)
        RETURN NEW;
      ELSE
        -- Skip notification for other statuses
        RETURN NEW;
    END CASE;
    
    -- Create notification for the offer maker (seller)
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      listing_id,
      related_user_id,
      is_read,
      is_delivered
    ) VALUES (
      NEW.seller_id,
      notification_type,
      notification_title,
      notification_body,
      jsonb_build_object(
        'offer_id', NEW.id,
        'seeker_id', NEW.seeker_id,
        'status', NEW.status,
        'seek_listing_id', NEW.seek_listing_id
      ),
      NEW.seek_listing_id,
      NEW.seeker_id,
      false,
      false
    );
    
    -- Check if seller has push notifications enabled and send push
    IF EXISTS (
      SELECT 1 FROM user_notification_preferences 
      WHERE user_id = NEW.seller_id 
      AND push_enabled = true 
      AND marketplace_notifications = true
    ) THEN
      -- Queue push notification for processing
      INSERT INTO push_notification_queue (
        user_id,
        notification_type,
        title,
        body,
        data
      ) VALUES (
        NEW.seller_id,
        notification_type,
        notification_title,
        notification_body,
        jsonb_build_object(
          'offer_id', NEW.id,
          'type', 'offer_' || NEW.status,
          'seek_listing_id', NEW.seek_listing_id
        )
      );
    END IF;
    
    -- Special handling for accepted offers - also notify seeker about the acceptance
    IF NEW.status = 'accepted' THEN
      INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        listing_id,
        related_user_id,
        is_read,
        is_delivered
      ) VALUES (
        NEW.seeker_id,
        'marketplace_activity',
        'Offer Accepted Successfully',
        'You have accepted an offer. Proceed with payment to complete the transaction.',
        jsonb_build_object(
          'offer_id', NEW.id,
          'seller_id', NEW.seller_id,
          'status', NEW.status,
          'price_cents', NEW.price_cents
        ),
        NEW.seek_listing_id,
        NEW.seller_id,
        false,
        false
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for offer notifications
DROP TRIGGER IF EXISTS trigger_offer_made_notification ON offers;
CREATE TRIGGER trigger_offer_made_notification
  AFTER INSERT ON offers
  FOR EACH ROW
  EXECUTE FUNCTION create_offer_made_notification();

DROP TRIGGER IF EXISTS trigger_offer_status_notification ON offers;
CREATE TRIGGER trigger_offer_status_notification
  AFTER UPDATE ON offers
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION create_offer_status_notification();

-- Function to create notification when someone expresses interest in a listing
CREATE OR REPLACE FUNCTION create_listing_interest_notification(
  p_listing_id uuid,
  p_interested_user_id uuid,
  p_message text DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  listing_owner_id uuid;
  listing_title text;
BEGIN
  -- Get listing owner and title
  SELECT user_id, title INTO listing_owner_id, listing_title
  FROM listings
  WHERE id = p_listing_id;
  
  -- Don't notify if user is interested in their own listing
  IF listing_owner_id = p_interested_user_id THEN
    RETURN;
  END IF;
  
  -- Create notification for listing owner
  INSERT INTO notifications (
    user_id,
    type,
    title,
    body,
    data,
    listing_id,
    related_user_id,
    is_read,
    is_delivered
  ) VALUES (
    listing_owner_id,
    'listing_interest',
    'Someone is interested in your listing!',
    COALESCE('Interest shown in "' || listing_title || '"', 'Someone is interested in your item'),
    jsonb_build_object(
      'listing_id', p_listing_id,
      'interested_user_id', p_interested_user_id,
      'message', p_message
    ),
    p_listing_id,
    p_interested_user_id,
    false,
    false
  );
  
  -- Check if owner has push notifications enabled
  IF EXISTS (
    SELECT 1 FROM user_notification_preferences 
    WHERE user_id = listing_owner_id 
    AND push_enabled = true 
    AND marketplace_notifications = true
  ) THEN
    -- Queue push notification
    INSERT INTO push_notification_queue (
      user_id,
      notification_type,
      title,
      body,
      data
    ) VALUES (
      listing_owner_id,
      'listing_interest',
      'Someone is interested in your listing!',
      COALESCE('Interest shown in "' || listing_title || '"', 'Someone is interested in your item'),
      jsonb_build_object(
        'listing_id', p_listing_id,
        'type', 'listing_interest'
      )
    );
  END IF;
END;
$$ LANGUAGE plpgsql;
