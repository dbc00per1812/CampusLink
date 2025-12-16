// Supabase Edge Function: stripe_webhook
// - Verifies Stripe signature
// - Processes relevant events and updates the payments table
// - Handles Stripe Connect events for payout tracking
// - Handles bank account payouts (payout.paid, payout.failed, payout.canceled)
import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

function jsonResponse(status, body, init = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      ...init.headers
    }
  });
}

function getStripe() {
  const secretKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!secretKey) {
    throw new Error("Missing STRIPE_SECRET_KEY environment variable");
  }
  return new Stripe(secretKey, {
    apiVersion: "2024-06-20"
  });
}

function getSupabaseServiceClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variable");
  }
  return createClient(supabaseUrl, serviceRoleKey);
}

async function updatePaymentStatusByIntentId(paymentIntentId, status, extra = {}) {
  const supabase = getSupabaseServiceClient();
  
  // If payment succeeded, set escrow status to held
  const updateData: any = {
    status,
    ...extra
  };
  
  if (status === 'succeeded') {
    updateData.escrow_release_status = 'held';
    console.log(`🔒 Setting escrow_release_status to 'held' for payment ${paymentIntentId}`);
  }
  
  const { error } = await supabase.from("payments").update(updateData).eq("payment_intent_id", paymentIntentId);
  if (error) {
    throw new Error(`Failed to update payment status: ${error.message}`);
  }
}

async function updatePayoutStatusByTransferId(transferId, status, extra = {}) {
  const supabase = getSupabaseServiceClient();
  const updateData = {
    status,
    updated_at: new Date().toISOString(),
    ...extra
  };
  const { error } = await supabase.from("payouts").update(updateData).eq("stripe_transfer_id", transferId);
  if (error) {
    // Transfer might not have a corresponding payout yet (in case of automatic transfers)
    console.warn(`Failed to update payout status for transfer ${transferId}: ${error.message}`);
  }
}

async function getPayoutByTransferId(transferId) {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase.from("payouts").select("id, seller_id, amount_cents").eq("stripe_transfer_id", transferId).single();
  if (error || !data) {
    return null;
  }
  return data;
}

async function createOrUpdateOrderFromPayment(paymentIntentId, metadata) {
  const supabase = getSupabaseServiceClient();
  try {
    // Get payment details from METADATA (not payments table - that's not used)
    const listingId = metadata?.listing_id;
    const buyerId = metadata?.buyer_id;
    const sellerId = metadata?.seller_id;
    const buyerPriceCents = metadata?.buyer_price_cents;
    
    if (!listingId || !buyerId || !sellerId) {
      console.error("Missing required metadata for order creation");
      return;
    }
    
    console.log(`Processing payment ${paymentIntentId} for listing ${listingId}`);
    
    // CHECK IF ORDER ALREADY EXISTS (from accepted offer)
    const { data: existingOrders } = await supabase
      .from("orders")
      .select("id, payment_status")
      .eq("listing_id", listingId)
      .eq("buyer_id", buyerId)
      .eq("payment_status", "pending")
      .limit(1);
    
    if (existingOrders && existingOrders.length > 0) {
      // UPDATE EXISTING ORDER (accepted offer that's now being paid)
      const existingOrder = existingOrders[0];
      console.log(`Found existing unpaid order ${existingOrder.id}, updating with payment`);
      
      const { error: updateError } = await supabase
        .from("orders")
        .update({
          stripe_payment_intent_id: paymentIntentId,
          payment_status: "succeeded",
          updated_at: new Date().toISOString()
        })
        .eq("id", existingOrder.id);
      
      if (updateError) {
        console.error(`Failed to update order ${existingOrder.id}:`, updateError.message);
      } else {
        console.log(`✅ Order ${existingOrder.id} updated with payment successfully`);
        
        // Also update escrow_release_status in payments table to 'held'
        const { error: escrowError } = await supabase
          .from("payments")
          .update({
            escrow_release_status: 'held'
          })
          .eq("payment_intent_id", paymentIntentId);
        
        if (escrowError) {
          console.error(`Failed to update escrow status: ${escrowError.message}`);
        } else {
          console.log(`✅ Escrow status set to 'held' for payment ${paymentIntentId}`);
        }
      }
      return;
    }
    
    // NO EXISTING ORDER: Create new order (normal purchase flow)
    console.log("No existing order found, creating new order via RPC");
    const { data: order, error: orderError } = await supabase.rpc("reserve_then_order", {
      p_listing_id: listingId,
      p_buyer_id: buyerId,
      p_seller_id: sellerId,
      p_price_cents: buyerPriceCents || "0",
      p_payment_method: "card"
    });
    
    if (orderError) {
      console.error(`Failed to create order for payment ${paymentIntentId}: ${orderError.message}`);
    } else {
      console.log(`✅ Order created successfully for payment ${paymentIntentId}: ${order?.id || 'unknown'}`);
    }
  } catch (error) {
    console.error(`Error handling order from payment ${paymentIntentId}:`, error);
  }
}

async function updateConnectAccountStatus(accountId, payoutsEnabled, detailsSubmitted) {
  const supabase = getSupabaseServiceClient();
  // Find user by stripe_connect_id
  const { data: user, error: userError } = await supabase.from("users").eq("stripe_connect_id", accountId).single();
  if (userError || !user) {
    console.warn(`No user found with Stripe Connect ID ${accountId}`);
    return;
  }
  // Update user's Connect account status (could add fields for this if needed)
  const { error: updateError } = await supabase.from("users").update({
    stripe_payouts_enabled: payoutsEnabled,
    stripe_details_submitted: detailsSubmitted,
    updated_at: new Date().toISOString()
  }).eq("id", user.id);
  if (updateError) {
    console.error(`Failed to update Connect account status for user ${user.id}: ${updateError.message}`);
  }
}

Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "content-type, stripe-signature",
        "Access-Control-Allow-Methods": "POST, OPTIONS"
      }
    });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, {
      error: "Method not allowed"
    });
  }
  const stripe = getStripe();
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!webhookSecret) {
    return jsonResponse(500, {
      error: "Missing STRIPE_WEBHOOK_SECRET"
    });
  }
  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return jsonResponse(400, {
      error: "Missing Stripe-Signature header"
    });
  }
  const payload = await req.text();
  // Use async verification for edge/Deno runtimes (SubtleCrypto provider)
  const cryptoProvider = Stripe.createSubtleCryptoProvider();
  let event;
  try {
    event = await stripe.webhooks.constructEventAsync(payload, signature, webhookSecret, undefined, cryptoProvider);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(400, {
      error: `Webhook signature verification failed: ${message}`
    });
  }
  try {
    switch(event.type){
      // Payment Intent Events
      case "payment_intent.succeeded":
        {
          const pi = event.data.object;
          await updatePaymentStatusByIntentId(pi.id, "succeeded");
          // Create or update order when payment succeeds
          await createOrUpdateOrderFromPayment(pi.id, pi.metadata);
          break;
        }
      case "payment_intent.payment_failed":
        {
          const pi = event.data.object;
          await updatePaymentStatusByIntentId(pi.id, "failed");
          break;
        }
      case "payment_intent.canceled":
        {
          const pi = event.data.object;
          await updatePaymentStatusByIntentId(pi.id, "canceled");
          break;
        }
      case "payment_intent.requires_action":
        {
          const pi = event.data.object;
          await updatePaymentStatusByIntentId(pi.id, "requires_action");
          break;
        }
      case "payment_intent.processing":
        {
          const pi = event.data.object;
          await updatePaymentStatusByIntentId(pi.id, "processing");
          break;
        }
      case "payment_intent.amount_capturable_updated":
        {
          const pi = event.data.object;
          await updatePaymentStatusByIntentId(pi.id, "requires_capture");
          break;
        }
      // Charge Events
      case "charge.succeeded":
        {
          const charge = event.data.object;
          const paymentIntentId = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id ?? "";
          if (paymentIntentId) {
            console.log(`💳 Charge succeeded for payment intent: ${paymentIntentId}`);
            await updatePaymentStatusByIntentId(paymentIntentId, "succeeded");
            // Also create/update order
            const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
            await createOrUpdateOrderFromPayment(paymentIntentId, paymentIntent.metadata);
          }
          break;
        }
      case "charge.dispute.created":
        {
          const charge = event.data.object;
          const paymentIntentId = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id ?? "";
          if (paymentIntentId) {
            await updatePaymentStatusByIntentId(paymentIntentId, "dispute_created");
          }
          break;
        }
      // Transfer Events (for Stripe Connect payouts via transfers)
      case "transfer.created":
        {
          const transfer = event.data.object;
          const transferId = transfer.id;
          // Update payout status to processing
          await updatePayoutStatusByTransferId(transferId, "processing", {
            stripe_transfer_amount: transfer.amount,
            stripe_transfer_currency: transfer.currency
          });
          console.log(`Transfer created: ${transferId}, amount: ${transfer.amount}`);
          break;
        }
      case "transfer.paid":
        {
          const transfer = event.data.object;
          const transferId = transfer.id;
          // Update payout status to paid
          await updatePayoutStatusByTransferId(transferId, "paid", {
            paid_at: new Date().toISOString()
          });
          console.log(`Transfer paid: ${transferId}, amount: ${transfer.amount}`);
          break;
        }
      case "transfer.failed":
        {
          const transfer = event.data.object;
          const transferId = transfer.id;
          // Get the payout record to refund the wallet balance
          const payout = await getPayoutByTransferId(transferId);
          if (payout) {
            // Update payout status to failed
            await updatePayoutStatusByTransferId(transferId, "failed", {
              error_message: "Transfer failed - funds will be refunded to wallet"
            });
            // Refund the amount back to user's available balance
            const supabase = getSupabaseServiceClient();
            const { data: wallet, error: walletError } = await supabase.from("wallets").select("available_cents").eq("user_id", payout.seller_id).single();
            if (!walletError && wallet) {
              const { error: refundError } = await supabase.from("wallets").update({
                available_cents: wallet.available_cents + payout.amount_cents,
                updated_at: new Date().toISOString()
              }).eq("user_id", payout.seller_id);
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
      // Payout Events (for bank account payouts created via stripe.payouts.create)
      case "payout.paid":
        {
          const payout = event.data.object;
          const payoutId = payout.id;
          console.log(`💰 Payout completed: ${payoutId} - Amount: $${payout.amount / 100}`);
          
          // Update payout status to completed
          const supabase = getSupabaseServiceClient();
          const { data, error } = await supabase
            .from("payouts")
            .update({
              status: "completed",
              completed_at: new Date().toISOString(),
              updated_at: new Date().toISOString()
            })
            .eq("stripe_payout_id", payoutId)
            .select();

          if (error) {
            console.error(`Failed to update payout status for ${payoutId}: ${error.message}`);
          } else if (!data || data.length === 0) {
            console.warn(`No payout found with stripe_payout_id: ${payoutId}`);
          } else {
            console.log(`✅ Payout marked as completed: ${data[0].id}`);
          }
          break;
        }
      case "payout.failed":
        {
          const payout = event.data.object;
          const payoutId = payout.id;
          console.log(`❌ Payout failed: ${payoutId} - Reason: ${payout.failure_message || "Unknown"}`);
          
          const supabase = getSupabaseServiceClient();
          
          // Get payout record to refund wallet balance
          const { data: payoutRecord, error: fetchError } = await supabase
            .from("payouts")
            .select("id, user_id, amount_cents")
            .eq("stripe_payout_id", payoutId)
            .single();

          if (fetchError || !payoutRecord) {
            console.warn(`No payout found with stripe_payout_id: ${payoutId}`);
          } else {
            // Update payout status to failed
            const { error: updateError } = await supabase
              .from("payouts")
              .update({
                status: "failed",
                updated_at: new Date().toISOString(),
                error_message: payout.failure_message || "Payout failed"
              })
              .eq("stripe_payout_id", payoutId);

            if (updateError) {
              console.error(`Failed to update payout status for ${payoutId}: ${updateError.message}`);
            } else {
              console.log(`Payout marked as failed: ${payoutRecord.id}`);
              
              // Refund the amount back to user's available balance
              const { data: wallet, error: walletError } = await supabase
                .from("wallets")
                .select("available_cents")
                .eq("user_id", payoutRecord.user_id)
                .single();

              if (!walletError && wallet) {
                const { error: refundError } = await supabase
                  .from("wallets")
                  .update({
                    available_cents: wallet.available_cents + payoutRecord.amount_cents,
                    updated_at: new Date().toISOString()
                  })
                  .eq("user_id", payoutRecord.user_id);

                if (refundError) {
                  console.error(`Failed to refund wallet for failed payout ${payoutId}: ${refundError.message}`);
                } else {
                  console.log(`✅ Refunded ${payoutRecord.amount_cents} cents to wallet for user ${payoutRecord.user_id}`);
                }
              }
            }
          }
          break;
        }
      case "payout.canceled":
        {
          const payout = event.data.object;
          const payoutId = payout.id;
          console.log(`🚫 Payout canceled: ${payoutId}`);
          
          const supabase = getSupabaseServiceClient();
          
          // Get payout record to refund wallet balance
          const { data: payoutRecord, error: fetchError } = await supabase
            .from("payouts")
            .select("id, user_id, amount_cents")
            .eq("stripe_payout_id", payoutId)
            .single();

          if (fetchError || !payoutRecord) {
            console.warn(`No payout found with stripe_payout_id: ${payoutId}`);
          } else {
            // Update payout status to canceled
            const { error: updateError } = await supabase
              .from("payouts")
              .update({
                status: "canceled",
                updated_at: new Date().toISOString()
              })
              .eq("stripe_payout_id", payoutId);

            if (updateError) {
              console.error(`Failed to update payout status for ${payoutId}: ${updateError.message}`);
            } else {
              console.log(`Payout marked as canceled: ${payoutRecord.id}`);
              
              // Refund the amount back to user's available balance
              const { data: wallet, error: walletError } = await supabase
                .from("wallets")
                .select("available_cents")
                .eq("user_id", payoutRecord.user_id)
                .single();

              if (!walletError && wallet) {
                const { error: refundError } = await supabase
                  .from("wallets")
                  .update({
                    available_cents: wallet.available_cents + payoutRecord.amount_cents,
                    updated_at: new Date().toISOString()
                  })
                  .eq("user_id", payoutRecord.user_id);

                if (refundError) {
                  console.error(`Failed to refund wallet for canceled payout ${payoutId}: ${refundError.message}`);
                } else {
                  console.log(`✅ Refunded ${payoutRecord.amount_cents} cents to wallet for user ${payoutRecord.user_id}`);
                }
              }
            }
          }
          break;
        }
      // Stripe Connect Account Events
      case "account.updated":
        {
          const account = event.data.object;
          const accountId = account.id;
          // Update user's Connect account status
          await updateConnectAccountStatus(accountId, account.payouts_enabled ?? false, account.details_submitted ?? false);
          console.log(`Account updated: ${accountId}, payouts_enabled: ${account.payouts_enabled}, details_submitted: ${account.details_submitted}`);
          break;
        }
      default:
        {
          // Log unhandled events for debugging
          console.log(`Unhandled event type: ${event.type}`);
          break;
        }
    }
    return jsonResponse(200, {
      received: true
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Webhook error: ${message}`, {
      event_type: event.type
    });
    return jsonResponse(400, {
      error: message
    });
  }
});

