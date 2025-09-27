
-- Disable the problematic trigger that's causing conflicts with Stripe payments
DROP TRIGGER IF EXISTS create_payment_on_order_insert ON public.orders;
DROP TRIGGER IF EXISTS update_payment_on_order_update ON public.orders;

-- Also drop the trigger functions
DROP FUNCTION IF EXISTS create_payment_for_order();
DROP FUNCTION IF EXISTS update_payment_for_order();

