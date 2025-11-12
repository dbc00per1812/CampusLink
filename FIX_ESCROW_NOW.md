# Fix Escrow Mode - Quick Action Guide

**Issue**: Insufficient funds error when requesting payout  
**Cause**: Money in platform account, not seller's Connect account  
**Time to fix**: 5-10 minutes

---

## 🎯 Quick Fix (Right Now)

### Step 1: Check Where the Money Is (2 min)

**Go to Stripe Dashboard:**
1. https://dashboard.stripe.com/test/balance (use `/balance` for live mode)
2. Look at "Available balance" 
3. **Do you see $4.25 (or $5.00)?** → Money is stuck in platform account ✅

**Then check Connect account:**
1. Dashboard → Connect → Accounts
2. Click on your Connect account (should be `acct_...`)
3. Look at "Balance" tab
4. **Is it $0.00?** → Confirms escrow mode ✅

### Step 2: Transfer Money to Your Connect Account (3 min)

**Two ways to do this:**

#### Option A: Via Stripe Dashboard (Easiest)

1. **Go to**: https://dashboard.stripe.com/test/connect/transfers
2. **Click**: "New" or "Create transfer"
3. **Destination**: Select your Connect account
4. **Amount**: Enter the amount (e.g., $4.25 = 425 cents)
5. **Currency**: USD
6. **Description**: "Manual transfer for payout"
7. **Click**: "Create transfer"
8. **Wait**: ~30 seconds for transfer to complete

#### Option B: Via Stripe Dashboard (Alternative)

1. **Go to**: Dashboard → Connect → Accounts
2. **Click**: Your Connect account
3. **Click**: "Transfer" button (top right)
4. **Amount**: Enter amount
5. **Submit**

### Step 3: Now Request Payout (1 min)

1. **Open**: CampusLink app
2. **Go to**: Wallet tab
3. **Click**: "Request Payout"
4. **Amount**: $4.25 (or whatever you transferred)
5. **Submit**
6. **Should work now!** ✅

---

## 🔍 Verify It Worked

**Check Supabase logs:**
1. Dashboard → Edge Functions → process-payout → Logs
2. Should see: "✅ Stripe payout created: po_xxxxx"
3. No "insufficient funds" error

**Check Stripe Dashboard:**
1. Dashboard → Connect → Accounts → Your account → Payouts
2. Should see new payout listed
3. Status: "paid" or "in_transit"

**Check app:**
1. Wallet → Payout History
2. Should see payout with status "processing" or "completed"

---

## 🎯 Long-term Fix (Prevent This from Happening Again)

### Option 1: Complete Stripe Connect Onboarding (Recommended)

**Run this SQL first:**
```sql
SELECT 
  stripe_connect_id,
  stripe_payouts_enabled,
  stripe_details_submitted,
  stripe_charges_enabled
FROM users
WHERE id = auth.uid();
```

**If any are NULL or FALSE:**

1. **Test Mode:**
   - Go to: https://dashboard.stripe.com/test/connect/accounts/overview
   - Click on your account
   - Complete any missing requirements
   - Usually instant approval in test mode

2. **Live Mode:**
   - Complete Stripe Connect onboarding in your app
   - Submit all required documents
   - Wait for Stripe verification (1-2 days)
   - They'll verify identity, bank account, etc.

**Once complete:**
- Future payments will use "destination charges"
- Money goes DIRECTLY to your Connect account
- You can payout immediately
- No manual transfers needed

### Option 2: Auto-Transfer in Payout Function

**Update `process-payout` to handle escrow mode:**

This is more complex but handles both cases automatically. See `ESCROW_MODE_PROBLEM.md` for code examples.

---

## 📊 Understanding What Happened

### Before (Escrow Mode)
```
Buyer paid → $5.00 to PLATFORM account
Your Connect account → $0.00
You request payout → ERROR: Insufficient funds
```

### After Transfer
```
Platform account → $5.00 - $4.25 = $0.75
Your Connect account → $0.00 + $4.25 = $4.25
You request payout → SUCCESS! ✅
```

### After Completing Onboarding (Future)
```
Buyer pays → $4.25 DIRECTLY to your Connect account
Platform keeps → $0.75 application fee
You request payout → SUCCESS! ✅ (no transfer needed)
```

---

## ⚠️ Important Notes

### For Test Mode
- Transfers are instant
- No actual money moves
- Good for testing

### For Live Mode (Production)
- **DO NOT** launch until Connect onboarding complete
- Manual transfers for every payment is NOT scalable
- You'd be holding seller funds (legal issues)
- Poor user experience

**Complete onboarding BEFORE going live!**

---

## 🚨 If Transfer Fails

**Error: "Insufficient funds in platform account"**
- You haven't made any sales yet
- Or sales used destination charges already
- Check platform balance in Stripe

**Error: "Invalid destination"**
- Connect account ID wrong
- Or account not verified
- Complete onboarding first

**Error: "Cannot transfer to this account"**
- Account missing capabilities
- Complete Stripe verification
- May need to add bank account

---

## ✅ Success Checklist

After following this guide:

- [ ] Checked platform balance (has money)
- [ ] Checked Connect balance (was $0.00)
- [ ] Created transfer in Stripe Dashboard
- [ ] Verified transfer completed
- [ ] Requested payout in app
- [ ] Payout succeeded without error
- [ ] Payout appears in Stripe Dashboard
- [ ] Started Connect onboarding for future

**All checked?** You're done! 🎉

---

## 📞 Still Having Issues?

**Gather this info:**

1. **Platform balance**: $______
2. **Connect balance before transfer**: $______
3. **Transfer amount**: $______
4. **Transfer status**: (pending/succeeded/failed)
5. **Payout error** (if any): _________________

---

**Darragh**, once you do the manual transfer, the payout should work immediately. But definitely complete the Connect onboarding so this doesn't happen again!


