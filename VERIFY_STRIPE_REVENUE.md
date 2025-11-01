# Verify Your Platform Revenue in Stripe

## 🎯 Quick Check (30 seconds)

### Option 1: Payments Page (Recommended)

1. **Go to**: https://dashboard.stripe.com/test/payments
2. **Find** the $103.00 payment (most recent)
3. **Click on it**
4. **Scroll down** to "Transfers and payouts"
5. **You should see**:
   ```
   Application fee: $X.XX  ← YOUR MONEY! 🎉
   Transfer to acct_xxx: $XX.XX  ← Seller's money
   ```

### Option 2: Application Fees Page

1. **Go to**: https://dashboard.stripe.com/test/connect/application_fees
2. **See all** application fees you've collected
3. **Each row** is money that went to YOUR platform account

---

## 📊 Detailed Verification

### Step 1: Find the Payment Intent

**URL**: https://dashboard.stripe.com/test/payments

Look for:
- **Amount**: $103.00 (or whatever the buyer paid)
- **Status**: Succeeded
- **Created**: Just now (today's date)

### Step 2: Click Into Payment Details

You'll see a page with these sections:

#### A. Timeline
Shows when payment was created, confirmed, and captured

#### B. Payment Summary
```
Amount: $103.00
Stripe processing fee: -$3.29
Application fee: -$X.XX  ← YOUR CUT! 💰
Net: $XX.XX (goes to connected account)
```

#### C. Metadata
Should show:
- `campuslink_cut_cents`: Your markup in cents
- `seller_price_cents`: Seller's original price
- `buyer_price_cents`: What buyer paid
- `quantity`: Number of units

#### D. Transfers
Shows the transfer to the seller's connected account

### Step 3: Check Your Balance

**URL**: https://dashboard.stripe.com/test/balance

You should see:
- **Available balance**: Includes your application fees
- **Pending balance**: Upcoming deposits

---

## 💰 Understanding the Money Flow

### Example: $100 Item

1. **Seller lists**: $100.00
2. **Stripe fee**: $3.20 (2.9% + $0.30)
3. **Subtotal**: $103.20
4. **Rounded up**: $104.00 (what buyer pays)
5. **Your cut**: $0.80 (the markup)

### In Stripe Dashboard:

```
Payment Intent: $104.00
├─ Stripe takes: $3.32 (from the $104)
├─ You keep: $0.80 (application fee)
└─ Seller gets: ~$99.88
```

**Note**: Stripe's fee is calculated on the TOTAL buyer payment ($104), not the seller's price.

---

## 🔍 How to Calculate Your Actual Revenue

### Formula:
```
Your Revenue = Application Fee - (Your Stripe Fees on the Fee)
```

Since Stripe takes 2.9% + $0.30 on the ENTIRE payment, they also take a cut from your application fee.

### Real Example:
- Buyer pays: $104.00
- Stripe fee on $104: $3.32
- Your app fee: $0.80
- **Net to you**: ~$0.78 (after Stripe's cut of your fee)
- Net to seller: ~$99.88

---

## 📈 Viewing Revenue Reports

### Daily Revenue
**URL**: https://dashboard.stripe.com/test/connect/application_fees

Filter by:
- Date range
- Status (paid, pending)
- Amount

### Monthly Reports
1. Go to: https://dashboard.stripe.com/test/reports
2. Select: "Application fees"
3. Choose: Date range
4. Export: CSV for accounting

---

## 🧪 Test Mode vs Live Mode

**Important**: Right now you're in **TEST MODE**!

Toggle in top-right of Stripe Dashboard:
- **Test mode**: Play money (what you're using now)
- **Live mode**: Real money (for production)

All the URLs above have `/test/` in them - that's test mode.

For **live mode**, remove `/test/`:
- Test: `dashboard.stripe.com/test/payments`
- Live: `dashboard.stripe.com/payments`

---

## 🎯 What to Look For (Checklist)

After a successful purchase:

✅ **Payment appears** in Payments list
✅ **Status is "Succeeded"**
✅ **Amount matches** what buyer paid ($103 for the white dog)
✅ **Application fee is present** (your markup)
✅ **Transfer to connected account** (seller's portion)
✅ **Metadata contains** pricing breakdown
✅ **Your balance increased** by the application fee

---

## 🚨 Troubleshooting

### Issue: No Application Fee Showing

**Possible causes**:
1. Old edge function deployed (without application_fee_amount)
2. Seller doesn't have Stripe Connect account
3. Payment failed/was refunded

**Check**:
```sql
-- In Supabase SQL Editor
SELECT 
    id,
    payment_status,
    marketplace_fee_cents,
    stripe_payment_intent_id
FROM orders
ORDER BY created_at DESC
LIMIT 5;
```

### Issue: Application Fee is $0

**Cause**: No markup (seller price + fees already rounded to whole dollar)

**Example**:
- Seller: $20.00
- Stripe fee: $0.88
- Subtotal: $20.88
- Rounded: $21.00
- Your cut: $0.12 ✅

If subtotal was exactly $21.00, your cut would be $0.

### Issue: Can't Find Connected Account Transfer

**Cause**: Payment not captured yet (still held in escrow)

**Check**: Look for "Capture" button on payment - you're using manual capture.

---

## 💡 Pro Tips

### 1. Set Up Webhooks
Get notified when application fees are collected:
```
application_fee.created
application_fee.refunded
```

### 2. Automate Accounting
Export application fees daily:
```bash
stripe application_fees list --limit 100 --created gt=$(date -u -d '1 day ago' +%s)
```

### 3. Track Seller Payouts
Monitor when sellers receive their money:
```bash
stripe transfers list --destination <seller_account_id>
```

### 4. Reconciliation
Compare your Supabase orders with Stripe application fees:
- Supabase: `marketplace_fee_cents` column
- Stripe: Application fee amount
- They should match!

---

## 🎉 Success!

If you see application fees in your Stripe Dashboard, **you're making money!** 💰

Every rounded-up dollar goes straight to your platform account automatically.

**Next Steps**:
1. Test a few more purchases
2. Verify fees are collecting
3. When ready, switch to Live Mode
4. Start making real revenue! 🚀

---

## 📞 Need Help?

**Stripe Support**:
- Dashboard: Click "?" icon in top right
- Email: support@stripe.com
- Docs: https://stripe.com/docs/connect/application-fees

**Common Questions**:
- "When do I get paid?" - Stripe pays out to your bank account (configurable, default is 2 days)
- "What about refunds?" - Application fees are automatically refunded too
- "What's the minimum fee?" - No minimum! Even $0.01 works

---

**Last Updated**: Ready to verify your revenue!


