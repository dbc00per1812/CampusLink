-- Enable order notifications for all users

-- 1. Create notification preferences for users who don't have them
INSERT INTO public.user_notification_preferences (
    user_id,
    push_enabled,
    order_notifications,
    message_notifications,
    payment_notifications,
    rating_notifications,
    marketplace_notifications
)
SELECT 
    u.id,
    true,  -- push_enabled
    true,  -- order_notifications
    true,  -- message_notifications
    true,  -- payment_notifications
    true,  -- rating_notifications
    true   -- marketplace_notifications
FROM auth.users u
LEFT JOIN public.user_notification_preferences unp ON u.id = unp.user_id
WHERE unp.user_id IS NULL;

-- 2. Enable order notifications for existing users who have them disabled
UPDATE public.user_notification_preferences 
SET 
    push_enabled = true,
    order_notifications = true
WHERE order_notifications = false OR push_enabled = false;

-- 3. Test creating an order notification for the most recent order
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
        -- Create a test notification
        SELECT create_notification(
            recent_order.seller_id,
            'order_placed',
            'New Order!',
            'You have a new order (test notification)',
            jsonb_build_object('order_id', recent_order.id::text),
            recent_order.id,
            NULL,
            recent_order.listing_id,
            recent_order.buyer_id
        ) INTO notification_id;
        
        RAISE NOTICE 'Created test notification: %', notification_id;
    END IF;
END $$;

-- 4. Check if the test notification was created
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
  AND body LIKE '%test notification%'
ORDER BY created_at DESC 
LIMIT 1;

-- 5. Process any pending notifications
SELECT * FROM process_and_send_notifications();
