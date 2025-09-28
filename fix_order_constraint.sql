-- DEFINITIVE FIX: Remove the problematic foreign key constraint
-- This constraint requires a payment to exist before an order can be created

-- Drop the foreign key constraint that's causing the issue
ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_stripe_payment_intent_fkey;

-- The stripe_payment_intent_id should be nullable and not require a payment record
ALTER TABLE public.orders 
ALTER COLUMN stripe_payment_intent_id DROP NOT NULL;

-- Ensure we can insert orders without payment intent IDs
COMMENT ON COLUMN public.orders.stripe_payment_intent_id IS 'Optional reference to Stripe payment intent - not required for order creation';

-- Verify the constraint is gone
SELECT conname 
FROM pg_constraint 
WHERE conrelid = 'public.orders'::regclass 
AND conname = 'orders_stripe_payment_intent_fkey';
