// Supabase Edge Function to process expired orders
// Auto-cancels orders that haven't been completed within 5 days
// Also voids/refunds the payment authorization
//
// Run via cron job: SELECT cron.schedule('process-expired-orders', '0 * * * *', ...);

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// 5-day deadline in milliseconds
const ORDER_DEADLINE_MS = 5 * 24 * 60 * 60 * 1000; // 5 days

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🔄 Processing expired orders...");

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    // Calculate the cutoff time (5 days ago)
    const cutoffDate = new Date(Date.now() - ORDER_DEADLINE_MS);
    const cutoffISO = cutoffDate.toISOString();

    console.log(`📅 Cutoff date: ${cutoffISO}`);
    console.log(`📅 Orders created before this date will be auto-cancelled`);

    // Find orders that:
    // 1. Are not completed or cancelled
    // 2. Were created more than 5 days ago
    // 3. Have payment that needs to be voided/refunded
    const { data: expiredOrders, error: fetchError } = await supabaseAdmin
      .from("orders")
      .select("*")
      .in("order_status", ["placed", "seller_confirmed", "in_progress"])
      .lt("created_at", cutoffISO);

    if (fetchError) {
      console.error("Error fetching expired orders:", fetchError);
      throw fetchError;
    }

    if (!expiredOrders || expiredOrders.length === 0) {
      console.log("✅ No expired orders found");
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: "No expired orders found",
          processed: 0 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`⏰ Found ${expiredOrders.length} expired order(s)`);

    let processed = 0;
    let errors: string[] = [];

    for (const order of expiredOrders) {
      try {
        console.log(`\n🔄 Processing expired order: ${order.id}`);
        console.log(`   Created: ${order.created_at}`);
        console.log(`   Status: ${order.order_status}`);
        console.log(`   Payment Status: ${order.payment_status}`);
        console.log(`   Payment Intent: ${order.stripe_payment_intent_id || "None"}`);

        // Step 1: Cancel/void the Stripe payment if exists
        if (order.stripe_payment_intent_id) {
          try {
            const paymentIntent = await stripe.paymentIntents.retrieve(order.stripe_payment_intent_id);
            
            console.log(`   💳 Payment Intent Status: ${paymentIntent.status}`);

            if (paymentIntent.status === "requires_capture") {
              // Payment was authorized but not captured - cancel it
              await stripe.paymentIntents.cancel(order.stripe_payment_intent_id);
              console.log(`   ✅ Payment authorization cancelled`);
            } else if (paymentIntent.status === "succeeded") {
              // Payment was captured - need to refund
              await stripe.refunds.create({
                payment_intent: order.stripe_payment_intent_id,
                reason: "requested_by_customer",
              });
              console.log(`   ✅ Payment refunded`);
            } else if (paymentIntent.status === "canceled") {
              console.log(`   ℹ️ Payment was already cancelled`);
            } else {
              console.log(`   ⚠️ Payment in unexpected state: ${paymentIntent.status}`);
            }
          } catch (stripeError: any) {
            console.error(`   ❌ Stripe error: ${stripeError.message}`);
            // Continue with order cancellation even if Stripe fails
          }
        } else {
          console.log(`   ℹ️ No payment intent - order may have been wallet payment or unpaid`);
          
          // If it was a wallet payment, we should refund the wallet
          if (order.payment_method === "wallet" && order.payment_status === "succeeded") {
            // Get buyer's wallet and refund
            const { data: wallet, error: walletError } = await supabaseAdmin
              .from("wallets")
              .select("available_cents")
              .eq("user_id", order.buyer_id)
              .single();

            if (!walletError && wallet) {
              const refundAmount = order.buyer_price_cents || order.price_cents;
              const { error: refundError } = await supabaseAdmin
                .from("wallets")
                .update({
                  available_cents: wallet.available_cents + refundAmount,
                  updated_at: new Date().toISOString(),
                })
                .eq("user_id", order.buyer_id);

              if (!refundError) {
                console.log(`   ✅ Wallet refunded: ${refundAmount} cents`);
              } else {
                console.error(`   ❌ Wallet refund failed: ${refundError.message}`);
              }
            }
          }
        }

        // Step 2: Update order status to cancelled with reason
        const { error: updateError } = await supabaseAdmin
          .from("orders")
          .update({
            order_status: "cancelled",
            payment_status: order.payment_status === "succeeded" ? "refunded" : "cancelled",
            cancelled_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", order.id);

        if (updateError) {
          console.error(`   ❌ Failed to update order status: ${updateError.message}`);
          errors.push(`Order ${order.id}: ${updateError.message}`);
          continue;
        }

        console.log(`   ✅ Order status updated to cancelled`);

        // Step 3: Get listing info for notification
        const { data: listing } = await supabaseAdmin
          .from("listings")
          .select("title")
          .eq("id", order.listing_id)
          .single();

        const listingTitle = listing?.title || "your order";

        // Step 4: Notify buyer about cancellation and refund
        await supabaseAdmin.from("push_notification_queue").insert({
          user_id: order.buyer_id,
          title: "Order Auto-Cancelled",
          body: `Your order for "${listingTitle}" was cancelled because the seller didn't complete it within 5 days. You've been refunded.`,
          data: {
            type: "order_cancelled",
            order_id: order.id,
            reason: "seller_deadline_expired",
          },
        });

        // Step 5: Notify seller about the cancellation
        await supabaseAdmin.from("push_notification_queue").insert({
          user_id: order.seller_id,
          title: "Order Cancelled - Deadline Missed",
          body: `Your order for "${listingTitle}" was auto-cancelled because it wasn't completed within 5 days. The buyer has been refunded.`,
          data: {
            type: "order_cancelled",
            order_id: order.id,
            reason: "deadline_expired",
          },
        });

        // Step 6: If listing was marked as sold, unmark it so it's available again
        const { error: listingError } = await supabaseAdmin
          .from("listings")
          .update({
            is_sold: false,
            archived: false,
            updated_at: new Date().toISOString(),
          })
          .eq("id", order.listing_id);

        if (!listingError) {
          console.log(`   ✅ Listing restored to available`);
        }

        processed++;
        console.log(`   ✅ Order ${order.id} processed successfully`);

      } catch (orderError: any) {
        console.error(`   ❌ Error processing order ${order.id}: ${orderError.message}`);
        errors.push(`Order ${order.id}: ${orderError.message}`);
      }
    }

    console.log(`\n✅ Processed ${processed}/${expiredOrders.length} expired orders`);
    if (errors.length > 0) {
      console.log(`⚠️ Errors: ${errors.join(", ")}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${processed} expired orders`,
        processed,
        total: expiredOrders.length,
        errors: errors.length > 0 ? errors : undefined,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error("Error processing expired orders:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to process expired orders",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
