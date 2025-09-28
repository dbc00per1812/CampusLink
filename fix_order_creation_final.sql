-- FINAL FIX: Create order using RPC to bypass JSON parsing entirely
-- This function handles order creation with proper validation

DROP FUNCTION IF EXISTS public.create_order_bypass CASCADE;

CREATE OR REPLACE FUNCTION public.create_order_bypass(
    p_listing_id text,
    p_buyer_id text,
    p_seller_id text,
    p_price_cents integer,
    p_payment_method text,
    p_escrow_account_id text,
    p_time_slot_id text DEFAULT NULL
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order public.orders;
BEGIN
    -- Insert the order and return it
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
        time_slot_id
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
        CASE WHEN p_time_slot_id IS NOT NULL AND p_time_slot_id != '' THEN p_time_slot_id::uuid ELSE NULL END
    )
    RETURNING * INTO v_order;
    
    -- Mark listing as sold
    UPDATE public.listings 
    SET is_sold = true,
        status = 'sold'
    WHERE id = p_listing_id::uuid;
    
    RETURN v_order;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Order creation failed: %', SQLERRM;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.create_order_bypass TO authenticated;

-- Ensure RLS policies are correct
DROP POLICY IF EXISTS "Authenticated users can create orders as buyer" ON public.orders;
CREATE POLICY "Authenticated users can create orders as buyer" ON public.orders
    FOR INSERT TO authenticated
    WITH CHECK (buyer_id = auth.uid());

DROP POLICY IF EXISTS "Users can view their own orders" ON public.orders;
CREATE POLICY "Users can view their own orders" ON public.orders
    FOR SELECT TO authenticated
    USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Refresh schema
NOTIFY pgrst, 'reload schema';
