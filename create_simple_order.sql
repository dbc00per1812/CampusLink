-- Create a simple function to insert orders without JSON parsing issues
CREATE OR REPLACE FUNCTION public.create_order_simple(
    p_listing_id text,
    p_buyer_id text,
    p_seller_id text,
    p_price_cents integer,
    p_payment_method text,
    p_escrow_account_id text
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order public.orders;
BEGIN
    -- Insert the order
    INSERT INTO public.orders (
        listing_id,
        buyer_id,
        seller_id,
        price_cents,
        payment_method,
        payment_status,
        order_status,
        stripe_escrow_account_id,
        marketplace_fee_cents,
        created_at,
        updated_at
    ) VALUES (
        p_listing_id::uuid,
        p_buyer_id::uuid,
        p_seller_id::uuid,
        p_price_cents,
        p_payment_method,
        'succeeded',
        'placed',
        p_escrow_account_id,
        0,
        now(),
        now()
    )
    RETURNING * INTO v_order;
    
    -- Mark listing as sold
    UPDATE public.listings 
    SET is_sold = true,
        status = 'sold'
    WHERE id = p_listing_id::uuid;
    
    RETURN v_order;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.create_order_simple(text, text, text, integer, text, text) TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
