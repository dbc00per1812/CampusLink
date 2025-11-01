-- ============================================
-- DELETE ALL USERS AND DATA
-- WARNING: This will delete ALL data from the database
-- Use only in development/testing environments
-- ============================================

-- TRUNCATE CASCADE handles all foreign keys and triggers automatically
-- All tables from your actual database schema

TRUNCATE TABLE 
    conversations,
    disputes,
    listings,
    messages,
    notifications,
    offers,
    orders,
    payments,
    payouts,
    push_notification_queue,
    ratings,
    reports,
    service_bookings,
    time_slot_bookings,
    time_slots,
    trigger_debug_log,
    user_notification_preferences,
    users,
    wallet_transactions,
    wallets
RESTART IDENTITY CASCADE;

-- Delete from auth.users (can't use TRUNCATE on Supabase auth tables)
DELETE FROM auth.users;

-- Confirmation message
SELECT 'All users and data have been deleted successfully.' AS status;
