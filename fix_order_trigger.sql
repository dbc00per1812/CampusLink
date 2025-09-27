-- Fix the order trigger that's causing JSON parsing errors
-- The issue is unnecessary UUID casting on fields that are already UUIDs

-- Drop the existing trigger and function
DROP TRIGGER IF EXISTS create_payment_on_order_insert ON public.orders;
DROP FUNCTION IF EXISTS create_payment_for_order();

-- Recreate the function without the unnecessary UUID casts
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
            NEW.buyer_id,  -- Already UUID, no cast needed
            NEW.seller_id,  -- Already UUID, no cast needed
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

-- Recreate the trigger
CREATE TRIGGER create_payment_on_order_insert
AFTER INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION create_payment_for_order();

-- Also check if the RLS policies were applied
-- If not, this will add them (safe to run multiple times)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'payments' 
        AND policyname = 'Users can create payments for their transactions'
    ) THEN
        -- Add INSERT policy for payments table
        CREATE POLICY "Users can create payments for their transactions" ON public.payments
            FOR INSERT 
            TO authenticated
            WITH CHECK (
                buyer_id = auth.uid() OR seller_id = auth.uid()
            );
    END IF;
END $$;
