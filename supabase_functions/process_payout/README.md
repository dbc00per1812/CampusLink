# Process Payout Edge Function

This edge function handles processing payouts via Stripe Connect API. It creates actual payouts in Stripe that transfer funds to users' bank accounts.

## Deployment Instructions

Since this project doesn't use Docker and deploys edge functions via the Supabase website:

1. **Go to Supabase Dashboard**
   - Navigate to https://supabase.com/dashboard
   - Select your project

2. **Navigate to Edge Functions**
   - Click on "Edge Functions" in the left sidebar
   - Click "New function" button

3. **Create the Function**
   - Name: `process_payout`
   - Copy and paste the contents of `index.ts` into the code editor
   - Click "Deploy"

4. **Set Environment Variables**
   - In the Edge Function settings, add:
   - `STRIPE_SECRET_KEY` = Your Stripe secret key (sk_live_... or sk_test_...)
   - Note: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are automatically available

5. **Verify Deployment**
   - The function should be available at: `https://YOUR_PROJECT_REF.functions.supabase.co/process_payout`
   - Test by requesting a payout from the app

## What This Function Does

1. **Validates Request**
   - Verifies user's JWT token
   - Checks payout record exists and belongs to user
   - Ensures payout is in "pending" status

2. **Gets Stripe Connect Account**
   - Retrieves user's stripe_connect_id from database
   - Verifies account exists and is set up

3. **Creates Stripe Payout**
   - Calls Stripe API to create payout
   - Payout goes to the user's default external account (bank account from onboarding)
   - Amount: net_amount_cents (after fees)

4. **Updates Database**
   - Stores stripe_payout_id for tracking
   - Updates status to "processing"
   - Will be updated to "completed" via webhook when Stripe confirms

## Request Format

```json
{
  "payout_id": "uuid-of-payout-record"
}
```

## Response Format

**Success:**
```json
{
  "success": true,
  "payout_id": "uuid",
  "stripe_payout_id": "po_xxxxx",
  "status": "processing",
  "estimated_arrival": "2025-10-19T00:00:00Z"
}
```

**Error:**
```json
{
  "error": "Error message"
}
```

## Required Environment Variables

- `STRIPE_SECRET_KEY` - Your Stripe secret key (must be added manually)
- `SUPABASE_URL` - Automatically available
- `SUPABASE_SERVICE_ROLE_KEY` - Automatically available

## Database Requirements

### Payouts Table Columns Needed:
- `id` (UUID)
- `user_id` (UUID)
- `amount_cents` (INT)
- `net_amount_cents` (INT)
- `status` (TEXT) - "pending", "processing", "completed", "failed"
- `stripe_payout_id` (TEXT) - to store Stripe payout ID
- `updated_at` (TIMESTAMP)

### Users Table Columns Needed:
- `id` (UUID)
- `stripe_connect_id` (TEXT) - Connect account ID from onboarding

## Important Notes

### Automatic vs Manual Triggering
Currently, this function must be called manually after a payout record is created. You have two options:

**Option 1: Manual Processing (Current)**
- User requests payout → record created in database
- Call this Edge Function to actually process it with Stripe

**Option 2: Automatic Processing (Recommended)**
- Set up a database trigger or scheduled function
- Automatically process pending payouts every hour
- See "AUTO_PROCESS_PAYOUTS.md" for implementation

### Stripe Payout Timing
- Standard payouts: 2-3 business days to arrive
- The `arrival_date` from Stripe indicates when funds will reach the bank
- Status updates will come via Stripe webhooks (see SETUP_PAYOUT_WEBHOOKS.md)

### Testing
**Test Mode:**
- Use `sk_test_...` key
- Stripe won't actually send money
- Test with Stripe Connect test accounts

**Live Mode:**
- Use `sk_live_...` key  
- Real money will be transferred
- Ensure Stripe Connect accounts are fully verified

## Error Handling

Common errors:
- "Payout not found or unauthorized" - User doesn't own this payout
- "Payout is already processing/completed" - Can't reprocess
- "Stripe Connect account not found" - User hasn't completed onboarding
- "Insufficient funds" - Connect account balance too low (shouldn't happen with our wallet system)

## Security

- ✅ JWT token validation
- ✅ User ownership verification
- ✅ Stripe Connect account scoping (payouts only affect the specific Connect account)
- ✅ Service role key for database operations
- ✅ CORS headers for web access

## Next Steps

After deploying this function:

1. **Update Swift App** - Call this function after creating payout records
2. **Set Up Webhooks** - Handle Stripe payout status updates (paid, failed, etc.)
3. **Add Automation** - Auto-process pending payouts on a schedule
4. **Add Monitoring** - Track failed payouts and alert users

## Troubleshooting

**Error: "No authorization header"**
- App is not sending JWT token
- Check AuthManager is providing valid session

**Error: "Stripe Connect account not found"**
- User hasn't completed onboarding
- Verify stripe_connect_id is in users table

**Error: "Insufficient funds in Stripe account"**
- This is a Stripe balance issue
- Check that escrow releases are working properly
- Verify wallet balance matches Stripe Connect balance

**Payout stuck in "processing"**
- Wait for Stripe webhook to update status
- Check Stripe Dashboard for payout status
- May take 2-3 days for standard payouts

