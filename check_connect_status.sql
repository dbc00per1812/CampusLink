-- Check if user has completed Stripe Connect onboarding
SELECT 
    id,
    email,
    stripe_connect_id,
    has_debit_card,
    created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;
