-- Fix order notifications - ensure they're being created and delivered

-- 1. Check if create_notification function exists, if not create a simple version
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::jsonb,
    p_order_id UUID DEFAULT NULL,
    p_message_id UUID DEFAULT NULL,
    p_listing_id UUID DEFAULT NULL,
    p_related_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id,
        type,
        title,
        body,
        data,
        order_id,
        message_id,
        listing_id,
        related_user_id,
        is_delivered,
        created_at
    ) VALUES (
        p_user_id,
        p_type,
        p_title,
        p_body,
        p_data,
        p_order_id,
        p_message_id,
        p_listing_id,
        p_related_user_id,
        false,  -- Will be processed by our notification system
        NOW()
    )
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- 2. Make sure the order notification trigger is properly set up
-- (We already fixed this in fix_notification_trigger.sql, but let's verify)

-- 3. Test creating an order notification manually
SELECT create_notification(
    (SELECT seller_id FROM public.orders ORDER BY created_at DESC LIMIT 1),  -- Send to seller
    'order_placed',
    'New Order!',
    'You have a new order',
    jsonb_build_object('order_id', (SELECT id FROM public.orders ORDER BY created_at DESC LIMIT 1)::text),
    (SELECT id FROM public.orders ORDER BY created_at DESC LIMIT 1),  -- order_id
    NULL,  -- message_id
    (SELECT listing_id FROM public.orders ORDER BY created_at DESC LIMIT 1),  -- listing_id
    (SELECT buyer_id FROM public.orders ORDER BY created_at DESC LIMIT 1)   -- related_user_id (buyer)
) as test_notification_id;

-- 4. Process the test notification
SELECT * FROM process_and_send_notifications();

-- 5. Check if the test notification was created and processed
SELECT 
    id,
    user_id,
    type,
    title,
    body,
    is_delivered,
    delivered_at,
    created_at
FROM public.notifications 
WHERE type = 'order_placed'
ORDER BY created_at DESC 
LIMIT 3;
