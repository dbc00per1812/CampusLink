-- Direct SQL test to see what the actual error is

-- First, let's see what a simple insert does
INSERT INTO public.orders (
    listing_id,
    buyer_id,
    seller_id,
    price_cents,
    payment_method,
    payment_status,
    order_status
) VALUES (
    (SELECT id FROM public.listings LIMIT 1), -- Use an existing listing
    auth.uid(), -- Current user as buyer
    (SELECT user_id FROM public.listings LIMIT 1), -- Seller from the listing
    1000, -- $10.00
    'card',
    'succeeded',
    'placed'
);

-- If that fails, let's try with explicit UUIDs to test
-- You'll need to replace these with actual UUIDs from your database
/*
INSERT INTO public.orders (
    listing_id,
    buyer_id,
    seller_id,
    price_cents,
    payment_method,
    payment_status,
    order_status
) VALUES (
    'YOUR_LISTING_ID_HERE'::uuid,
    'YOUR_BUYER_ID_HERE'::uuid,
    'YOUR_SELLER_ID_HERE'::uuid,
    1000,
    'card',
    'succeeded',
    'placed'
);
*/
