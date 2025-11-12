-- Check if the order was updated by the webhook after payment

-- 1. Check the order that should have been updated
SELECT 
  id,
  order_status,
  payment_status,
  stripe_payment_intent_id,
  buyer_price_cents,
  seller_price_cents,
  created_at,
  updated_at
FROM orders
WHERE id = '7440705A-E6A0-4651-A41F-090B71698A5C';

-- Expected after webhook:
-- payment_status: 'succeeded' (not 'pending')
-- stripe_payment_intent_id: 'pi_3SSWh6PwXrdA7iH...' (not null)
-- updated_at: should be recent (12:51 AM)

-- 2. Check if duplicate order was created
SELECT 
  id,
  order_status,
  payment_status,
  stripe_payment_intent_id,
  created_at
FROM orders
WHERE listing_id = (SELECT listing_id FROM orders WHERE id = '7440705A-E6A0-4651-A41F-090B71698A5C')
ORDER BY created_at DESC
LIMIT 5;

-- Should only see ONE order for this listing, not multiple

-- 3. Check payments table for the payment_intent
SELECT 
  id,
  payment_intent_id,
  listing_id,
  buyer_id,
  seller_id,
  amount,
  status,
  created_at
FROM payments
WHERE payment_intent_id LIKE 'pi_3SSW%'
ORDER BY created_at DESC
LIMIT 3;

-- This shows if the payment record was created

