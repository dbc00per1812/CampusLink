# Deploy Escrow Status Tracking Fix

## Overview
This fix ensures the `escrow_release_status` field in the `payments` table is properly tracked at all times throughout the order lifecycle.

## What This Fixes

✅ **Database tracking** - `escrow_release_status` now updates automatically  
✅ **Webhook updates** - Sets status to 'held' when payment succeeds  
✅ **Order completion** - Sets status to 'released' when buyer confirms  
✅ **UI display** - Shows accurate escrow status from database  
✅ **Historical data** - Backfills existing records  
✅ **Future-proof** - Database triggers keep everything in sync  

---

## Deployment Steps

### Step 1: Deploy Database Changes

Run this SQL in your Supabase SQL Editor:

```bash
# File: FIX_ESCROW_STATUS_TRACKING.sql
```

This will:
- Backfill all existing payment records with correct escrow status
- Create database triggers to auto-update escrow status
- Create `escrow_status_view` for easy querying

**Expected output**: 
- Existing records updated
- 2 triggers created
- 1 view created
- Verification query showing no mismatches

### Step 2: Deploy Stripe Webhook

Deploy the updated webhook function:

```bash
cd supabase/functions
npx supabase functions deploy stripe-webhook
```

**Changes**:
- Sets `escrow_release_status = 'held'` when payment succeeds
- Logs escrow status updates

### Step 3: Build & Deploy iOS App

No special deployment needed - just rebuild:

```bash
# Open Xcode and build the project
# Or use command line:
xcodebuild -project CampusLink.xcodeproj -scheme CampusLink -configuration Release
```

**Changes**:
- OrderService now updates escrow status on order completion
- EscrowService fetches actual status from payments table
- UI displays real-time escrow status

---

## Verification

### 1. Check Database Triggers

```sql
-- Verify triggers exist
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table
FROM information_schema.triggers
WHERE trigger_name IN ('trigger_update_escrow_status', 'trigger_update_escrow_on_payment');
```

Expected: 2 rows

### 2. Check Escrow Status View

```sql
-- Check all escrow statuses
SELECT 
    order_status,
    payment_status,
    escrow_release_status,
    COUNT(*) as count
FROM escrow_status_view
GROUP BY order_status, payment_status, escrow_release_status
ORDER BY order_status;
```

Expected: All completed orders should have `escrow_release_status = 'released'`

### 3. Check for Mismatches

```sql
-- Should return 0 rows
SELECT *
FROM escrow_status_view
WHERE (order_status = 'completed' AND escrow_release_status != 'released')
   OR (order_status IN ('placed', 'seller_confirmed', 'in_progress') 
       AND payment_status = 'succeeded' 
       AND escrow_release_status = 'released');
```

Expected: 0 rows

### 4. Test New Payment Flow

1. Create a new order in the app
2. Complete payment
3. Check database:
   ```sql
   SELECT 
       o.id,
       o.order_status,
       p.escrow_release_status
   FROM orders o
   LEFT JOIN payments p ON p.payment_intent_id = o.stripe_payment_intent_id
   WHERE o.id = 'YOUR_ORDER_ID'
   ORDER BY o.created_at DESC
   LIMIT 1;
   ```
   Expected: `escrow_release_status = 'held'`

4. Confirm delivery in app
5. Check database again:
   Expected: `escrow_release_status = 'released'`

### 5. Check Webhook Logs

In Supabase Dashboard → Edge Functions → stripe-webhook → Logs:

Look for:
- `🔒 Setting escrow_release_status to 'held' for payment pi_...`
- `✅ Escrow status set to 'held' for payment pi_...`

### 6. Check App Logs

In Xcode console when confirming delivery:

Look for:
- `🔵 confirmDelivery: Updating escrow_release_status in payments table`
- `✅ confirmDelivery: Escrow status updated to 'released' in payments table`
- `✅ Fetched escrow_release_status from payments table: released`

---

## Escrow Status Flow

```
┌─────────────────────────────────────────────────┐
│ 1. Payment Intent Created                       │
│    Buyer completes checkout                     │
└─────────────────────┬───────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│ 2. Webhook: payment_intent.succeeded            │
│    payments.escrow_release_status = 'held'      │
│    orders.payment_status = 'succeeded'          │
└─────────────────────┬───────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│ 3. Order In Progress                            │
│    Seller marks delivered                       │
│    escrow_release_status = 'held' (unchanged)   │
└─────────────────────┬───────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│ 4. Buyer Confirms Delivery                      │
│    OrderService.confirmDelivery() called        │
│    orders.order_status = 'completed'            │
│    payments.escrow_release_status = 'released'  │
│    Funds released to seller wallet              │
└─────────────────────┬───────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│ 5. Escrow Protection Card in UI                 │
│    Shows: "Funds Released" (green)              │
│    Status pulled from payments table            │
└─────────────────────────────────────────────────┘
```

---

## Rollback Plan

If you need to rollback:

### 1. Remove Database Triggers

```sql
DROP TRIGGER IF EXISTS trigger_update_escrow_status ON orders;
DROP TRIGGER IF EXISTS trigger_update_escrow_on_payment ON payments;
DROP FUNCTION IF EXISTS update_escrow_status_on_completion();
DROP FUNCTION IF EXISTS update_escrow_status_on_payment();
DROP VIEW IF EXISTS escrow_status_view;
```

### 2. Revert Webhook

```bash
# Redeploy previous version from git
git checkout HEAD~1 -- supabase/functions/stripe-webhook/index.ts
npx supabase functions deploy stripe-webhook
```

### 3. Revert App Code

```bash
# Revert Swift changes
git checkout HEAD~1 -- CampusLink/Core/Services/OrderService.swift
git checkout HEAD~1 -- CampusLink/Core/Services/EscrowService.swift
git checkout HEAD~1 -- CampusLink/Features/Payments/Views/EscrowStatusView.swift

# Rebuild app
```

---

## Troubleshooting

### Issue: Escrow status not updating in webhook

**Check**:
```bash
# View webhook logs
npx supabase functions logs stripe-webhook --tail
```

**Fix**: Redeploy webhook function

### Issue: Escrow status not updating on delivery confirmation

**Check**: App logs in Xcode console

**Fix**: 
1. Check that `stripe_payment_intent_id` exists on the order
2. Verify payments table has a record with that payment_intent_id
3. Check RLS policies on payments table

### Issue: Database triggers not firing

**Check**:
```sql
-- Enable logging
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Check if triggers exist
SELECT * FROM pg_trigger WHERE tgname LIKE 'trigger_update_escrow%';
```

**Fix**: Re-run the trigger creation from FIX_ESCROW_STATUS_TRACKING.sql

---

## Files Modified

**Database**:
- ✅ `FIX_ESCROW_STATUS_TRACKING.sql` (NEW)

**Backend**:
- ✅ `supabase/functions/stripe-webhook/index.ts`

**iOS App**:
- ✅ `CampusLink/Core/Services/OrderService.swift`
- ✅ `CampusLink/Core/Services/EscrowService.swift`
- ✅ `CampusLink/Features/Payments/Views/EscrowStatusView.swift`

**Documentation**:
- ✅ `log.md` (updated)

---

## Success Criteria

After deployment, you should see:

✅ All completed orders have `escrow_release_status = 'released'`  
✅ All active paid orders have `escrow_release_status = 'held'`  
✅ New payments automatically get status 'held'  
✅ Order completion automatically updates status to 'released'  
✅ UI shows accurate escrow status from database  
✅ Database triggers keep everything in sync  

---

## Questions?

Check the detailed implementation in `log.md` for more information about the changes.

