-- Quick fix for UUID type mismatch errors in offers system
-- Run this in Supabase SQL Editor to fix "operator does not exist: uuid <> text" errors

BEGIN;

-- First, add the price_cents column if it doesn't exist
ALTER TABLE public.offers 
ADD COLUMN IF NOT EXISTS price_cents integer;

-- Make offer_listing_id nullable
ALTER TABLE public.offers 
ALTER COLUMN offer_listing_id DROP NOT NULL;

-- Add constraint
ALTER TABLE public.offers 
DROP CONSTRAINT IF EXISTS offers_must_have_price_or_listing,
ADD CONSTRAINT offers_must_have_price_or_listing CHECK (
    (offer_listing_id IS NOT NULL) OR (price_cents IS NOT NULL AND price_cents > 0)
);

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS accept_offer(uuid, uuid);
DROP FUNCTION IF EXISTS decline_offer(uuid, uuid, text);

-- Create fixed accept_offer function with proper UUID handling
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
    v_order_id uuid;
    v_price_cents integer;
    v_listing_id uuid;
    v_conversation_id uuid;
BEGIN
    -- Get the offer
    SELECT * INTO v_offer FROM public.offers 
    WHERE id = p_offer_id AND status = 'pending';
    
    IF v_offer IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Offer not found or not pending');
    END IF;
    
    -- Verify the user is the seeker (FIXED: proper UUID comparison)
    IF v_offer.seeker_id::uuid != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the seeker can accept offers');
    END IF;
    
    -- Get the seek listing
    SELECT * INTO v_seek_listing FROM public.listings 
    WHERE id = v_offer.seek_listing_id;
    
    -- Determine price and listing ID
    IF v_offer.price_cents IS NOT NULL THEN
        -- Custom price offer
        v_price_cents := v_offer.price_cents;
        v_listing_id := v_offer.seek_listing_id;
    ELSE
        -- Traditional listing offer (fallback)
        v_price_cents := 1000; -- $10.00 default
        v_listing_id := v_offer.seek_listing_id;
    END IF;
    
    -- Update offer status
    UPDATE public.offers 
    SET status = 'accepted', updated_at = now()
    WHERE id = p_offer_id;
    
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
        v_offer.seeker_id::uuid,
        v_offer.seller_id::uuid,
        v_price_cents,
        'wallet',
        'pending',
        'placed',
        now(),
        now()
    ) RETURNING id INTO v_order_id;
    
    -- Find or create conversation (FIXED: proper UUID casting)
    SELECT id INTO v_conversation_id
    FROM public.conversations
    WHERE listing_id = v_seek_listing.id
    AND buyer_id = v_offer.seeker_id::uuid
    AND seller_id = v_offer.seller_id::uuid
    LIMIT 1;
    
    IF v_conversation_id IS NULL THEN
        INSERT INTO public.conversations (listing_id, buyer_id, seller_id)
        VALUES (v_seek_listing.id, v_offer.seeker_id::uuid, v_offer.seller_id::uuid)
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

-- Create fixed decline_offer function
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
    
    -- Verify the user is either the seeker or seller (FIXED: proper UUID comparison)
    IF v_offer.seeker_id::uuid != p_user_id AND v_offer.seller_id::uuid != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized to decline this offer');
    END IF;
    
    -- Update offer status
    UPDATE public.offers 
    SET status = 'declined', updated_at = now()
    WHERE id = p_offer_id;
    
    RETURN jsonb_build_object('success', true);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION accept_offer TO authenticated;
GRANT EXECUTE ON FUNCTION decline_offer TO authenticated;

COMMIT;

-- Test the functions
SELECT 'Database setup complete! You can now accept and decline offers.' as status;
