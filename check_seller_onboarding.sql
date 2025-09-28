-- Check if the seller (listing owner) has completed Stripe Connect onboarding

-- Find the most recent listing you tried to buy from
SELECT 'Recent listings:' as info;
SELECT 
  l.id,
  l.title,
  l.user_id as seller_id,
  u.name as seller_name,
  u.stripe_connect_id,
  CASE 
    WHEN u.stripe_connect_id IS NOT NULL THEN '✅ Onboarded'
    ELSE '❌ NOT onboarded - THIS IS THE PROBLEM'
  END as onboarding_status
FROM listings l
JOIN users u ON l.user_id = u.id
WHERE l.created_at >= CURRENT_DATE - INTERVAL '7 days'
  AND l.user_id != '50b58786-ffe6-4b99-b7d3-a1b12e21c539' -- Not your own listings
ORDER BY l.created_at DESC
LIMIT 5;

-- Check YOUR Stripe Connect status too
SELECT 'Your Stripe status:' as your_status;
SELECT 
  name,
  stripe_connect_id,
  CASE 
    WHEN stripe_connect_id IS NOT NULL THEN '✅ You are onboarded'
    ELSE '❌ You are NOT onboarded'
  END as your_onboarding_status
FROM users 
WHERE id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539';
