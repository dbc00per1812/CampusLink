# Payout Error Troubleshooting Checklist ✅

**Print this and check boxes as you go!**

---

## 🎯 Step 1: Supabase Dashboard Check

**URL**: https://supabase.com/dashboard

- [ ] Logged into Supabase
- [ ] Selected correct project
- [ ] Clicked "Edge Functions" in sidebar

**Do you see `process-payout` in the list?**

- [ ] **YES** → Go to Step 2
- [ ] **NO** → Go to Step 4 (Deploy Function)

---

## 🔑 Step 2: Environment Variables Check

**If function exists:**

- [ ] Clicked on `process-payout` function
- [ ] Opened Settings/Configuration tab
- [ ] Found "Environment Variables" section

**Do you see `STRIPE_SECRET_KEY`?**

- [ ] **YES** → Go to Step 3
- [ ] **NO** → Add it:
  - [ ] Click "Add Variable"
  - [ ] Key: `STRIPE_SECRET_KEY`
  - [ ] Value: (your Stripe secret key from Stripe dashboard)
  - [ ] Save
  - [ ] Go to Step 5 (Test)

---

## 📋 Step 3: Check Function Logs

**View recent errors:**

- [ ] Still in `process-payout` function page
- [ ] Click "Logs" tab
- [ ] Look for entries from ~1:51 AM (when error occurred)

**What do the logs show?**

- [ ] No logs from that time → Function never called (weird!)
- [ ] Error about Stripe key → Missing STRIPE_SECRET_KEY
- [ ] Error about Connect account → Stripe Connect not set up
- [ ] Other error → Write it down: _______________________

**Based on logs:**

- [ ] Missing key → Add STRIPE_SECRET_KEY, go to Step 5
- [ ] Connect error → Go to Step 6 (Check Stripe Connect)
- [ ] Other → Note error and contact support

---

## 🏗️ Step 4: Deploy Edge Function

**If function doesn't exist:**

- [ ] In Supabase, clicked "New Function"
- [ ] Named it: `process-payout` (exactly, with hyphen)
- [ ] Opened file: `supabase/functions/process-payout/index.ts`
- [ ] Copied ALL contents
- [ ] Pasted into Supabase editor
- [ ] Clicked "Deploy" or "Save"
- [ ] Waited for success confirmation

**Set environment variable:**

- [ ] Clicked "Settings" or "Configuration"
- [ ] Added environment variable:
  - [ ] Key: `STRIPE_SECRET_KEY`
  - [ ] Value: (your Stripe secret key)
- [ ] Saved

**Now go to Step 5 (Test)**

---

## 🧪 Step 5: Test Payout

**Try requesting payout again:**

- [ ] Opened CampusLink app
- [ ] Went to Wallet
- [ ] Clicked "Request Payout"
- [ ] Selected amount (try small amount like $0.50)
- [ ] Clicked "Request Payout"

**What happened?**

- [ ] ✅ **SUCCESS!** → Payout requested, no error
  - [ ] Go to Step 7 (Verify in Stripe)
- [ ] ❌ **ERROR** → Still getting error
  - [ ] Note error message: _______________________
  - [ ] Go to Step 6 (Check Stripe Connect)

---

## 💳 Step 6: Check Stripe Connect Setup

**Run diagnostic SQL:**

- [ ] Opened Supabase SQL Editor
- [ ] Opened file: `DIAGNOSE_PAYOUT_SYSTEM.sql`
- [ ] Copied all contents
- [ ] Pasted and executed

**Check Section 4 results:**

Your `stripe_connect_id`:
- [ ] Has a value (starts with `acct_`) → Good!
- [ ] Is NULL → **Problem found!** Need to complete Stripe Connect onboarding

Your `stripe_payouts_enabled`:
- [ ] Is `true` → Good!
- [ ] Is `false` or `NULL` → **Problem found!** Complete verification in Stripe

**If Connect account is missing or not ready:**

- [ ] Go to Stripe Connect onboarding in app
- [ ] Complete all required steps
- [ ] Submit for verification
- [ ] Wait for approval
- [ ] Try payout again

---

## ✅ Step 7: Verify Payout in Stripe

**If payout succeeded:**

- [ ] Opened Stripe Dashboard: https://dashboard.stripe.com
- [ ] Switched to Test/Live mode (whichever you're using)
- [ ] Clicked "Connect" → "Accounts"
- [ ] Found your Connect account
- [ ] Clicked "Payouts" tab

**Do you see the payout?**

- [ ] **YES** → 🎉 SUCCESS! Everything is working!
- [ ] **NO** → Run diagnostic SQL and check for errors

---

## 💰 Step 8: Check Wallet Balance

**Verify wallet was handled correctly:**

- [ ] Ran diagnostic SQL (Section 3)
- [ ] Noted "available_cents" value

**If payout FAILED but wallet was DEDUCTED:**

- [ ] Need to refund wallet
- [ ] Run this SQL:
  ```sql
  -- Add back the deducted amount
  UPDATE wallets 
  SET available_cents = available_cents + 425,  -- for $4.25
      updated_at = NOW()
  WHERE user_id = auth.uid();
  ```
- [ ] Verified refund in app

---

## 📊 Step 9: Final Verification

**Everything should now show:**

- [ ] Edge function is deployed
- [ ] STRIPE_SECRET_KEY is configured
- [ ] Stripe Connect account exists
- [ ] Payouts are enabled
- [ ] Test payout succeeded
- [ ] Payout appears in Stripe dashboard
- [ ] Payout status is "pending" or "processing"
- [ ] Wallet balance is correct

**If all checked:**

- [ ] 🎉 SYSTEM IS WORKING!
- [ ] Document what the issue was: _______________________
- [ ] Test with larger amount if desired
- [ ] Monitor for next 24-48 hours

---

## ❌ If Still Not Working

**Gather this info:**

1. **Edge function deployed?** 
   - [ ] Yes
   - [ ] No

2. **STRIPE_SECRET_KEY set?**
   - [ ] Yes
   - [ ] No

3. **Function logs show error:**
   - Error message: _______________________

4. **Diagnostic SQL Section 4 (Stripe Connect):**
   - stripe_connect_id: _______________________
   - stripe_payouts_enabled: _______________________

5. **Diagnostic SQL Section 1 (Recent payouts):**
   - How many pending?: _______________________
   - Status values: _______________________

**Contact support with these 5 answers** → Can provide exact fix

---

## 🎯 Success Criteria

You know it's working when:

- ✅ Payout request completes without error
- ✅ Wallet balance decreases by payout amount
- ✅ Payout record created in database
- ✅ Payout has `stripe_payout_id` (not null)
- ✅ Payout appears in Stripe dashboard
- ✅ Status changes from "pending" to "processing"
- ✅ Money arrives in bank account (2-3 days for standard)

---

## 📞 Quick Reference

**Supabase Dashboard**: https://supabase.com/dashboard  
**Stripe Dashboard**: https://dashboard.stripe.com  
**Edge Function Name**: `process-payout` (hyphen, not underscore)  
**Environment Variable**: `STRIPE_SECRET_KEY`  
**Minimum Payout**: $0.50  
**Standard Payout Time**: 2-3 business days  

---

## 🔗 Documentation Files

If you need more details, see:

- `PAYOUT_ERROR_QUICK_FIX.md` - Detailed troubleshooting
- `PAYMENT_SYSTEM_ANALYSIS.md` - Technical deep dive
- `DIAGNOSE_PAYOUT_SYSTEM.sql` - Database diagnostic script
- `ANALYSIS_SUMMARY.md` - Executive summary
- `log.md` - Full documentation entry

---

**Good luck, Darragh! 🚀**

