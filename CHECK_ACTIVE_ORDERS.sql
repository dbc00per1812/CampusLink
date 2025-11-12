-- Check what orders are being counted as "active"
-- Run this in Supabase SQL Editor to see what's actually in the database

-- 1. Check ALL orders for current user
-- Replace 'YOUR_USER_ID' with your actual user ID from auth.users
SELECT 
    id,
    order_status,
    payment_status,
    buyer_id,
    seller_id,
    created_at,
    updated_at
FROM orders
WHERE buyer_id = 'YOUR_USER_ID'::uuid 
   OR seller_id = 'YOUR_USER_ID'::uuid
ORDER BY created_at DESC;

-- 2. Check what orders SHOULD be counted as "buyer needs to pay"
SELECT 
    id,
    order_status,
    payment_status,
    'BUYER_NEEDS_TO_PAY' as reason
FROM orders
WHERE buyer_id = 'YOUR_USER_ID'::uuid
  AND order_status = 'placed'
  AND payment_status = 'pending';

-- 3. Check what orders SHOULD be counted as "buyer needs to confirm"
SELECT 
    id,
    order_status,
    payment_status,
    'BUYER_NEEDS_TO_CONFIRM' as reason
FROM orders
WHERE buyer_id = 'YOUR_USER_ID'::uuid
  AND order_status = 'seller_confirmed'
  AND payment_status = 'requires_capture';

-- 4. Check what orders SHOULD be counted as "seller needs to deliver"
SELECT 
    id,
    order_status,
    payment_status,
    'SELLER_NEEDS_TO_DELIVER' as reason
FROM orders
WHERE seller_id = 'YOUR_USER_ID'::uuid
  AND order_status IN ('placed', 'in_progress')
  AND payment_status IN ('succeeded', 'requires_capture');

-- 5. Get your user ID (run this first to get YOUR_USER_ID)
SELECT id, email FROM auth.users WHERE email = 'your-email@example.com';

