# Deploy Stripe Webhook Handler

## 🚨 Urgent - Stripe Will Disable Webhook by October 24, 2025

Stripe has been trying to send webhook events to your endpoint for 4 days (101 failed attempts) and will disable it by **October 24, 2025 at 10:33:37 PM UTC** if not fixed.

## What This Fixes

**Current Problem**:
- ❌ Payouts work but status never updates from "processing" → "completed"
- ❌ Users can't see when their money has actually been transferred
- ❌ Failed payouts are invisible
- ❌ Support burden increases dramatically

**After Deployment**:
- ✅ Automatic status updates when payouts complete
- ✅ Users see accurate payout status
- ✅ Failed payouts are visible
- ✅ Accurate database state
- ✅ Better user experience

---

## Quick Deployment (15 minutes)

### Step 1: Deploy Edge Function to Supabase (7 minutes)

1. **Go to Supabase Dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select your project: **CampusLink**
   - Your project ID: `vnmzijluyctlufnzxast`

2. **Navigate to Edge Functions**
   - Click "Edge Functions" in the left sidebar
   - Click "New function" button

3. **Create the Function**
   - **Name**: `stripe-webhook` (must be exactly this)
   - Copy the entire contents of:
     ```
     /Users/eileenmurphy/CampusLink/supabase/functions/stripe-webhook/index.ts
     ```
   - Paste into the code editor
   - Click "Deploy"

4. **Set Environment Variables**
   - In the Edge Function settings, click "Secrets"
   - Add two environment variables:

   **Variable 1:**
   - Key: `STRIPE_SECRET_KEY`
   - Value: Your Stripe secret key
     - For **test mode**: Use `sk_test_...`
     - For **production**: Use `sk_live_...`
   - Click "Add secret"

   **Variable 2:**
   - Key: `STRIPE_WEBHOOK_SECRET`
   - Value: Leave blank for now (we'll get this in Step 2)
   - Click "Add secret"

5. **Verify Deployment**
   - Function should be live at:
     ```
     https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook
     ```

---

### Step 2: Configure Webhook in Stripe Dashboard (5 minutes)

1. **Go to Stripe Dashboard**
   - Live mode: https://dashboard.stripe.com/webhooks
   - Test mode: https://dashboard.stripe.com/test/webhooks

2. **Update Existing Webhook** (it already exists!)
   - Find the webhook with URL: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
   - Click on it
   - You should see ~101 failed attempts
   - Click "Edit endpoint"

3. **Verify Events Are Selected**
   - Ensure these events are checked:
     - ✅ `payout.paid`
     - ✅ `payout.failed`
     - ✅ `payout.canceled`
   - If not, add them
   - Click "Update endpoint"

4. **Get Webhook Signing Secret**
   - On the webhook details page, look for "Signing secret"
   - Click "Reveal" or "Show"
   - Copy the secret (starts with `whsec_...`)
   - **Important**: Keep this secret safe!

---

### Step 3: Add Webhook Secret to Supabase (2 minutes)

1. **Go back to Supabase Dashboard**
   - Navigate to: Edge Functions → `stripe-webhook`
   - Click "Secrets" or "Environment Variables"

2. **Update STRIPE_WEBHOOK_SECRET**
   - Find the `STRIPE_WEBHOOK_SECRET` variable
   - Click "Edit"
   - Paste the webhook signing secret from Stripe (whsec_...)
   - Click "Save"

3. **Redeploy Function** (if needed)
   - Some platforms require redeploying after env var changes
   - If prompted, click "Redeploy"

---

### Step 4: Test the Webhook (3 minutes)

#### Option A: Use Stripe Dashboard (Easiest)

1. **Go to Stripe Dashboard**
   - Navigate to: Webhooks
   - Click on your webhook endpoint

2. **Send Test Event**
   - Click "Send test webhook" button
   - Select event type: `payout.paid`
   - Click "Send test webhook"

3. **Check Response**
   - Should see: `✅ 200 - Success`
   - If you see `404` - function not deployed correctly
   - If you see `400` - signature verification issue
   - If you see `500` - check function logs

4. **Check Supabase Logs**
   - Go to: Edge Functions → `stripe-webhook` → Logs
   - Should see: `✅ Webhook signature verified for event: payout.paid`

#### Option B: Use Stripe CLI (Advanced)

```bash
# Install Stripe CLI if not installed
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to your endpoint
stripe listen --forward-to https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook

# In another terminal, trigger test events
stripe trigger payout.paid
stripe trigger payout.failed
stripe trigger payout.canceled
```

#### Verify in Database

After sending test events, check your database:

```sql
-- Check recent payouts and their statuses
SELECT 
  id, 
  status, 
  stripe_payout_id, 
  created_at, 
  completed_at
FROM payouts 
ORDER BY created_at DESC 
LIMIT 10;
```

Expected results:
- Payouts with `completed_at` timestamp should have `status = 'completed'`
- Failed/canceled payouts should have appropriate status

---

## Verification Checklist

- [ ] Edge function deployed to Supabase
- [ ] `STRIPE_SECRET_KEY` environment variable set
- [ ] `STRIPE_WEBHOOK_SECRET` environment variable set
- [ ] Webhook configured in Stripe Dashboard
- [ ] Webhook URL: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
- [ ] Events selected: `payout.paid`, `payout.failed`, `payout.canceled`
- [ ] Test webhook sent from Stripe Dashboard
- [ ] Response code: 200 (success)
- [ ] Function logs show webhook received
- [ ] Database updates verified (if test data available)

---

## Troubleshooting

### Issue: Still Getting 404 Errors

**Possible Causes**:
1. Function not deployed yet
2. Function name is wrong (must be `stripe-webhook`)
3. Wrong Supabase project URL

**Solutions**:
1. Verify function exists in Supabase Dashboard
2. Check function URL matches exactly: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
3. Try redeploying the function

### Issue: Getting 400 Errors (Invalid Signature)

**Possible Causes**:
1. `STRIPE_WEBHOOK_SECRET` not set
2. Wrong webhook signing secret
3. Using test mode secret in live mode (or vice versa)

**Solutions**:
1. Verify `STRIPE_WEBHOOK_SECRET` environment variable is set
2. Get the correct signing secret from Stripe Dashboard
3. Make sure test/live modes match between Stripe and Supabase

### Issue: Getting 500 Errors (Server Error)

**Possible Causes**:
1. Database connection issue
2. Missing Supabase environment variables
3. Invalid database query

**Solutions**:
1. Check Supabase function logs for detailed error
2. Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-provided
3. Check database schema has `stripe_payout_id` column

### Issue: Webhook Receives 200 But Database Not Updated

**Possible Causes**:
1. No matching payout found in database
2. `stripe_payout_id` doesn't match
3. RLS policies blocking update (shouldn't happen with service role key)

**Solutions**:
1. Check function logs for warnings like "Payout not found"
2. Verify payout exists in database with correct `stripe_payout_id`
3. Run this query:
   ```sql
   SELECT id, stripe_payout_id, status 
   FROM payouts 
   WHERE stripe_payout_id = 'po_xxxxx';  -- Replace with actual ID
   ```

---

## Monitoring

### Check Webhook Status in Stripe

1. Go to: https://dashboard.stripe.com/webhooks
2. Click on your webhook endpoint
3. View recent deliveries:
   - ✅ Green checkmark = Success (200 response)
   - ❌ Red X = Failed
   - Click on any delivery to see details

### Check Function Logs in Supabase

1. Go to: Supabase Dashboard → Edge Functions → `stripe-webhook`
2. Click "Logs"
3. Look for:
   - `✅ Webhook signature verified` - Good!
   - `💰 Payout completed` - Payout.paid event processed
   - `❌ Payout failed` - Payout.failed event processed
   - `🚫 Payout canceled` - Payout.canceled event processed
   - Any errors or warnings

### Database Monitoring

Run this query periodically to check payout statuses:

```sql
-- Payouts that should have completed by now
SELECT 
  id,
  status,
  stripe_payout_id,
  created_at,
  (NOW() - created_at) as age
FROM payouts 
WHERE status = 'processing' 
AND created_at < NOW() - INTERVAL '5 days'
ORDER BY created_at DESC;
```

If payouts are stuck in "processing" for > 5 days, something might be wrong with webhooks.

---

## What Happens Next

### Automatic Status Updates

Once deployed, the webhook will automatically:

1. **When a payout completes** (`payout.paid`):
   - Update `status` to `'completed'`
   - Set `completed_at` timestamp
   - Users see money has arrived

2. **When a payout fails** (`payout.failed`):
   - Update `status` to `'failed'`
   - Users see payout failed
   - ⚠️ Note: Wallet balance is NOT automatically refunded (manual intervention needed)

3. **When a payout is canceled** (`payout.canceled`):
   - Update `status` to `'canceled'`
   - ⚠️ Note: Wallet balance is NOT automatically refunded (manual intervention needed)

### Timeline

- **Immediate**: Webhook starts receiving events
- **0-5 seconds**: Status updates appear in database
- **0-10 seconds**: Users see updated status in app (on refresh)
- **2-3 business days**: Typical time for standard payouts to complete

---

## Future Enhancements

After this is working, consider adding:

1. **Automatic Wallet Refunds**
   - When payout fails/cancels, automatically refund wallet balance
   - Requires additional logic in webhook handler

2. **Email Notifications**
   - Send email when payout completes
   - Send email if payout fails

3. **Push Notifications**
   - Notify users when money arrives
   - Alert on failed payouts

4. **Audit Trail**
   - Create `webhook_events` table to log all events
   - Useful for debugging and compliance

5. **Retry Logic**
   - If database update fails, retry automatically
   - Store failed events for manual processing

---

## Important Notes

### Test Mode vs Live Mode

- **Test Mode**: Use test Stripe keys and test webhook signing secret
  - Webhook URL stays the same
  - Just change environment variables

- **Live Mode**: Use live Stripe keys and live webhook signing secret
  - Webhook URL stays the same
  - Just change environment variables
  - **Important**: Configure separate webhook in Stripe live mode

### Security

- ✅ Webhook signature verification prevents unauthorized requests
- ✅ Signing secret must be kept secure (like a password)
- ✅ Supabase service role key bypasses RLS for updates
- ✅ No user authentication needed (Stripe is the authenticated party)

### Reliability

- Stripe will retry failed webhooks automatically (up to 3 days)
- If webhook fails, you can manually replay events from Stripe Dashboard
- Database updates are atomic (either succeed or fail, never partial)

---

## Support

If you encounter issues:

1. **Check function logs** in Supabase Dashboard
2. **Check webhook delivery** in Stripe Dashboard
3. **Verify environment variables** are set correctly
4. **Test with Stripe's test webhook sender**
5. **Check database** for payout records with `stripe_payout_id`

---

## Summary

**What you're deploying**:
- A webhook endpoint that receives Stripe events
- Automatically updates payout statuses in your database
- Fixes the issue where payouts stay "processing" forever

**Why it's important**:
- Users need to see when their money arrives
- Failed payouts need to be visible
- Reduces support burden
- Accurate database state

**How long it takes**:
- 15 minutes to deploy and configure
- 2 minutes to test
- Works automatically after that

**When to deploy**:
- **Urgently!** Stripe will disable the webhook by October 24, 2025
- Deploy to test mode first
- Then deploy to production

---

Good luck, Darragh! This will fix the webhook 404 errors and make your payout system fully functional. 🚀


