# Deploy Offer Payment Edge Function

## Edge Function Created
`create_offer_payment_intent` - Handles Stripe payment intents for offer acceptance

## What It Does
1. Validates the user is the seeker (buyer)
2. Fetches offer details including custom price
3. Creates Stripe payment intent with fees
4. Records payment in database
5. Returns client secret for payment sheet

## Deployment Steps

### 1. Deploy the Edge Function
```bash
cd supabase
npx supabase functions deploy create_offer_payment_intent
```

### 2. Set Environment Variables
In Supabase Dashboard > Edge Functions > create_offer_payment_intent > Settings:

```
STRIPE_SECRET_KEY=sk_live_YOUR_STRIPE_SECRET_KEY
```

### 3. Test the Function
The function is now integrated into the offer acceptance flow:
1. Create a seek post
2. Have someone make an offer
3. Accept the offer with card payment
4. Stripe payment sheet should appear
5. Complete payment
6. Offer marked as accepted, payment in escrow

## Features
- Validates offer ownership
- Calculates Stripe processing fees (2.9% + 30¢)
- Creates payment record for tracking
- Integrates with existing escrow system
- Full error handling

## Security
- Requires authenticated user
- Validates user is the seeker
- Checks offer status is pending
- Cancels payment intent if database insert fails
