# Offer Payment Fix Summary

## The Problem
You were getting "invalid input syntax for type json" when trying to make an offer with card payment.

## Root Cause
The app was trying to create **orders** for **seek listings**, which doesn't make sense:
- Seek listings are REQUESTS for products/services (intent='seek')
- Orders should only be created for actual product/service listings (intent='offer')
- The database was rejecting the order creation because the listing_id referenced a seek listing

## The Solution
Changed the offer flow to NOT create orders immediately:
1. When user makes an offer → create offer record only
2. When seeker accepts offer → THEN create the order
3. This avoids the JSON error completely

## What Changed
- `handleCardPayment()` - Now just creates offer record, no order
- `handleWalletPayment()` - Same, just creates offer record
- Orders are created later during the acceptance flow

## SQL Scripts to Apply
1. **fix_payments_rls.sql** - Adds missing RLS policies for payments table
2. **fix_order_trigger.sql** - Fixes the trigger that was causing issues (optional)

## The Complete Fix Journey
1. ✅ Fixed RLS policies (payments table INSERT permission)
2. ✅ Fixed UUID type mismatches (OrderInsert, OfferInsert)
3. ✅ Fixed Encodable compilation errors
4. ✅ Fixed auth session hang (added direct user ID methods)
5. ✅ Fixed card payment trying to use Stripe with non-existent listing
6. ✅ **FINAL FIX**: Don't create orders for seek listings!

The offer payment flow should now work completely without any errors!
