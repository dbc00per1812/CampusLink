-- Test the create_offer_payment_intent Edge Function directly
-- First, let's get a recent offer to test with

SELECT 
    id,
    seek_listing_id,
    seller_id,
    seeker_id,
    price_cents,
    status,
    created_at
FROM public.offers 
WHERE status = 'pending'
ORDER BY created_at DESC 
LIMIT 1;

-- Check if the offer exists and has the right data
-- Replace the offer_id and buyer_id below with actual values from the query above

-- Example test (replace with actual IDs):
-- SELECT extensions.http((
--     'POST',
--     'https://your-project.supabase.co/functions/v1/create_offer_payment_intent',
--     ARRAY[
--         extensions.http_header('Authorization', 'Bearer YOUR_JWT_TOKEN'),
--         extensions.http_header('Content-Type', 'application/json')
--     ],
--     '{"offer_id": "7FAD8A9D-E38F-4A15-A577-5EDC7A4A5FF3", "buyer_id": "actual-buyer-id"}'
-- ));
