-- Fix the create_notification function to use correct column names

CREATE OR REPLACE FUNCTION create_notification(
    p_user_id uuid, 
    p_type text, 
    p_title text, 
    p_body text, 
    p_data jsonb DEFAULT '{}'::jsonb, 
    p_order_id uuid DEFAULT NULL::uuid, 
    p_message_id uuid DEFAULT NULL::uuid, 
    p_listing_id uuid DEFAULT NULL::uuid, 
    p_related_user_id uuid DEFAULT NULL::uuid, 
    p_scheduled_for timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS uuid
LANGUAGE plpgsql
AS $function$
DECLARE
  notification_id uuid;
  user_prefs record;
BEGIN
  -- Get user notification preferences with correct column names
  SELECT * INTO user_prefs 
  FROM public.user_notification_preferences 
  WHERE user_id = p_user_id;
  
  -- Check if user has notifications enabled for this type
  -- Use correct column name: push_enabled instead of push_notifications_enabled
  IF user_prefs IS NULL OR NOT user_prefs.push_enabled THEN
    RAISE NOTICE 'User % has no prefs or push disabled', p_user_id;
    RETURN NULL;
  END IF;
  
  -- Check type-specific preferences with correct column names
  CASE p_type
    WHEN 'order_placed', 'order_confirmed', 'order_in_progress', 'order_completed', 'order_cancelled' THEN
      IF NOT user_prefs.order_notifications THEN 
        RAISE NOTICE 'User % has order notifications disabled', p_user_id;
        RETURN NULL; 
      END IF;
    WHEN 'new_message' THEN
      IF NOT user_prefs.message_notifications THEN 
        RAISE NOTICE 'User % has message notifications disabled', p_user_id;
        RETURN NULL; 
      END IF;
    WHEN 'payment_succeeded', 'payment_failed', 'payout_completed' THEN
      IF NOT user_prefs.payment_notifications THEN 
        RAISE NOTICE 'User % has payment notifications disabled', p_user_id;
        RETURN NULL; 
      END IF;
    WHEN 'rating_received', 'rating_reminder' THEN
      IF NOT user_prefs.rating_notifications THEN 
        RAISE NOTICE 'User % has rating notifications disabled', p_user_id;
        RETURN NULL; 
      END IF;
    WHEN 'listing_interest', 'marketplace_activity' THEN
      IF NOT user_prefs.marketplace_notifications THEN 
        RAISE NOTICE 'User % has marketplace notifications disabled', p_user_id;
        RETURN NULL; 
      END IF;
  END CASE;
  
  -- Set scheduled time if not provided
  IF p_scheduled_for IS NULL THEN
    p_scheduled_for := now();
  END IF;
  
  -- Insert notification
  INSERT INTO public.notifications (
    user_id, type, title, body, data, order_id, message_id, 
    listing_id, related_user_id, scheduled_for
  ) VALUES (
    p_user_id, p_type, p_title, p_body, p_data, p_order_id, p_message_id,
    p_listing_id, p_related_user_id, p_scheduled_for
  ) RETURNING id INTO notification_id;
  
  RAISE NOTICE 'Created notification % for user %', notification_id, p_user_id;
  RETURN notification_id;
END;
$function$;

-- Test creating a notification for the most recent order
DO $$
DECLARE
    recent_order RECORD;
    notification_id UUID;
BEGIN
    -- Get the most recent order
    SELECT id, seller_id, buyer_id, listing_id 
    INTO recent_order
    FROM public.orders 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF recent_order IS NOT NULL THEN
        RAISE NOTICE 'Testing notification for order % seller %', recent_order.id, recent_order.seller_id;
        
        -- Create a test notification
        SELECT create_notification(
            recent_order.seller_id,
            'order_placed',
            'New Order!',
            'You have a new order (manual test)',
            jsonb_build_object('order_id', recent_order.id::text),
            recent_order.id,
            NULL,
            recent_order.listing_id,
            recent_order.buyer_id
        ) INTO notification_id;
        
        RAISE NOTICE 'Test notification result: %', notification_id;
    END IF;
END $$;

-- Check if the test notification was created
SELECT 
    id,
    user_id,
    type,
    title,
    body,
    is_delivered,
    created_at
FROM public.notifications 
WHERE type = 'order_placed'
  AND body LIKE '%manual test%'
ORDER BY created_at DESC 
LIMIT 1;
