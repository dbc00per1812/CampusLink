# Stripe-First Payout System - The RIGHT Way

**Philosophy**: Database is for records. Stripe is for money. NEVER trust database for balance.

---

## 🎯 The Fix (Production-Ready)

### Step 1: Deploy `get-stripe-balance` Edge Function

1. **Copy**: `supabase/functions/get-stripe-balance/index.ts`
2. **Deploy to Supabase**:
   - Dashboard → Edge Functions → New Function
   - Name: `get-stripe-balance`
   - Paste code
   - Deploy

3. **Set env var**: `STRIPE_SECRET_KEY` (already set if process-payout works)

### Step 2: Update WalletView to Query Stripe

**File**: `CampusLink/Features/Wallet/Views/WalletView.swift`

Find where it loads balance and add Stripe query:

```swift
struct WalletView: View {
    @State private var stripeBalance: StripeBalance?
    @State private var isLoadingStripeBalance = false
    
    var body: some View {
        // ... existing code ...
    }
    
    // Add this
    private func loadStripeBalance() async {
        isLoadingStripeBalance = true
        
        do {
            struct StripeBalanceResponse: Decodable {
                let available_for_standard_cents: Int
                let available_for_instant_cents: Int
                let pending_cents: Int
                let total_cents: Int
            }
            
            let response: StripeBalanceResponse = try await supabase.functions.invoke(
                "get-stripe-balance",
                options: FunctionInvokeOptions(method: .post)
            )
            
            await MainActor.run {
                stripeBalance = StripeBalance(
                    availableStandard: response.available_for_standard_cents,
                    availableInstant: response.available_for_instant_cents,
                    pending: response.pending_cents,
                    total: response.total_cents
                )
                isLoadingStripeBalance = false
            }
        } catch {
            print("Error loading Stripe balance:", error)
            await MainActor.run {
                isLoadingStripeBalance = false
            }
        }
    }
    
    // Call in .task or .onAppear
    .task {
        await loadStripeBalance()
    }
}

struct StripeBalance {
    let availableStandard: Int
    let availableInstant: Int
    let pending: Int
    let total: Int
}
```

### Step 3: Pass STRIPE Balance to PayoutRequestView

**Change this:**
```swift
// OLD (WRONG):
PayoutRequestView(
    availableBalance: wallet.availableCents,  // ❌ Database lie
    onPayoutRequested: { _ in },
    onDismiss: { }
)
```

**To this:**
```swift
// NEW (CORRECT):
PayoutRequestView(
    availableBalance: stripeBalance?.availableStandard ?? 0,  // ✅ Stripe truth
    pendingBalance: stripeBalance?.pending ?? 0,
    onPayoutRequested: { _ in },
    onDismiss: { }
)
```

### Step 4: Update PayoutRequestView UI

Show BOTH available now AND pending:

```swift
struct PayoutRequestView: View {
    let availableBalance: Int  // From Stripe
    let pendingBalance: Int     // From Stripe (new)
    
    var body: some View {
        VStack {
            // Available NOW
            Text("Available to withdraw")
                .font(.caption)
            Text(formatAmount(availableBalance))
                .font(.largeTitle)
                .bold()
            
            // Pending
            if pendingBalance > 0 {
                Text("+ \(formatAmount(pendingBalance)) pending (available in 2-7 days)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}
```

---

## 🚀 What This Achieves

### Before (Broken):
```
1. Query database wallet → $4.25 (wrong)
2. Show "$4.25 available"
3. User requests $4.25
4. Stripe says "only have $0.56" → FAIL
```

### After (Fixed):
```
1. Query Stripe balance → $0.56 available, $2.00 pending
2. Show "$0.56 available now, $2.00 coming soon"
3. User requests $0.50
4. Stripe says "OK!" → SUCCESS ✅
```

---

## 📝 Database Wallet Purpose

**What database wallet is FOR:**
- ✅ Historical record
- ✅ Audit trail
- ✅ Accounting reports

**What database wallet is NOT for:**
- ❌ Validation
- ❌ Balance checks
- ❌ Payout decisions

**Stripe is the single source of truth for money.**

---

## 🧪 Testing

### Test 1: Check Real Balance

```bash
# Call the edge function directly
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/get-stripe-balance \
  -H "Authorization: Bearer YOUR_TOKEN"

# Should return:
{
  "available_for_standard_cents": 56,
  "available_for_instant_cents": 256,
  "pending_cents": 200,
  "total_cents": 256
}
```

### Test 2: Request Small Payout

- Open app
- Should show: "$0.56 available"
- Request: $0.50
- Should work! ✅

### Test 3: Try Large Payout

- Request: $2.00
- Should show error: "Only $0.56 available now. $2.00 is pending."

---

## 🎯 Why This is Right

**Darragh, you were correct:**

1. ✅ Stripe is source of truth
2. ✅ Database can't be trusted
3. ✅ Query actual balance before showing UI
4. ✅ Let Stripe validate everything

**No more:**
- ❌ Out-of-sync database
- ❌ Wrong balance displays
- ❌ Failed payouts due to bad data

**Only:**
- ✅ Real-time Stripe balance
- ✅ Accurate available amount
- ✅ Payouts that actually work

---

## 📋 Deployment Checklist

- [ ] Deploy `get-stripe-balance` edge function
- [ ] Update WalletView to query Stripe
- [ ] Pass Stripe balance to PayoutRequestView
- [ ] Show pending balance in UI
- [ ] Test with small payout ($0.50)
- [ ] Verify in Stripe dashboard
- [ ] Delete database wallet (optional, but satisfying)

---

**This is production-grade, Darragh. Database is dead. Long live Stripe!** 🎉

