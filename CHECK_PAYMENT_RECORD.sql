-- Check if payment record exists for the payment intent

SELECT 
  id,
  payment_intent_id,
  listing_id,
  buyer_id,
  seller_id,
  amount,
  status,
  payment_method,
  created_at
FROM payments
WHERE payment_intent_id = 'pi_3SSWh6PwXrdA7iH0ijuREfiL'
ORDER BY created_at DESC;

-- Also check with LIKE in case it's truncated
SELECT 
  id,
  payment_intent_id,
  listing_id,
  amount,
  status
FROM payments
WHERE payment_intent_id LIKE 'pi_3SSWh6%'
ORDER BY created_at DESC;

-- If nothing found, the payment record wasn't created!

