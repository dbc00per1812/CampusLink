-- Create the reserve_then_order RPC function that the app is expecting
-- This function creates an order with proper validation and atomic operations

CREATE OR REPLACE FUNCTION public.reserve_then_order(
    p_listing_id uuid,
    p_buyer_id uuid,
    p_seller_id uuid,
    p_price_cents text,  -- App sends as string
    p_payment_method text
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order public.orders;
    v_listing public.listings;
    v_price_cents integer;
BEGIN
    -- Convert price to integer
    v_price_cents := p_price_cents::integer;
    
    -- Verify listing exists and is available
    SELECT * INTO v_listing 
    FROM public.listings 
    WHERE id = p_listing_id 
      AND status = 'active'
      AND is_sold = false
    FOR UPDATE;  -- Lock the listing row
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Listing not found or not available';
    END IF;
    
    -- Verify buyer and seller are different
    IF p_buyer_id = p_seller_id THEN
        RAISE EXCEPTION 'Buyer and seller cannot be the same';
    END IF;
    
    -- Create the order
    INSERT INTO public.orders (
        listing_id,
        buyer_id,
        seller_id,
        price_cents,
        payment_method,
        payment_status,
        order_status,
        marketplace_fee_cents,
        created_at,
        updated_at
    ) VALUES (
        p_listing_id,
        p_buyer_id,
        p_seller_id,
        v_price_cents,
        p_payment_method,
        'succeeded',  -- Payment already succeeded via Stripe
        'placed',
        0,  -- Fee calculation can be added later
        now(),
        now()
    )
    RETURNING * INTO v_order;
    
    -- Mark listing as sold
    UPDATE public.listings 
    SET is_sold = true,
        status = 'sold',
        reserved_by = NULL,
        reserved_until = NULL
    WHERE id = p_listing_id;
    
    -- Create conversation if it doesn't exist
    INSERT INTO public.conversations (
        listing_id,
        buyer_id,
        seller_id
    )
    SELECT 
        p_listing_id,
        p_buyer_id,
        p_seller_id
    WHERE NOT EXISTS (
        SELECT 1 FROM public.conversations
        WHERE listing_id = p_listing_id 
          AND buyer_id = p_buyer_id 
          AND seller_id = p_seller_id
    );
    
    RETURN v_order;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.reserve_then_order(uuid, uuid, uuid, text, text) TO authenticated;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
