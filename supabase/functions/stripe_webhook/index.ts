// Supabase Edge Function: stripe_webhook
// - Verifies Stripe signature
// - Processes relevant events and updates the payments table
// - Handles Stripe Connect events for payout tracking

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

type HttpJson = Record<string, unknown> | unknown[] | string | number | boolean | null;

function jsonResponse(status: number, body: HttpJson, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
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

async function updatePaymentStatusByIntentId(paymentIntentId: string, status: string, extra: Record<string, unknown> = {}): Promise<void> {
  const supabase = getSupabaseServiceClient();
  const { error } = await supabase
    .from("payments")
    .update({ status, ...extra })
    .eq("payment_intent_id", paymentIntentId);
  if (error) {
    throw new Error(`Failed to update payment status: ${error.message}`);
  }
}

async function updatePayoutStatusByTransferId(transferId: string, status: string, extra: Record<string, unknown> = {}): Promise<void> {
  const supabase = getSupabaseServiceClient();
  const updateData = { 
    status, 
    updated_at: new Date().toISOString(),
    ...extra 
  };
  
  const { error } = await supabase
    .from("payouts")
    .update(updateData)
    .eq("stripe_transfer_id", transferId);
    
  if (error) {
    // Transfer might not have a corresponding payout yet (in case of automatic transfers)
    console.warn(`Failed to update payout status for transfer ${transferId}: ${error.message}`);
  }
}

async function getPayoutByTransferId(transferId: string): Promise<{ id: string; seller_id: string; amount_cents: number } | null> {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("payouts")
    .select("id, seller_id, amount_cents")
    .eq("stripe_transfer_id", transferId)
    .single();
    
  if (error || !data) {
    return null;
  }
  
  return data as { id: string; seller_id: string; amount_cents: number };
}

async function createOrderFromPayment(paymentIntentId: string): Promise<void> {
  const supabase = getSupabaseServiceClient();
  
  try {
    // Get payment details
    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .select("listing_id, buyer_id, seller_id, amount_cents, payment_method")
      .eq("payment_intent_id", paymentIntentId)
      .single();
      
    if (paymentError || !payment) {
      console.warn(`No payment found for PaymentIntent ${paymentIntentId}`);
      return;
    }
    
    // Create order using the reserve_then_order RPC
    const { data: order, error: orderError } = await supabase
      .rpc("reserve_then_order", {
        p_listing_id: payment.listing_id,
        p_buyer_id: payment.buyer_id,
        p_seller_id: payment.seller_id,
        p_price_cents: payment.amount_cents.toString(),
        p_payment_method: payment.payment_method || "card"
      });
      
    if (orderError) {
      console.error(`Failed to create order for payment ${paymentIntentId}: ${orderError.message}`);
    } else {
      console.log(`Order created successfully for payment ${paymentIntentId}: ${order.id}`);
    }
    
  } catch (error) {
    console.error(`Error creating order from payment ${paymentIntentId}:`, error);
  }
}

async function updateConnectAccountStatus(accountId: string, payoutsEnabled: boolean, detailsSubmitted: boolean): Promise<void> {
  const supabase = getSupabaseServiceClient();
  
  // Find user by stripe_connect_id
  const { data: user, error: userError } = await supabase
    .from("users")
    .eq("stripe_connect_id", accountId)
    .single();
    
  if (userError || !user) {
    console.warn(`No user found with Stripe Connect ID ${accountId}`);
    return;
  }
  
  // Update user's Connect account status (could add fields for this if needed)
  const { error: updateError } = await supabase
    .from("users")
    .update({
      stripe_payouts_enabled: payoutsEnabled,
      stripe_details_submitted: detailsSubmitted,
      updated_at: new Date().toISOString(),
    })
    .eq("id", user.id);
    
  if (updateError) {
    console.error(`Failed to update Connect account status for user ${user.id}: ${updateError.message}`);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "content-type, stripe-signature",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  const stripe = getStripe();
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!webhookSecret) {
    return jsonResponse(500, { error: "Missing STRIPE_WEBHOOK_SECRET" });
  }

  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return jsonResponse(400, { error: "Missing Stripe-Signature header" });
  }

  const payload = await req.text();

  // Use async verification for edge/Deno runtimes (SubtleCrypto provider)
  const cryptoProvider = Stripe.createSubtleCryptoProvider();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      payload,
      signature,
      webhookSecret,
      undefined,
      cryptoProvider,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(400, { error: `Webhook signature verification failed: ${message}` });
  }

  try {
    switch (event.type) {
      // Payment Intent Events
      case "payment_intent.succeeded": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "succeeded");
        
        // Create order when payment succeeds
        await createOrderFromPayment(pi.id);
        break;
      }
      case "payment_intent.payment_failed": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "failed");
        break;
      }
      case "payment_intent.canceled": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "canceled");
        break;
      }
      case "payment_intent.requires_action": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "requires_action");
        break;
      }
      case "payment_intent.processing": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "processing");
        break;
      }
      case "payment_intent.amount_capturable_updated": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "requires_capture");
        break;
      }
      
      // Charge Events
      case "charge.dispute.created": {
        const charge = event.data.object as Stripe.Charge;
        const paymentIntentId = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id ?? "";
        if (paymentIntentId) {
          await updatePaymentStatusByIntentId(paymentIntentId, "dispute_created");
        }
        break;
      }
      
      // Transfer Events (for Stripe Connect payouts)
      case "transfer.created": {
        const transfer = event.data.object as Stripe.Transfer;
        const transferId = transfer.id;
        
        // Update payout status to processing
        await updatePayoutStatusByTransferId(transferId, "processing", {
          stripe_transfer_amount: transfer.amount,
          stripe_transfer_currency: transfer.currency,
        });
        
        console.log(`Transfer created: ${transferId}, amount: ${transfer.amount}`);
        break;
      }
      
      case "transfer.paid": {
        const transfer = event.data.object as Stripe.Transfer;
        const transferId = transfer.id;
        
        // Update payout status to paid
        await updatePayoutStatusByTransferId(transferId, "paid", {
          paid_at: new Date().toISOString(),
        });
        
        console.log(`Transfer paid: ${transferId}, amount: ${transfer.amount}`);
        break;
      }
      
      case "transfer.failed": {
        const transfer = event.data.object as Stripe.Transfer;
        const transferId = transfer.id;
        
        // Get the payout record to refund the wallet balance
        const payout = await getPayoutByTransferId(transferId);
        
        if (payout) {
          // Update payout status to failed
          await updatePayoutStatusByTransferId(transferId, "failed", {
            error_message: "Transfer failed - funds will be refunded to wallet",
          });
          
          // Refund the amount back to user's available balance
          const supabase = getSupabaseServiceClient();
          const { data: wallet, error: walletError } = await supabase
            .from("wallets")
            .select("available_cents")
            .eq("user_id", payout.seller_id)
            .single();
            
          if (!walletError && wallet) {
            const { error: refundError } = await supabase
              .from("wallets")
              .update({
                available_cents: wallet.available_cents + payout.amount_cents,
                updated_at: new Date().toISOString(),
              })
              .eq("user_id", payout.seller_id);
              
            if (refundError) {
              console.error(`Failed to refund wallet for failed transfer ${transferId}: ${refundError.message}`);
            } else {
              console.log(`Refunded ${payout.amount_cents} cents to wallet for user ${payout.seller_id}`);
            }
          }
        }
        
        console.log(`Transfer failed: ${transferId}`);
        break;
      }
      
      // Stripe Connect Account Events
      case "account.updated": {
        const account = event.data.object as Stripe.Account;
        const accountId = account.id;
        
        // Update user's Connect account status
        await updateConnectAccountStatus(
          accountId,
          account.payouts_enabled ?? false,
          account.details_submitted ?? false
        );
        
        console.log(`Account updated: ${accountId}, payouts_enabled: ${account.payouts_enabled}, details_submitted: ${account.details_submitted}`);
        break;
      }
      
      default: {
        // Log unhandled events for debugging
        console.log(`Unhandled event type: ${event.type}`);
        break;
      }
    }

    return jsonResponse(200, { received: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Webhook error: ${message}`, { event_type: event.type });
    return jsonResponse(400, { error: message });
  }
});


