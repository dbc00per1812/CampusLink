-- Fix order and payment synchronization
-- Ensures all orders have corresponding payment records for wallet visibility

-- First, create any missing payment records for existing orders
INSERT INTO public.payments (
    listing_id,
    buyer_id,
    seller_id,
    amount,
    status,
    payment_method,
    order_id,
    marketplace_fee_cents,
    stripe_escrow_account_id,
    escrow_release_status,
    auto_release_at,
    created_at
)
SELECT 
    o.listing_id,
    o.buyer_id::uuid,
    o.seller_id::uuid,
    o.price_cents / 100.0, -- Convert cents to dollars for payments table
    CASE 
        WHEN o.order_status = 'completed' THEN 'succeeded'
        WHEN o.order_status = 'cancelled' THEN 'cancelled'
        WHEN o.order_status = 'refunded' THEN 'refunded'
        ELSE 'succeeded'
    END as status,
    COALESCE(o.payment_method, 'wallet') as payment_method,
    o.id as order_id,
    COALESCE(o.marketplace_fee_cents, 0) as marketplace_fee_cents,
    o.stripe_escrow_account_id,
    CASE 
        WHEN o.order_status = 'completed' THEN 'released'
        WHEN o.order_status IN ('cancelled', 'refunded') THEN 'refunded'
        ELSE 'held'
    END as escrow_release_status,
    o.created_at + interval '3 days' as auto_release_at,
    o.created_at
FROM public.orders o
LEFT JOIN public.payments p ON p.order_id = o.id
WHERE p.id IS NULL
  AND o.payment_status = 'succeeded';

-- Create a trigger function to automatically create payment records for new orders
CREATE OR REPLACE FUNCTION create_payment_for_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create payment record if order has succeeded payment
    IF NEW.payment_status = 'succeeded' THEN
        INSERT INTO public.payments (
            listing_id,
            buyer_id,
            seller_id,
            amount,
            status,
            payment_method,
            order_id,
            marketplace_fee_cents,
            stripe_escrow_account_id,
            escrow_release_status,
            auto_release_at,
            created_at
        ) VALUES (
            NEW.listing_id,
            NEW.buyer_id::uuid,
            NEW.seller_id::uuid,
            NEW.price_cents / 100.0,
            'succeeded',
            COALESCE(NEW.payment_method, 'wallet'),
            NEW.id,
            COALESCE(NEW.marketplace_fee_cents, 0),
            NEW.stripe_escrow_account_id,
            'held',
            NEW.created_at + interval '3 days',
            NEW.created_at
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the trigger if it exists
DROP TRIGGER IF EXISTS create_payment_on_order_insert ON public.orders;

-- Create the trigger
CREATE TRIGGER create_payment_on_order_insert
AFTER INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION create_payment_for_order();

-- Also handle order status updates
CREATE OR REPLACE FUNCTION update_payment_for_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Update payment status when order status changes
    IF NEW.order_status != OLD.order_status THEN
        UPDATE public.payments
        SET 
            status = CASE 
                WHEN NEW.order_status = 'completed' THEN 'succeeded'
                WHEN NEW.order_status = 'cancelled' THEN 'cancelled'
                WHEN NEW.order_status = 'refunded' THEN 'refunded'
                ELSE status
            END,
            escrow_release_status = CASE 
                WHEN NEW.order_status = 'completed' THEN 'released'
                WHEN NEW.order_status IN ('cancelled', 'refunded') THEN 'refunded'
                ELSE escrow_release_status
            END,
            escrow_release_at = CASE 
                WHEN NEW.order_status = 'completed' THEN NOW()
                ELSE escrow_release_at
            END
        WHERE order_id = NEW.id;
    END IF;
    
    -- Update delivery confirmations
    IF NEW.buyer_confirmed_at IS NOT NULL AND OLD.buyer_confirmed_at IS NULL THEN
        UPDATE public.payments
        SET buyer_confirmed_at = NEW.buyer_confirmed_at
        WHERE order_id = NEW.id;
    END IF;
    
    IF NEW.seller_confirmed_at IS NOT NULL AND OLD.seller_confirmed_at IS NULL THEN
        UPDATE public.payments
        SET delivered_at = NEW.seller_confirmed_at
        WHERE order_id = NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the trigger if it exists
DROP TRIGGER IF EXISTS update_payment_on_order_update ON public.orders;

-- Create the trigger
CREATE TRIGGER update_payment_on_order_update
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION update_payment_for_order();

-- Create a function to get wallet transaction history that includes both payments and orders
CREATE OR REPLACE FUNCTION get_wallet_transactions(p_user_id uuid, p_limit integer DEFAULT 50)
RETURNS TABLE (
    id uuid,
    listing_id uuid,
    buyer_id text,
    seller_id text,
    amount numeric,
    status text,
    payment_method text,
    created_at timestamptz,
    order_id uuid,
    listing_title text,
    is_buyer boolean
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (COALESCE(p.order_id, p.id))
        COALESCE(p.id, o.id) as id,
        COALESCE(p.listing_id, o.listing_id) as listing_id,
        COALESCE(p.buyer_id::text, o.buyer_id) as buyer_id,
        COALESCE(p.seller_id::text, o.seller_id) as seller_id,
        COALESCE(p.amount, o.price_cents / 100.0) as amount,
        COALESCE(p.status, 
            CASE 
                WHEN o.order_status = 'completed' THEN 'succeeded'
                WHEN o.order_status = 'cancelled' THEN 'cancelled'
                WHEN o.order_status = 'refunded' THEN 'refunded'
                ELSE 'succeeded'
            END
        ) as status,
        COALESCE(p.payment_method, o.payment_method, 'wallet') as payment_method,
        COALESCE(p.created_at, o.created_at) as created_at,
        COALESCE(p.order_id, o.id) as order_id,
        l.title as listing_title,
        CASE 
            WHEN COALESCE(p.buyer_id::text, o.buyer_id) = p_user_id::text THEN true
            ELSE false
        END as is_buyer
    FROM public.payments p
    FULL OUTER JOIN public.orders o ON p.order_id = o.id
    LEFT JOIN public.listings l ON COALESCE(p.listing_id, o.listing_id) = l.id
    WHERE (
        COALESCE(p.buyer_id::text, o.buyer_id) = p_user_id::text 
        OR COALESCE(p.seller_id::text, o.seller_id) = p_user_id::text
    )
    AND COALESCE(p.status, 'succeeded') NOT IN ('failed', 'cancelled')
    AND COALESCE(o.payment_status, 'succeeded') = 'succeeded'
    ORDER BY COALESCE(p.order_id, p.id), COALESCE(p.created_at, o.created_at) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_wallet_transactions(uuid, integer) TO authenticated;

-- Add RLS policy for the function
CREATE POLICY "Users can view their own transactions" ON public.payments
    FOR SELECT USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- Add comment to explain the fix
COMMENT ON FUNCTION create_payment_for_order() IS 'Automatically creates payment records for orders to ensure wallet transaction visibility';
COMMENT ON FUNCTION get_wallet_transactions(uuid, integer) IS 'Returns unified transaction history from both payments and orders tables';
