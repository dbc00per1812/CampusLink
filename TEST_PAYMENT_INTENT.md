# Testing create_payment_intent Edge Function

## Prerequisites

Before testing, you need:
1. ✅ Edge function deployed to Supabase
2. ✅ A test listing in your database
3. ✅ A test user account (not the listing owner)
4. ✅ Your Supabase credentials

---

## Method 1: Supabase Dashboard (Easiest) ⭐

1. Go to **Supabase Dashboard** → **Edge Functions** → `create_payment_intent`
2. Click the **"Test"** or **"Invoke"** tab
3. Add your auth token in **Headers**:
   ```
   Authorization: Bearer YOUR_JWT_TOKEN
   ```
4. Use this **Request Body**:
   ```json
   {
     "listing_id": "your-listing-uuid-here",
     "quantity": 2
   }
   ```
5. Click **"Invoke Function"**
6. Check the response for pricing breakdown!

---

## Method 2: Using the Test Script

### Step 1: Get Your Credentials

Find these in Supabase Dashboard → Settings → API:
- **Project URL**: `https://xxxxx.supabase.co`
- **Anon Key**: `eyJhbG...` (long string)

### Step 2: Get a User Auth Token

**Option A - From Browser Console (if logged in to your app):**
```javascript
// In browser console while logged into your app
console.log(localStorage.getItem('supabase.auth.token'))
```

**Option B - Using Supabase CLI:**
```bash
supabase auth users list
# Copy a user's access token
```

**Option C - Quick test login:**
```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/auth/v1/token?grant_type=password' \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "your-password"
  }' | jq -r '.access_token'
```

### Step 3: Update the Test Script

Edit `test_payment_intent.sh` and replace:
```bash
SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
SUPABASE_ANON_KEY="your-anon-key-here"
USER_AUTH_TOKEN="your-jwt-token-here"
```

### Step 4: Run the Test

```bash
chmod +x test_payment_intent.sh
./test_payment_intent.sh LISTING_UUID 2
```

**Example:**
```bash
./test_payment_intent.sh 123e4567-e89b-12d3-a456-426614174000 3
```

**Expected Output:**
```
🧪 Testing create_payment_intent Edge Function

📋 Test Parameters:
   Listing ID: 123e4567-e89b-12d3-a456-426614174000
   Quantity: 3

📡 Sending request...

HTTP Status: 200

✅ Success!

Response:
{
  "client_secret": "pi_xxx_secret_xxx",
  "seller_price_cents": 7500,
  "buyer_price_cents": 7700,
  "stripe_fee_cents": 248,
  "campuslink_cut_cents": 48,
  "quantity": 3,
  "price_per_unit": 2500
}

💰 Pricing Breakdown:
   Seller receives: $75.00
   Buyer pays: $77.00
   Stripe fee: $2.48
   🎯 CampusLink cut: $0.48
```

---

## Method 3: Quick curl Command

Get a listing UUID from your database, then:

```bash
curl -X POST \
  'https://YOUR_PROJECT.supabase.co/functions/v1/create_payment_intent' \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "listing_id": "YOUR_LISTING_UUID",
    "quantity": 2
  }'
```

---

## Method 4: Test from iOS App (Real World)

Just use your app normally! The payment flow will call this function.

**Debug logs to watch:**
```swift
// In PaymentService.swift
print("💰 Payment Intent Response:", response)
```

**Stripe Dashboard:**
Go to **Stripe Dashboard** → **Payments** → Check for:
- ✅ Payment Intent created
- ✅ Application fee amount showing your cut
- ✅ Connected account (seller) listed

---

## Common Test Scenarios

### Test 1: Single Unit Purchase
```json
{
  "listing_id": "your-uuid",
  "quantity": 1
}
```
Expected: Basic pricing, small platform cut

### Test 2: Multi-Unit Purchase
```json
{
  "listing_id": "your-uuid",
  "quantity": 5
}
```
Expected: Price × 5, larger platform cut

### Test 3: Quantity Not Available
```json
{
  "listing_id": "your-uuid",
  "quantity": 999
}
```
Expected: Error "Insufficient quantity"

### Test 4: Invalid Listing
```json
{
  "listing_id": "00000000-0000-0000-0000-000000000000",
  "quantity": 1
}
```
Expected: Error "Listing not found"

---

## Verifying Results

### ✅ Check Database
```sql
-- See if payment record was created
SELECT * FROM payments 
WHERE listing_id = 'YOUR_LISTING_UUID'
ORDER BY created_at DESC 
LIMIT 1;
```

### ✅ Check Stripe Dashboard
1. Go to **Stripe Dashboard** → **Payments**
2. Look for payment intent with metadata:
   - `campuslink_cut_cents`
   - `quantity`
   - `listing_id`
3. Check **Application Fees** tab to see your platform earnings

### ✅ Check Edge Function Logs
**Supabase Dashboard** → **Edge Functions** → `create_payment_intent` → **Logs**

Look for:
```
💰 Pricing breakdown: {
  quantity: 2,
  sellerPriceCents: 5000,
  stripeFeeCents: 175,
  buyerPriceCents: 5200,
  campusLinkCutCents: 25
}
```

---

## Troubleshooting

### Error: "Unauthorized"
- ❌ Auth token is missing or expired
- ✅ Get fresh token by logging in again

### Error: "Listing not found"
- ❌ UUID is wrong or listing doesn't exist
- ✅ Query database: `SELECT id FROM listings LIMIT 5;`

### Error: "Seller cannot purchase their own listings"
- ❌ You're using the listing owner's token
- ✅ Use a different test user's token

### Error: "Seller does not have Stripe Connect account"
- ❌ Seller hasn't completed Stripe onboarding
- ✅ Complete onboarding flow in app or use different listing

### No application fee in Stripe
- ❌ Old edge function version deployed
- ✅ Verify `application_fee_amount` is in the code
- ✅ Redeploy the function

---

## Quick Start (TL;DR)

```bash
# 1. Get a listing UUID
psql -h YOUR_DB_HOST -d postgres -c "SELECT id, title, price FROM listings LIMIT 5;"

# 2. Get auth token from your logged-in app
# (Browser console: localStorage.getItem('supabase.auth.token'))

# 3. Test!
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/create_payment_intent' \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"listing_id": "YOUR_UUID", "quantity": 2}'
```

That's it! 🎉

