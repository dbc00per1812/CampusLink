-- MANUAL FIX: Update order after successful payment (if webhook failed)
-- ONLY run this if you verified payment succeeded in Stripe but order not updated

-- Step 1: First check the order status
SELECT 
  id,
  order_status,
  payment_status,
  stripe_payment_intent_id,
  created_at
FROM orders
WHERE buyer_id = auth.uid()
ORDER BY created_at DESC
LIMIT 1;

-- Step 2: Get the payment_intent_id from Stripe Dashboard
-- Go to: https://dashboard.stripe.com/test/payments
-- Find your most recent payment
-- Copy the payment_intent ID (starts with pi_...)

-- Step 3: Update the order manually
-- REPLACE 'YOUR_ORDER_ID' and 'pi_YOUR_PAYMENT_INTENT_ID' with actual values

/*
UPDATE orders
SET 
  payment_status = 'requires_capture',
  stripe_payment_intent_id = 'pi_YOUR_PAYMENT_INTENT_ID',
  updated_at = NOW()
WHERE id = 'YOUR_ORDER_ID'
  AND buyer_id = auth.uid();
*/

-- Step 4: Verify it worked
SELECT 
  id,
  order_status,
  payment_status,
  stripe_payment_intent_id,
  updated_at
FROM orders
WHERE buyer_id = auth.uid()
ORDER BY created_at DESC
LIMIT 1;

-- After this, close and reopen the order in the app
-- The "Confirm Order & Pay" button should disappear

