# Fix: Check Stripe Available Balance Before Payout

**Issue**: App allows payout request for $2.00, but Stripe only has $0.56 available  
**Root Cause**: App checks database wallet balance, not Stripe's actual available balance  
**Solution**: Query Stripe balance before showing payout UI

---

## The Problem

**Current flow:**
```
1. App checks: wallets.available_cents = 256 ✅
2. User requests: $2.00 payout
3. App calls Stripe: Create payout for $2.00
4. Stripe says: Only $0.56 available ❌
5. Error: "Insufficient funds"
```

**What should happen:**
```
1. App queries Stripe: Get actual available balance
2. Stripe returns: $0.56 available for standard, $2.56 for instant
3. App shows: "You can withdraw up to $0.56 (standard) or $2.56 (instant)"
4. User requests: Amount within limit
5. Payout succeeds ✅
```

---

## Solution Options

### Option A: Query Stripe Balance (Recommended)

Before showing payout UI, get the actual available balance from Stripe.

**Create new edge function: `get_stripe_balance`**

```typescript
// supabase/functions/get-stripe-balance/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("No authorization header");

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) throw new Error("Invalid token");

    // Get user's Stripe Connect ID
    const { data: userProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("stripe_connect_id")
      .eq("id", user.id)
      .single();

    if (profileError || !userProfile?.stripe_connect_id) {
      throw new Error("Stripe Connect account not found");
    }

    // Initialize Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    // Get balance from Stripe Connect account
    const balance = await stripe.balance.retrieve({
      stripeAccount: userProfile.stripe_connect_id,
    });

    // Calculate available amounts
    const availableForStandard = balance.available.reduce((sum, b) => sum + b.amount, 0);
    const pendingAmount = balance.pending.reduce((sum, b) => sum + b.amount, 0);
    
    // For instant payouts, check if instant balance exists
    const instantBalance = balance.instant_available?.[0]?.amount || 0;

    return new Response(
      JSON.stringify({
        available_for_standard_cents: availableForStandard,
        available_for_instant_cents: instantBalance || availableForStandard,
        pending_cents: pendingAmount,
        total_cents: availableForStandard + pendingAmount,
        currency: "usd",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error getting balance:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
```

**Update PayoutRequestView.swift:**

```swift
struct PayoutRequestView: View {
    // ... existing code ...
    
    @State private var stripeAvailableStandard: Int = 0
    @State private var stripeAvailableInstant: Int = 0
    @State private var isLoadingBalance = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                if isLoadingBalance {
                    ProgressView("Checking available balance...")
                        .padding()
                } else {
                    ScrollView {
                        // ... existing UI ...
                    }
                }
            }
        }
        .task {
            await loadStripeBalance()
            await checkDebitCardStatus()
        }
    }
    
    // Add this function
    private func loadStripeBalance() async {
        do {
            struct BalanceResponse: Decodable {
                let available_for_standard_cents: Int
                let available_for_instant_cents: Int
                let pending_cents: Int
                let total_cents: Int
            }
            
            let response: BalanceResponse = try await supabase.functions.invoke(
                "get-stripe-balance",
                options: FunctionInvokeOptions(method: .post)
            )
            
            await MainActor.run {
                stripeAvailableStandard = response.available_for_standard_cents
                stripeAvailableInstant = response.available_for_instant_cents
                isLoadingBalance = false
            }
        } catch {
            print("Error loading Stripe balance:", error)
            await MainActor.run {
                // Fallback to database balance
                stripeAvailableStandard = availableBalance
                stripeAvailableInstant = availableBalance
                isLoadingBalance = false
            }
        }
    }
    
    // Update validation
    private var canRequestPayout: Bool {
        let maxAvailable = selectedPayoutType == .instant ? 
            stripeAvailableInstant : stripeAvailableStandard
        
        return amountCents > 0 && 
               amountCents <= maxAvailable &&
               amountCents >= 50 // $0.50 minimum
    }
    
    // Update balance display
    private var balanceSection: some View {
        VStack(spacing: 16) {
            Text("Available Balance")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if selectedPayoutType == .standard {
                Text(formatAmount(stripeAvailableStandard))
                    .font(.system(size: 48, weight: .bold))
                
                if stripeAvailableStandard < availableBalance {
                    Text("\(formatAmount(availableBalance - stripeAvailableStandard)) pending (available in 2-7 days)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                Text(formatAmount(stripeAvailableInstant))
                    .font(.system(size: 48, weight: .bold))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
```

---

### Option B: Show Warning (Simpler)

Add a warning in the UI when requesting more than available:

```swift
// In PayoutRequestView
private var amountSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        // ... existing amount input ...
        
        // Add warning
        if amountCents > stripeAvailableStandard && selectedPayoutType == .standard {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Insufficient funds for standard payout")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Only \(formatAmount(stripeAvailableStandard)) available now. Try instant payout or wait 2-7 days.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
```

---

### Option C: Auto-Adjust Amount (User-Friendly)

Cap the input to what's actually available:

```swift
private var amountSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text("$")
            TextField("0.00", value: $amountCents, formatter: currencyFormatter)
                .keyboardType(.decimalPad)
        }
        
        // Quick amount buttons
        HStack(spacing: 8) {
            quickAmountButton(label: "Max Available", 
                            amount: selectedPayoutType == .instant ? 
                                  stripeAvailableInstant : stripeAvailableStandard)
            quickAmountButton(label: "Half", 
                            amount: (selectedPayoutType == .instant ? 
                                  stripeAvailableInstant : stripeAvailableStandard) / 2)
        }
    }
}

private func quickAmountButton(label: String, amount: Int) -> some View {
    Button(action: {
        amountCents = amount
    }) {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(6)
    }
}
```

---

## Quick Fix for Right Now

**Without code changes, just tell users:**

1. Check Stripe dashboard for "Available to pay out" amount
2. Only request that amount or less
3. OR wait for "Available soon" to become available
4. OR use instant payout (if debit card added)

---

## Deployment Steps

If you implement Option A:

1. Create `supabase/functions/get-stripe-balance/index.ts`
2. Deploy to Supabase:
   - Dashboard → Edge Functions → New Function
   - Name: `get-stripe-balance`
   - Paste code
   - Deploy
3. Update `PayoutRequestView.swift` with balance check
4. Test with your account
5. Should show "$0.56 available (standard)" instead of "$2.56"

---

**Darragh**, for RIGHT NOW just request $0.50 and it should work. For long-term, either wait for the money to clear or add the balance checking logic!

