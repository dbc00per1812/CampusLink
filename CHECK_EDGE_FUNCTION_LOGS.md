# Check Edge Function Logs for 503 Error

## The Issue
Getting 503 error means the edge function is crashing, not running properly.

## Where to Check

### Supabase Dashboard
1. Go to: https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/functions
2. Click on: **create_payment_intent**
3. Click tab: **Logs**
4. Look for the most recent request (12:09 PM)

### What to Look For

**If the function is crashing, you'll see**:
```
Error: [some error message]
Stack trace...
```

**Common causes**:
- Syntax error in TypeScript
- Accessing undefined variable
- Supabase query failing
- Type mismatch

## My Suspicion

Looking at the code changes, I think the issue might be we're querying the `orders` table but maybe:
1. The column names don't match (buyer_price_cents vs buyerPriceCents)
2. The order isn't being found
3. There's a type casting issue

## Quick Test

Can you check the actual order in the database?

```sql
SELECT 
  id,
  buyer_id,
  seller_id,
  buyer_price_cents,
  seller_price_cents,
  listing_id,
  payment_status
FROM orders
WHERE id = '7440705A-E6A0-4651-A41F-090B71698A5C';
```

This will tell us if:
- Order exists ✅
- Has buyer_price_cents and seller_price_cents columns ✅
- payment_status is 'pending' ✅

## Alternative Approach

If the edge function keeps crashing, we can simplify it by NOT supporting order_id for now and instead just using the listing_id from the order.

What does the **Edge Function Log** actually say?

