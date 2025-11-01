-- ============================================
-- Quick Verification Script for Offer Setup
-- Run this in Supabase SQL Editor to verify everything is configured
-- ============================================

-- 1. Check if offers table exists and has correct structure
SELECT 
    'Offers Table Structure' as check_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'offers'
ORDER BY ordinal_position;

-- 2. Verify RPC functions exist
SELECT 
    'RPC Functions' as check_name,
    proname as function_name,
    pronargs as num_arguments
FROM pg_proc
WHERE proname IN ('accept_offer', 'decline_offer', 'get_user_offers')
ORDER BY proname;

-- 3. Check triggers are active
SELECT 
    'Active Triggers' as check_name,
    trigger_name,
    event_manipulation as event_type,
    action_timing as timing
FROM information_schema.triggers
WHERE event_object_table = 'offers'
ORDER BY trigger_name;

-- 4. Check RLS policies on offers table
SELECT 
    'RLS Policies' as check_name,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command
FROM pg_policies
WHERE tablename = 'offers'
ORDER BY policyname;

-- 5. Verify indexes on offers table
SELECT
    'Indexes' as check_name,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'offers'
ORDER BY indexname;

-- 6. Count existing offers by status
SELECT 
    'Offer Statistics' as check_name,
    status,
    COUNT(*) as count
FROM offers
GROUP BY status
ORDER BY count DESC;

-- 7. Check recent offers (last 24 hours)
SELECT 
    'Recent Offers' as check_name,
    o.id,
    o.status,
    o.price_cents,
    l.title as seek_listing_title,
    p.name as seller_name,
    o.created_at
FROM offers o
LEFT JOIN listings l ON o.seek_listing_id = l.id
LEFT JOIN profiles p ON o.seller_id = p.id
WHERE o.created_at > NOW() - INTERVAL '24 hours'
ORDER BY o.created_at DESC
LIMIT 10;

-- 8. Verify seek listings exist for offers to be made on
SELECT 
    'Active Seek Listings' as check_name,
    COUNT(*) as count
FROM listings
WHERE listing_type = 'seek' 
AND status = 'active';

-- 9. Check notification triggers work (test function existence)
SELECT 
    'Notification Functions' as check_name,
    proname as function_name
FROM pg_proc
WHERE proname IN ('notify_new_offer', 'notify_offer_status_change');

-- 10. Verify price_cents column allows NULL (for custom pricing)
SELECT
    'Price Column Validation' as check_name,
    column_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'offers' 
AND column_name IN ('price_cents', 'offer_listing_id');

-- ============================================
-- Summary Check
-- ============================================
DO $$
DECLARE
    offers_table_exists BOOLEAN;
    rpc_count INTEGER;
    trigger_count INTEGER;
    notification_func_count INTEGER;
BEGIN
    -- Check table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'offers'
    ) INTO offers_table_exists;
    
    -- Check RPC functions
    SELECT COUNT(*) INTO rpc_count
    FROM pg_proc
    WHERE proname IN ('accept_offer', 'decline_offer', 'get_user_offers');
    
    -- Check triggers
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers
    WHERE event_object_table = 'offers';
    
    -- Check notification functions
    SELECT COUNT(*) INTO notification_func_count
    FROM pg_proc
    WHERE proname IN ('notify_new_offer', 'notify_offer_status_change');
    
    -- Output summary
    RAISE NOTICE '============================================';
    RAISE NOTICE 'OFFER SETUP VERIFICATION SUMMARY';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Offers table exists: %', offers_table_exists;
    RAISE NOTICE 'RPC functions found: % of 3 expected', rpc_count;
    RAISE NOTICE 'Triggers found: % of 2 expected', trigger_count;
    RAISE NOTICE 'Notification functions: % of 2 expected', notification_func_count;
    RAISE NOTICE '============================================';
    
    IF offers_table_exists AND rpc_count = 3 AND trigger_count >= 2 AND notification_func_count = 2 THEN
        RAISE NOTICE 'STATUS: ✅ ALL CHECKS PASSED - Offer system is ready!';
    ELSE
        RAISE NOTICE 'STATUS: ⚠️  ISSUES DETECTED - Review output above';
        IF NOT offers_table_exists THEN
            RAISE NOTICE '  - Offers table is missing';
        END IF;
        IF rpc_count < 3 THEN
            RAISE NOTICE '  - Missing RPC functions (found % of 3)', rpc_count;
        END IF;
        IF trigger_count < 2 THEN
            RAISE NOTICE '  - Missing triggers (found % of 2)', trigger_count;
        END IF;
        IF notification_func_count < 2 THEN
            RAISE NOTICE '  - Missing notification functions (found % of 2)', notification_func_count;
        END IF;
    END IF;
    RAISE NOTICE '============================================';
END $$;

