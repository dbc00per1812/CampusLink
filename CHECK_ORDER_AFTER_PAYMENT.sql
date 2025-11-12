-- Check if the order was updated by the webhook after payment

-- Get your most recent order
SELECT 
  id,
  listing_id,
  buyer_id,
  seller_id,
  order_status,
  payment_status,
  stripe_payment_intent_id,
  buyer_price_cents / 100.0 as buyer_price_dollars,
  seller_price_cents / 100.0 as seller_price_dollars,
  created_at,
  updated_at,
  EXTRACT(EPOCH FROM (NOW() - updated_at))/60 as minutes_since_update
FROM orders
WHERE buyer_id = auth.uid()
ORDER BY created_at DESC
LIMIT 1;

-- Expected after payment:
-- payment_status should be 'requires_capture' or 'succeeded' (NOT 'pending')
-- stripe_payment_intent_id should be filled in (NOT null)
-- updated_at should be recent (within last few minutes)

-- If payment_status is still 'pending':
-- → Webhook didn't fire or failed
-- → Need to check Stripe webhook logs
-- → May need to manually update order

