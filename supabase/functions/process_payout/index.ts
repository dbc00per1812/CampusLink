// Supabase Edge Function: process_payout
// - Processes approved payout requests by creating Stripe transfers
// - Validates payout request and seller authorization
// - Creates Stripe transfer to connected account
// - Updates payout status in database
// - Handles errors and retries

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

type ProcessPayoutRequest = {
  payout_id: string;
};

type PayoutRecord = {
  id: string;
  seller_id: string;
  amount_cents: number;
  status: string;
  stripe_transfer_id?: string | null;
  error_message?: string | null;
  retry_count?: number;
};

type UserProfile = {
  id: string;
  stripe_connect_id: string | null;
  email: string;
};

type WalletRecord = {
  user_id: string;
  available_cents: number;
  escrow_cents: number;
};

type HttpJson = Record<string, unknown> | unknown[] | string | number | boolean | null;

function jsonResponse(status: number, body: HttpJson, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      ...init.headers,
    },
  });
}

function getStripe(): Stripe {
  const secretKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!secretKey) {
    throw new Error("Missing STRIPE_SECRET_KEY environment variable");
  }
  return new Stripe(secretKey, { apiVersion: "2024-06-20" });
}

function getSupabaseServiceClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variable");
  }
  return createClient(supabaseUrl, serviceRoleKey);
}

function getSupabaseAuthClient(req: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variable");
  }
  return createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: req.headers.get("Authorization") ?? "",
      },
    },
  });
}

function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      },
    });
  }
  return null;
}

async function getAuthenticatedUserId(req: Request): Promise<string> {
  const supabase = getSupabaseAuthClient(req);
  const { data, error } = await supabase.auth.getUser();
  if (error || !data?.user?.id) {
    throw new Error("Unauthorized: unable to resolve authenticated user");
  }
  return data.user.id;
}

async function getPayoutRecord(payoutId: string): Promise<PayoutRecord> {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("payouts")
    .select("*")
    .eq("id", payoutId)
    .single();
  
  if (error || !data) {
    throw new Error(`Payout record not found: ${payoutId}`);
  }
  
  return data as PayoutRecord;
}

async function getUserProfile(userId: string): Promise<UserProfile> {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("users")
    .select("id, stripe_connect_id, email")
    .eq("id", userId)
    .single();
  
  if (error || !data) {
    throw new Error("User profile not found");
  }
  
  return data as UserProfile;
}

async function getWalletBalance(userId: string): Promise<WalletRecord> {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("wallets")
    .select("*")
    .eq("user_id", userId)
    .single();
  
  if (error || !data) {
    throw new Error("Wallet not found for user");
  }
  
  return data as WalletRecord;
}

async function updatePayoutStatus(
  payoutId: string, 
  status: string, 
  transferId?: string | null, 
  errorMessage?: string | null
): Promise<void> {
  const supabase = getSupabaseServiceClient();
  const updateData: any = {
    status,
    updated_at: new Date().toISOString(),
  };
  
  if (transferId !== undefined) {
    updateData.stripe_transfer_id = transferId;
  }
  
  if (errorMessage !== undefined) {
    updateData.error_message = errorMessage;
  }
  
  const { error } = await supabase
    .from("payouts")
    .update(updateData)
    .eq("id", payoutId);
  
  if (error) {
    throw new Error(`Failed to update payout status: ${error.message}`);
  }
}

async function deductFromAvailableBalance(userId: string, amountCents: number): Promise<void> {
  const supabase = getSupabaseServiceClient();
  
  // Use a transaction to ensure atomicity
  // First, get current balance with row lock
  const { data: wallet, error: fetchError } = await supabase
    .from("wallets")
    .select("available_cents")
    .eq("user_id", userId)
    .single();
  
  if (fetchError || !wallet) {
    throw new Error("Failed to fetch wallet balance");
  }
  
  const currentBalance = wallet.available_cents;
  
  if (currentBalance < amountCents) {
    throw new Error("Insufficient balance for payout");
  }
  
  // Update the balance
  const { error: updateError } = await supabase
    .from("wallets")
    .update({ 
      available_cents: currentBalance - amountCents,
      updated_at: new Date().toISOString()
    })
    .eq("user_id", userId)
    .eq("available_cents", currentBalance); // Optimistic locking
  
  if (updateError) {
    throw new Error(`Failed to update wallet balance: ${updateError.message}`);
  }
}

async function createStripeTransfer(
  amountCents: number, 
  connectAccountId: string, 
  payoutId: string,
  userId: string
): Promise<Stripe.Transfer> {
  const stripe = getStripe();
  
  // Calculate platform fee (e.g., 5% with minimum of $0.50)
  const platformFeeCents = Math.max(50, Math.floor(amountCents * 0.05));
  const transferAmountCents = amountCents - platformFeeCents;
  
  if (transferAmountCents <= 0) {
    throw new Error("Transfer amount must be greater than platform fee");
  }
  
  const transfer = await stripe.transfers.create({
    amount: transferAmountCents,
    currency: "usd",
    destination: connectAccountId,
    description: `Payout for marketplace seller`,
    metadata: {
      payout_id: payoutId,
      seller_id: userId,
      platform_fee_cents: platformFeeCents.toString(),
      requested_amount_cents: amountCents.toString(),
    },
  });
  
  return transfer;
}

async function incrementRetryCount(payoutId: string): Promise<number> {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("payouts")
    .select("retry_count")
    .eq("id", payoutId)
    .single();
  
  if (error || !data) {
    throw new Error("Failed to fetch retry count");
  }
  
  const currentCount = data.retry_count || 0;
  const newCount = currentCount + 1;
  
  const { error: updateError } = await supabase
    .from("payouts")
    .update({ retry_count: newCount })
    .eq("id", payoutId);
  
  if (updateError) {
    throw new Error("Failed to update retry count");
  }
  
  return newCount;
}

Deno.serve(async (req: Request) => {
  const maybeOptions = handleOptions(req);
  if (maybeOptions) return maybeOptions;

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  let payoutId: string | undefined;
  
  try {
    // Authenticate user
    const userId = await getAuthenticatedUserId(req);
    
    // Parse request body
    const body = (await req.json()) as ProcessPayoutRequest;
    payoutId = body?.payout_id;
    
    if (!payoutId || typeof payoutId !== "string") {
      return jsonResponse(400, { error: "Missing or invalid 'payout_id'" });
    }
    
    // Get payout record
    const payout = await getPayoutRecord(payoutId);
    
    // Verify the authenticated user is the seller
    if (payout.seller_id !== userId) {
      return jsonResponse(403, { error: "Only the seller can process this payout" });
    }
    
    // Check payout status
    if (payout.status !== "pending" && payout.status !== "failed") {
      return jsonResponse(400, { 
        error: `Payout cannot be processed. Current status: ${payout.status}` 
      });
    }
    
    // Check retry limit for failed payouts
    if (payout.status === "failed") {
      const retryCount = await incrementRetryCount(payoutId);
      if (retryCount > 3) {
        await updatePayoutStatus(payoutId, "cancelled", null, "Max retry attempts exceeded");
        return jsonResponse(400, { error: "Maximum retry attempts exceeded. Payout cancelled." });
      }
    }
    
    // Update status to processing
    await updatePayoutStatus(payoutId, "processing");
    
    // Get user profile with Stripe Connect ID
    const userProfile = await getUserProfile(userId);
    
    if (!userProfile.stripe_connect_id) {
      await updatePayoutStatus(payoutId, "failed", null, "No Stripe Connect account linked");
      return jsonResponse(400, { 
        error: "No Stripe Connect account linked. Please complete payout onboarding first." 
      });
    }
    
    // Verify sufficient balance
    const wallet = await getWalletBalance(userId);
    
    if (wallet.available_cents < payout.amount_cents) {
      await updatePayoutStatus(payoutId, "failed", null, "Insufficient available balance");
      return jsonResponse(400, { 
        error: "Insufficient available balance for payout" 
      });
    }
    
    // Check if Stripe Connect account is active
    const stripe = getStripe();
    const account = await stripe.accounts.retrieve(userProfile.stripe_connect_id);
    
    if (!account.payouts_enabled) {
      await updatePayoutStatus(payoutId, "failed", null, "Stripe Connect account not fully onboarded");
      return jsonResponse(400, { 
        error: "Your payout account is not fully set up. Please complete onboarding." 
      });
    }
    
    // Deduct from available balance (with row lock)
    await deductFromAvailableBalance(userId, payout.amount_cents);
    
    try {
      // Create Stripe transfer
      const transfer = await createStripeTransfer(
        payout.amount_cents,
        userProfile.stripe_connect_id,
        payoutId,
        userId
      );
      
      // Update payout status to completed
      await updatePayoutStatus(payoutId, "completed", transfer.id);
      
      return jsonResponse(200, {
        status: "completed",
        transfer_id: transfer.id,
        transfer_amount: transfer.amount,
        destination: transfer.destination,
        message: "Payout processed successfully",
      });
      
    } catch (transferError) {
      // If transfer fails, refund the balance
      const { error: refundError } = await getSupabaseServiceClient()
        .from("wallets")
        .update({ 
          available_cents: wallet.available_cents,
          updated_at: new Date().toISOString()
        })
        .eq("user_id", userId);
      
      if (refundError) {
        console.error("Critical: Failed to refund balance after transfer failure:", refundError);
      }
      
      throw transferError;
    }
    
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    
    // Update payout status to failed if we have the payout ID
    if (payoutId) {
      try {
        await updatePayoutStatus(payoutId, "failed", null, message);
      } catch (updateErr) {
        console.error("Failed to update payout status on error:", updateErr);
      }
    }
    
    // Log error for monitoring
    console.error("Payout processing error:", {
      error: message,
      payout_id: payoutId,
      timestamp: new Date().toISOString(),
    });
    
    return jsonResponse(400, { error: message });
  }
});
