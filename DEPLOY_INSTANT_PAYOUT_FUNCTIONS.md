# Deploy Instant Payout Edge Functions

## Quick Deploy Commands

You need to deploy **2 Edge Functions** for instant payouts to work.

### 1. Deploy add-debit-card Function

```bash
cd /Users/eileenmurphy/CampusLink
supabase functions deploy add-debit-card
```

### 2. Deploy get-debit-cards Function

```bash
supabase functions deploy get-debit-cards
```

## Verify Deployment

After deploying, you should see both functions in your Supabase Dashboard:
- Go to: https://supabase.com/dashboard/project/YOUR_PROJECT/functions
- Look for:
  - ✅ `add-debit-card`
  - ✅ `get-debit-cards`
  - ✅ `process-payout` (already deployed)

## Environment Variables

Both functions use these environment variables (already set in Supabase):
- `STRIPE_SECRET_KEY` - Your Stripe secret key
- `SUPABASE_URL` - Auto-provided
- `SUPABASE_SERVICE_ROLE_KEY` - Auto-provided

## Test After Deployment

1. Rebuild your iOS app
2. Go to Wallet → Request Payout
3. Try to "Enable Instant Payouts"
4. Add a debit card
5. Should work without 404 error!

## What These Functions Do

### add-debit-card
- Takes a Stripe payment token from the iOS app
- Adds it as an external account to the user's Stripe Connect account
- Verifies it's actually a debit card (rejects credit cards)
- Checks if it supports instant payouts
- Updates `users.has_debit_card = true`

### get-debit-cards
- Retrieves all debit cards saved for the user from Stripe
- Returns card details (last4, brand, instant availability)
- Used to check if user has any debit cards on file

