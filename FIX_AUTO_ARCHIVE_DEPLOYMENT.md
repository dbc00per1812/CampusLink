# Fix Auto-Archive System - Complete Deployment Guide

## Problem
Posts are NOT being archived after purchase, even though the code and SQL were created. The triggers were likely never deployed to the production database.

## Solution Overview
Deploy the auto-archive database triggers to Supabase. These triggers will automatically:
1. ✅ Archive posts when quantity reaches 0 after purchase
2. ✅ Decrement quantity_available and increment quantity_sold
3. ✅ Handle cancellations by restoring quantity

---

## Step 1: Verify Current State (REQUIRED)

**Go to Supabase → SQL Editor** and run:

```sql
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel');
```

### Expected Results:
- **0 rows** = Triggers were NEVER deployed ❌ → Proceed to Step 2
- **2 rows** = Triggers exist ✅ → Skip to Step 3 (they might be working)

---

## Step 2: Deploy Auto-Archive Triggers (MAIN FIX)

**Go to Supabase → SQL Editor**, open the file:
`DEPLOY_AUTO_ARCHIVE_FIX.sql`

**Copy the ENTIRE contents** and **Run** it in Supabase SQL Editor.

This will:
- ✅ Create the trigger functions with detailed logging
- ✅ Create the triggers on the orders table
- ✅ Verify deployment was successful

### What to Look For:
After running, you should see output showing:
```
✅ TRIGGERS CREATED:
- update_listing_quantity_after_order
- restore_listing_quantity_on_order_cancel

✅ FUNCTIONS CREATED:
- update_listing_quantity_on_order
- restore_listing_quantity_on_cancel
```

---

## Step 2.5: Retroactive Fix for Existing Orders

⚠️ **IMPORTANT:** The triggers are NOT retroactive! They only work for orders created AFTER deployment.

If you have listings that were already purchased but not archived, you need to fix them manually:

**Go to Supabase → SQL Editor**, open the file:
`RETROACTIVE_ARCHIVE_FIX.sql`

### Quick Steps:
1. **Run STEP 1** - Preview which listings need fixing
2. **Uncomment and run STEP 3** - Simple archive update:
   ```sql
   UPDATE listings
   SET archived = true
   WHERE quantity_available <= 0 AND archived = false;
   ```
3. **Run STEP 4** - Verify the fix worked

This is a **one-time fix**. After this, all new orders will be handled automatically by the triggers.

---

## Step 3: Test the System

### Option A: Test with New Purchase (Recommended)

1. **Create a test listing** in your app with:
   - Title: "Test Auto-Archive"
   - Price: $1.00
   - Quantity: 1

2. **Make a purchase** using another test account

3. **Check the listing** in Supabase:
   ```sql
   SELECT id, title, quantity_available, quantity_sold, archived
   FROM listings
   WHERE title = 'Test Auto-Archive';
   ```

4. **Expected Result:**
   - `quantity_available` = 0
   - `quantity_sold` = 1
   - `archived` = true ✅

### Option B: Check Recent Orders

```sql
-- Check recent orders and their listing status
SELECT 
    o.id as order_id,
    o.created_at,
    o.payment_status,
    o.order_status,
    o.quantity as order_quantity,
    l.id as listing_id,
    l.title,
    l.quantity_available,
    l.quantity_sold,
    l.archived,
    CASE 
        WHEN l.quantity_available = 0 AND l.archived = true THEN '✅ ARCHIVED'
        WHEN l.quantity_available = 0 AND l.archived = false THEN '❌ SHOULD BE ARCHIVED'
        ELSE '⏳ STILL AVAILABLE'
    END as status
FROM orders o
JOIN listings l ON l.id = o.listing_id
WHERE o.payment_status = 'succeeded'
ORDER BY o.created_at DESC
LIMIT 10;
```

---

## Step 4: Check Trigger Logs (Debugging)

If you want to see if the triggers are firing, check the PostgreSQL logs:

**In Supabase → Logs → Postgres Logs**, look for:
- `🔔 Auto-archive trigger fired for order`
- `✅ Listing archived (sold out)`
- `✅ Listing updated - X units remaining`

---

## How It Works

### When a Purchase is Made:

```
1. App creates order with payment_status = 'succeeded', order_status = 'placed'
2. Trigger: update_listing_quantity_after_order fires
3. Database updates listing:
   - quantity_available -= order.quantity
   - quantity_sold += order.quantity
   - archived = true (if quantity_available = 0)
```

### When an Order is Cancelled:

```
1. App updates order with order_status = 'cancelled'
2. Trigger: restore_listing_quantity_on_order_cancel fires
3. Database updates listing:
   - quantity_available += order.quantity
   - quantity_sold -= order.quantity
   - archived = false (if quantity_available > 0)
```

---

## Troubleshooting

### Problem: Triggers deployed but posts still not archiving

**Check the order status in database:**
```sql
SELECT id, payment_status, order_status, quantity, created_at
FROM orders
ORDER BY created_at DESC
LIMIT 5;
```

**The trigger ONLY fires when:**
- ✅ `payment_status` = 'succeeded' 
- ✅ `order_status` IN ('placed', 'confirmed')
- ✅ Both conditions must be true!

### Problem: I see the triggers but they don't seem to work

**Manually test the trigger:**
```sql
-- Get an existing order
SELECT id, listing_id FROM orders LIMIT 1;

-- Manually fire the trigger by re-inserting a test order
-- (Replace UUIDs with real ones from your database)
INSERT INTO orders (
    listing_id, 
    buyer_id, 
    seller_id, 
    price_cents, 
    payment_method, 
    payment_status, 
    order_status, 
    quantity
) VALUES (
    'YOUR-LISTING-ID',
    'YOUR-BUYER-ID',
    'YOUR-SELLER-ID',
    100,
    'card',
    'succeeded',
    'placed',
    1
);
```

Check if the listing gets archived after this insert.

---

## Verification Checklist

Before considering this complete, verify:

- [ ] Triggers exist in database (Step 1 query returns 2 rows)
- [ ] Functions exist in database (verification query in deploy script)
- [ ] **Retroactive fix applied** for old orders (Step 2.5)
- [ ] Old sold-out listings are now archived
- [ ] Test purchase archives the listing (quantity=0, archived=true)
- [ ] App hides archived listings from homepage/search
- [ ] Seller can still see archived listings in their dashboard

---

## Files Reference

- `DEPLOY_AUTO_ARCHIVE_FIX.sql` - Main deployment script (run this!)
- `RETROACTIVE_ARCHIVE_FIX.sql` - One-time fix for old orders (run after triggers)
- `VERIFY_AUTO_ARCHIVE_TRIGGERS.sql` - Verification queries
- `auto_archive_listings.sql` - Original version (less detailed logging)
- `ACTION_REQUIRED_AUTO_ARCHIVE.md` - Quick start guide

---

## Still Not Working?

If after following all steps posts still aren't archiving:

1. **Check app code** - Verify orders are created with correct status:
   ```swift
   orderStatus: "placed"
   paymentStatus: "succeeded"
   ```

2. **Check database directly** after a purchase:
   ```sql
   SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '1 hour';
   ```

3. **Enable detailed logging** - The triggers have RAISE NOTICE statements that will show in Postgres logs

4. **Contact me** - Share the results of the verification queries and I'll help debug further.

---

**Created:** October 16, 2025  
**Status:** Ready to deploy  
**Priority:** HIGH - Core functionality broken

