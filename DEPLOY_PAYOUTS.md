# Deploy Payout System - Critical Fix

## Overview
This deployment fixes the **critical issue** where payout requests were being created in the database but never actually processed with Stripe. Money was not being transferred to users' bank accounts.

## What Was Broken
1. ❌ Users could request payouts
2. ❌ Records created in database
3. ❌ Wallet balance reduced
4. ❌ **No Stripe API call was ever made**
5. ❌ Payouts stuck in "pending" forever
6. ❌ No money actually transferred

## What This Fixes
1. ✅ Edge Function calls Stripe API to create actual payouts
2. ✅ Payouts transfer real money to bank accounts
3. ✅ Status tracking (pending → processing → completed)
4. ✅ Stripe payout ID stored for tracking
5. ✅ Disabled broken instant/debit card payouts (not implemented)
6. ✅ Only bank account payouts enabled (working)

---

## Deployment Steps

### Step 1: Update Database Schema (5 minutes)

1. **Go to Supabase SQL Editor**
   - https://supabase.com/dashboard/project/YOUR_PROJECT/sql

2. **Run the migration**
   - Copy contents of `add_payout_tracking.sql`
   - Paste and execute
   - Verify "stripe_payout_id" column added

3. **Verify**
   ```sql
   SELECT column_name FROM information_schema.columns 
   WHERE table_name = 'payouts' AND column_name = 'stripe_payout_id';
   ```

---

### Step 2: Deploy Edge Function (10 minutes)

1. **Go to Supabase Edge Functions**
   - https://supabase.com/dashboard/project/YOUR_PROJECT/functions

2. **Create New Function**
   - Click "New Function"
   - Name: `process_payout`

3. **Copy Function Code**
   - Open: `supabase_functions/process_payout/index.ts`
   - Copy entire contents
   - Paste into Supabase code editor

4. **Deploy Function**
   - Click "Deploy"
   - Wait for confirmation

5. **Set Environment Variable**
   - In function settings, add:
   - Key: `STRIPE_SECRET_KEY`
   - Value: Your Stripe secret key
     - Test mode: `sk_test_...`
     - Live mode: `sk_live_...`
   - Save

---

### Step 3: Test Payout Flow (15 minutes)

#### Test with Test Mode First!

1. **Use Test Stripe Key**
   - Ensure `STRIPE_SECRET_KEY` is set to `sk_test_...`
   - Ensure app is using `pk_test_...` in Secrets.swift

2. **Complete Stripe Connect Onboarding (Test)**
   - In app, go to Wallet
   - Click "Complete Payout Setup"
   - Use Stripe Connect test account:
     - Account number: `000123456789`
     - Routing number: `110000000`
   - Complete onboarding

3. **Generate Test Balance**
   - Make a test purchase
   - Mark as delivered
   - Funds should appear in seller's wallet

4. **Request Payout**
   - Go to Wallet
   - Click "Request Payout"
   - Enter amount
   - Select "Standard (2-3 days)" (only option now)
   - Select "Bank Account" (only option now)
   - Tap "Request Payout"

5. **Verify Success**
   - Check console logs for: "✅ Payout processing initiated"
   - Go to Stripe Dashboard → Connect → Payouts
   - Should see payout listed

6. **Check Database**
   ```sql
   SELECT id, status, stripe_payout_id, amount_cents 
   FROM payouts 
   ORDER BY created_at DESC 
   LIMIT 5;
   ```
   - Status should be "processing"
   - stripe_payout_id should be set (po_xxxxx)

---

### Step 4: Set Up Webhooks (20 minutes)

Webhooks update payout status from "processing" → "completed" when Stripe confirms.

1. **Go to Stripe Dashboard**
   - https://dashboard.stripe.com/webhooks

2. **Add Endpoint**
   - Click "Add endpoint"
   - URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/stripe-webhook`
   - Select events:
     - `payout.paid`
     - `payout.failed`
     - `payout.canceled`

3. **Get Signing Secret**
   - Copy the webhook signing secret (whsec_...)
   - Save for next step

4. **Update/Create Webhook Handler**
   - See `SETUP_PAYOUT_WEBHOOKS.md` for full implementation
   - Need to add payout event handling to existing stripe-webhook function

---

### Step 5: Production Checklist

Before going live with real money:

- [ ] Database migration applied
- [ ] Edge Function deployed
- [ ] Environment variable set with **LIVE** key (`sk_live_...`)
- [ ] App updated with **LIVE** publishable key (`pk_live_...`)
- [ ] Tested in test mode successfully
- [ ] Webhooks configured
- [ ] Stripe account activated (not in test mode)
- [ ] All users must complete Stripe Connect with LIVE accounts
- [ ] Monitoring set up for failed payouts

---

## Important Notes

### Standard Payouts Only
- ✅ Bank account payouts: **WORKING**
- ❌ Instant/debit card payouts: **DISABLED**
  - No debit card collection mechanism
  - Can be implemented later if needed

### Payout Timing
- **Standard payouts**: 2-3 business days
- Status flow: `pending` → `processing` → `completed`
- Arrival date provided by Stripe

### Fees
- Standard payouts: **FREE** (no Stripe fees)
- All payouts go to bank account collected during onboarding

### Error Handling
If Edge Function fails:
- Payout record exists but not processed
- Wallet balance already reduced
- User sees error message
- **Action**: Manual intervention needed - contact support

### Monitoring
Check for stuck payouts:
```sql
-- Payouts in pending for > 5 minutes (should be processing)
SELECT * FROM payouts 
WHERE status = 'pending' 
AND created_at < NOW() - INTERVAL '5 minutes';

-- Payouts in processing for > 7 days (may be failed)
SELECT * FROM payouts 
WHERE status = 'processing' 
AND created_at < NOW() - INTERVAL '7 days';
```

---

## Rollback Plan

If something goes wrong:

1. **Disable Payouts in App**
   - Comment out payout button in WalletView
   - Redeploy app

2. **Restore Wallet Balances**
   ```sql
   -- For each stuck payout, restore balance
   UPDATE wallets 
   SET available_cents = available_cents + (
     SELECT amount_cents FROM payouts WHERE id = 'PAYOUT_ID'
   )
   WHERE user_id = 'USER_ID';
   
   -- Mark payout as failed
   UPDATE payouts 
   SET status = 'failed' 
   WHERE id = 'PAYOUT_ID';
   ```

---

## Next Steps After Deployment

1. **Monitor First Payouts**
   - Watch console logs
   - Check Stripe Dashboard
   - Verify status updates from webhooks

2. **User Communication**
   - Inform users payouts take 2-3 business days
   - Set expectations on timing

3. **Add Instant Payouts** (Future)
   - Implement debit card collection
   - Enable instant payout option
   - See `IMPLEMENT_INSTANT_PAYOUTS.md`

4. **Automate Stuck Payout Handling**
   - Create admin dashboard
   - Automated alerts for failed payouts
   - Self-service retry mechanism

---

## Testing Checklist

Test these scenarios before going live:

- [ ] Request payout with sufficient balance → SUCCESS
- [ ] Request payout with insufficient balance → ERROR
- [ ] Request payout without Stripe Connect → ERROR  
- [ ] Request payout < $0.50 → ERROR (minimum amount)
- [ ] Request payout > available balance → ERROR
- [ ] Check payout status updates via webhook
- [ ] Verify payout appears in Stripe Dashboard
- [ ] Confirm wallet balance reduced correctly
- [ ] Test with multiple users simultaneously

---

## Support & Troubleshooting

**Issue: "Failed to initiate payout with Stripe"**
- Check Edge Function logs in Supabase
- Verify STRIPE_SECRET_KEY is set correctly
- Check user has stripe_connect_id in database

**Issue: Payout stuck in "pending"**
- Edge Function didn't run or failed
- Check function logs
- May need manual processing

**Issue: Payout stuck in "processing"**
- Waiting for Stripe to complete
- Takes 2-3 business days
- Check Stripe Dashboard for actual status
- Webhook may not have fired

**Issue: "Stripe Connect account not found"**
- User hasn't completed onboarding
- stripe_connect_id not in database
- User needs to complete payout setup first

---

## Files Modified/Created

### Created:
- `supabase_functions/process_payout/index.ts` - Edge Function to process payouts
- `supabase_functions/process_payout/README.md` - Detailed documentation
- `add_payout_tracking.sql` - Database migration
- `DEPLOY_PAYOUTS.md` - This file

### Modified:
- `CampusLink/Core/Services/PayoutService.swift` - Now calls Edge Function
- `CampusLink/Features/Payments/Views/PayoutRequestView.swift` - Disabled instant/debit card options
- `log.md` - Documented all changes

---

Darragh, this is a **critical fix** that makes payouts actually work. Deploy carefully and test thoroughly! 🚀

