// Supabase Edge Function: cancel_payout
// - Cancels Stripe transfers for pending payouts
// - Validates payout ownership and cancellation eligibility
// - Updates payout status and restores wallet balance
// - Handles different Stripe transfer states

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

type CancelPayoutRequest = {
  payout_id: string;
};

type PayoutRecord = {
  id: string;
  user_id: string;
  seller_id: string;
  amount_cents: number;
  status: string;
  stripe_transfer_id?: string | null;
  error_message?: string | null;
  retry_count?: number;
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
  errorMessage?: string | null
): Promise<void> {
  const supabase = getSupabaseServiceClient();
  const updateData: any = {
    status,
    updated_at: new Date().toISOString(),
  };
  
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

async function restoreWalletBalance(userId: string, amountCents: number): Promise<void> {
  const supabase = getSupabaseServiceClient();
  
  // Get current balance
  const { data: wallet, error: fetchError } = await supabase
    .from("wallets")
    .select("available_cents")
    .eq("user_id", userId)
    .single();
  
  if (fetchError || !wallet) {
    throw new Error("Failed to fetch wallet balance");
  }
  
  // Restore the balance
  const { error: updateError } = await supabase
    .from("wallets")
    .update({ 
      available_cents: wallet.available_cents + amountCents,
      updated_at: new Date().toISOString()
    })
    .eq("user_id", userId);
  
  if (updateError) {
    throw new Error(`Failed to restore wallet balance: ${updateError.message}`);
  }
}

async function cancelStripeTransfer(transferId: string): Promise<{ cancelled: boolean; reason?: string }> {
  const stripe = getStripe();
  
  try {
    // Get the current transfer status
    const transfer = await stripe.transfers.retrieve(transferId);
    
    // Check if transfer can be cancelled
    if (transfer.status === 'pending') {
      // Cancel the pending transfer
      await stripe.transfers.cancel(transferId);
      return { cancelled: true };
    } else if (transfer.status === 'in_transit') {
      return { 
        cancelled: false, 
        reason: "Transfer is already in transit and cannot be cancelled" 
      };
    } else if (transfer.status === 'paid') {
      return { 
        cancelled: false, 
        reason: "Transfer has already been completed and cannot be cancelled" 
      };
    } else if (transfer.status === 'failed') {
      // Transfer already failed, consider it "cancelled"
      return { cancelled: true, reason: "Transfer had already failed" };
    } else if (transfer.status === 'canceled') {
      // Already cancelled
      return { cancelled: true, reason: "Transfer was already cancelled" };
    } else {
      return { 
        cancelled: false, 
        reason: `Transfer status '${transfer.status}' does not allow cancellation` 
      };
    }
  } catch (error) {
    // If transfer doesn't exist or other Stripe error
    if (error instanceof Stripe.errors.StripeError) {
      if (error.code === 'resource_missing') {
        // Transfer doesn't exist, consider it cancelled
        return { cancelled: true, reason: "Transfer not found in Stripe" };
      }
      throw new Error(`Stripe error: ${error.message}`);
    }
    throw error;
  }
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
    const body = (await req.json()) as CancelPayoutRequest;
    payoutId = body?.payout_id;
    
    if (!payoutId || typeof payoutId !== "string") {
      return jsonResponse(400, { error: "Missing or invalid 'payout_id'" });
    }
    
    // Get payout record
    const payout = await getPayoutRecord(payoutId);
    
    // Verify the authenticated user owns this payout
    if (payout.user_id !== userId && payout.seller_id !== userId) {
      return jsonResponse(403, { error: "You can only cancel your own payouts" });
    }
    
    // Check if payout can be cancelled
    if (payout.status === "cancelled") {
      return jsonResponse(400, { error: "Payout is already cancelled" });
    }
    
    if (payout.status === "completed" || payout.status === "paid") {
      return jsonResponse(400, { error: "Cannot cancel a completed payout" });
    }
    
    if (payout.status !== "pending" && payout.status !== "processing" && payout.status !== "failed") {
      return jsonResponse(400, { 
        error: `Payout cannot be cancelled. Current status: ${payout.status}` 
      });
    }
    
    let stripeResult = { cancelled: true, reason: "No Stripe transfer to cancel" };
    
    // If there's a Stripe transfer ID, try to cancel it
    if (payout.stripe_transfer_id) {
      stripeResult = await cancelStripeTransfer(payout.stripe_transfer_id);
      
      if (!stripeResult.cancelled) {
        return jsonResponse(400, { 
          error: `Cannot cancel payout: ${stripeResult.reason}` 
        });
      }
    }
    
    // Restore wallet balance
    await restoreWalletBalance(payout.user_id, payout.amount_cents);
    
    // Update payout status to cancelled
    await updatePayoutStatus(
      payoutId, 
      "cancelled", 
      stripeResult.reason || "Payout cancelled by user"
    );
    
    return jsonResponse(200, {
      status: "cancelled",
      message: "Payout cancelled successfully",
      stripe_cancelled: stripeResult.cancelled,
      stripe_reason: stripeResult.reason,
      amount_restored: payout.amount_cents / 100,
    });
    
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    
    // Log error for monitoring
    console.error("Payout cancellation error:", {
      error: message,
      payout_id: payoutId,
      timestamp: new Date().toISOString(),
    });
    
    return jsonResponse(400, { error: message });
  }
});
