-- Add custom price support for offers on seeking posts
-- This migration allows users to make offers with custom amounts instead of selecting existing listings

BEGIN;

-- Step 1: Add price_cents column to offers table if it doesn't exist
ALTER TABLE public.offers 
ADD COLUMN IF NOT EXISTS price_cents integer;

-- Step 2: Make offer_listing_id nullable to support custom price offers
ALTER TABLE public.offers 
ALTER COLUMN offer_listing_id DROP NOT NULL;

-- Step 3: Add check constraint to ensure either offer_listing_id or price_cents is provided
ALTER TABLE public.offers 
DROP CONSTRAINT IF EXISTS offers_must_have_price_or_listing,
ADD CONSTRAINT offers_must_have_price_or_listing CHECK (
    (offer_listing_id IS NOT NULL) OR (price_cents IS NOT NULL AND price_cents > 0)
);

-- Step 4: Create RPC function to accept an offer and create an order
CREATE OR REPLACE FUNCTION accept_offer(
    p_offer_id uuid,
    p_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offer public.offers%ROWTYPE;
    v_seek_listing public.listings%ROWTYPE;
    v_offer_listing public.listings%ROWTYPE;
    v_order_id uuid;
    v_price_cents integer;
    v_listing_id uuid;
    v_conversation_id uuid;
BEGIN
    -- Validate user is authenticated
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
    END IF;
    
    -- Get the offer
    SELECT * INTO v_offer FROM public.offers 
    WHERE id = p_offer_id AND status = 'pending';
    
    IF v_offer IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Offer not found or not pending');
    END IF;
    
    -- Verify the user is the seeker (owner of the seek listing)
    IF v_offer.seeker_id != p_user_id::text THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the seeker can accept offers');
    END IF;
    
    -- Get the seek listing
    SELECT * INTO v_seek_listing FROM public.listings 
    WHERE id = v_offer.seek_listing_id;
    
    IF v_seek_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Seek listing not found');
    END IF;
    
    -- Determine price and listing ID based on offer type
    IF v_offer.offer_listing_id IS NOT NULL THEN
        -- Traditional offer with existing listing
        SELECT * INTO v_offer_listing FROM public.listings 
        WHERE id = v_offer.offer_listing_id;
        
        IF v_offer_listing IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Offer listing not found');
        END IF;
        
        v_price_cents := (v_offer_listing.price * 100)::integer;
        v_listing_id := v_offer.offer_listing_id;
    ELSE
        -- Custom price offer
        v_price_cents := v_offer.price_cents;
        v_listing_id := v_offer.seek_listing_id; -- Use seek listing as the reference
    END IF;
    
    -- Update offer status to accepted
    UPDATE public.offers 
    SET status = 'accepted', updated_at = now()
    WHERE id = p_offer_id;
    
    -- Decline all other pending offers for this seek listing
    UPDATE public.offers 
    SET status = 'declined', updated_at = now()
    WHERE seek_listing_id = v_offer.seek_listing_id 
    AND id != p_offer_id 
    AND status = 'pending';
    
    -- Archive the seek listing
    UPDATE public.listings 
    SET archived = true, updated_at = now()
    WHERE id = v_offer.seek_listing_id;
    
    -- Create the order
    INSERT INTO public.orders (
        listing_id,
        buyer_id,
        seller_id,
        price_cents,
        payment_method,
        payment_status,
        order_status,
        created_at,
        updated_at
    ) VALUES (
        v_listing_id,
        v_offer.seeker_id::uuid, -- Seeker becomes the buyer
        v_offer.seller_id::uuid, -- Seller from the offer
        v_price_cents,
        'wallet', -- Default to wallet, can be changed in payment flow
        'pending',
        'placed',
        now(),
        now()
    ) RETURNING id INTO v_order_id;
    
    -- Find or create conversation
    SELECT id INTO v_conversation_id
    FROM public.conversations
    WHERE listing_id = v_seek_listing.id
    AND buyer_id = v_offer.seeker_id
    AND seller_id = v_offer.seller_id
    LIMIT 1;
    
    IF v_conversation_id IS NULL THEN
        INSERT INTO public.conversations (listing_id, buyer_id, seller_id)
        VALUES (v_seek_listing.id, v_offer.seeker_id, v_offer.seller_id)
        RETURNING id INTO v_conversation_id;
    END IF;
    
    -- Send acceptance message
    INSERT INTO public.messages (
        conversation_id,
        sender_id,
        content,
        message_type,
        order_id
    ) VALUES (
        v_conversation_id,
        p_user_id,
        format('✅ Offer accepted! Order #%s created for $%.2f. Please proceed with payment.', 
            substring(v_order_id::text from 1 for 8), 
            v_price_cents::numeric / 100
        ),
        'system',
        v_order_id
    );
    
    RETURN jsonb_build_object(
        'success', true, 
        'order_id', v_order_id,
        'conversation_id', v_conversation_id,
        'price_cents', v_price_cents
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Step 5: Create RPC function to decline an offer
CREATE OR REPLACE FUNCTION decline_offer(
    p_offer_id uuid,
    p_user_id uuid,
    p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offer public.offers%ROWTYPE;
    v_conversation_id uuid;
BEGIN
    -- Get the offer
    SELECT * INTO v_offer FROM public.offers 
    WHERE id = p_offer_id AND status = 'pending';
    
    IF v_offer IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Offer not found or not pending');
    END IF;
    
    -- Verify the user is either the seeker or seller
    IF v_offer.seeker_id != p_user_id::text AND v_offer.seller_id != p_user_id::text THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized to decline this offer');
    END IF;
    
    -- Update offer status
    UPDATE public.offers 
    SET status = 'declined', updated_at = now()
    WHERE id = p_offer_id;
    
    -- Send decline message if conversation exists
    SELECT id INTO v_conversation_id
    FROM public.conversations
    WHERE listing_id = v_offer.seek_listing_id
    AND buyer_id = v_offer.seeker_id
    AND seller_id = v_offer.seller_id
    LIMIT 1;
    
    IF v_conversation_id IS NOT NULL THEN
        INSERT INTO public.messages (
            conversation_id,
            sender_id,
            content,
            message_type
        ) VALUES (
            v_conversation_id,
            p_user_id,
            CASE 
                WHEN p_reason IS NOT NULL THEN 
                    format('❌ Offer declined. Reason: %s', p_reason)
                ELSE 
                    '❌ Offer declined.'
            END,
            'system'
        );
    END IF;
    
    RETURN jsonb_build_object('success', true);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Step 6: Create function to get offers for a user
CREATE OR REPLACE FUNCTION get_user_offers(
    p_user_id uuid,
    p_role text DEFAULT 'both' -- 'seeker', 'seller', or 'both'
) RETURNS TABLE (
    offer_id uuid,
    seek_listing_id uuid,
    seek_listing_title text,
    offer_listing_id uuid,
    offer_listing_title text,
    seeker_id text,
    seeker_name text,
    seller_id text,
    seller_name text,
    price_cents integer,
    formatted_price text,
    message text,
    status text,
    created_at timestamptz,
    updated_at timestamptz,
    is_seeker boolean,
    can_accept boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id as offer_id,
        o.seek_listing_id,
        sl.title as seek_listing_title,
        o.offer_listing_id,
        ol.title as offer_listing_title,
        o.seeker_id,
        seeker.name as seeker_name,
        o.seller_id,
        seller.name as seller_name,
        o.price_cents,
        CASE 
            WHEN o.price_cents IS NOT NULL THEN 
                '$' || (o.price_cents::numeric / 100)::text
            WHEN ol.price IS NOT NULL THEN
                '$' || ol.price::text
            ELSE NULL
        END as formatted_price,
        o.message,
        o.status,
        o.created_at,
        o.updated_at,
        o.seeker_id = p_user_id::text as is_seeker,
        o.seeker_id = p_user_id::text AND o.status = 'pending' as can_accept
    FROM public.offers o
    JOIN public.listings sl ON sl.id = o.seek_listing_id
    LEFT JOIN public.listings ol ON ol.id = o.offer_listing_id
    JOIN public.users seeker ON seeker.id = o.seeker_id::uuid
    JOIN public.users seller ON seller.id = o.seller_id::uuid
    WHERE 
        CASE p_role
            WHEN 'seeker' THEN o.seeker_id = p_user_id::text
            WHEN 'seller' THEN o.seller_id = p_user_id::text
            ELSE o.seeker_id = p_user_id::text OR o.seller_id = p_user_id::text
        END
    ORDER BY o.created_at DESC;
END;
$$;

-- Step 7: Grant necessary permissions
GRANT EXECUTE ON FUNCTION accept_offer TO authenticated;
GRANT EXECUTE ON FUNCTION decline_offer TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_offers TO authenticated;

COMMIT;

-- Instructions for use:
-- 1. Run this migration in your Supabase SQL editor
-- 2. The offers table now supports custom price offers
-- 3. Use accept_offer() to convert an accepted offer into an order
-- 4. Use decline_offer() to decline an offer with optional reason
-- 5. Use get_user_offers() to fetch all offers for a user
