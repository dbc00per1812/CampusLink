// Supabase Edge Function to cleanup stale pending orders
// Removes orders that were created but never paid for (payment_status: 'pending')
// and are older than 30 minutes. This handles cases where:
// - User abandoned the payment flow
// - App crashed or was force-closed during payment
// - Network issues prevented payment completion
//
// SAFETY: This function is very conservative:
// - Only deletes orders with payment_status: 'pending' (never authorized)
// - Only deletes orders older than 30 minutes
// - Verifies no Stripe payment was associated
// - Safely unarchives listings only if no other active orders exist
//
// Run via cron job: SELECT cron.schedule('cleanup-stale-pending-orders', '*/15 * * * *', ...);

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// 30-minute threshold in milliseconds
// Orders must be at least this old before being cleaned up
const STALE_THRESHOLD_MS = 30 * 60 * 1000; // 30 minutes

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🧹 Starting stale pending order cleanup...");

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    // Calculate the cutoff time (30 minutes ago)
    const cutoffDate = new Date(Date.now() - STALE_THRESHOLD_MS);
    const cutoffISO = cutoffDate.toISOString();

    console.log(`📅 Cutoff date: ${cutoffISO}`);
    console.log(`📅 Orders created before this date with pending payment will be cleaned up`);

    // Find stale pending orders:
    // 1. payment_status = 'pending' (NEVER authorized or charged)
    // 2. Created more than 30 minutes ago
    // 3. Order status is 'placed' (initial state)
    const { data: stalePendingOrders, error: fetchError } = await supabaseAdmin
      .from("orders")
      .select("id, listing_id, buyer_id, seller_id, stripe_payment_intent_id, created_at")
      .eq("payment_status", "pending")
      .eq("order_status", "placed")
      .lt("created_at", cutoffISO);

    if (fetchError) {
      console.error("Error fetching stale pending orders:", fetchError);
      throw fetchError;
    }

    if (!stalePendingOrders || stalePendingOrders.length === 0) {
      console.log("✅ No stale pending orders found");
      return new Response(
        JSON.stringify({
          success: true,
          message: "No stale pending orders found",
          processed: 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`⏰ Found ${stalePendingOrders.length} stale pending order(s)`);

    let deleted = 0;
    let skipped = 0;
    const errors: string[] = [];

    for (const order of stalePendingOrders) {
      try {
        console.log(`\n🔄 Processing stale order: ${order.id}`);
        console.log(`   Created: ${order.created_at}`);
        console.log(`   Listing: ${order.listing_id}`);

        // SAFETY CHECK 1: If there's a Stripe PaymentIntent, verify it wasn't used
        if (order.stripe_payment_intent_id) {
          console.log(`   ⚠️ Order has PaymentIntent: ${order.stripe_payment_intent_id}`);
          
          try {
            const paymentIntent = await stripe.paymentIntents.retrieve(order.stripe_payment_intent_id);
            
            // If the payment was actually processed, DO NOT delete this order
            if (paymentIntent.status === "succeeded" || paymentIntent.status === "requires_capture") {
              console.log(`   ❌ SKIP: PaymentIntent is ${paymentIntent.status} - payment was processed`);
              console.log(`   ⚠️ This order should have payment_status updated, not deleted`);
              skipped++;
              continue;
            }
            
            // If payment is in a cancellable state, cancel it
            if (paymentIntent.status === "requires_payment_method" || paymentIntent.status === "requires_confirmation") {
              console.log(`   💳 Cancelling unused PaymentIntent: ${paymentIntent.status}`);
              try {
                await stripe.paymentIntents.cancel(order.stripe_payment_intent_id);
                console.log(`   ✅ PaymentIntent cancelled`);
              } catch (cancelError: any) {
                console.log(`   ⚠️ Could not cancel PaymentIntent: ${cancelError.message}`);
                // Continue anyway - the PaymentIntent will expire on its own
              }
            }
          } catch (stripeError: any) {
            console.log(`   ⚠️ Could not retrieve PaymentIntent: ${stripeError.message}`);
            // If we can't verify, safer to skip
            if (!stripeError.message?.includes("No such payment_intent")) {
              console.log(`   ❌ SKIP: Cannot verify PaymentIntent status`);
              skipped++;
              continue;
            }
            // PaymentIntent doesn't exist - safe to proceed
            console.log(`   ℹ️ PaymentIntent does not exist in Stripe - safe to cleanup`);
          }
        }

        // SAFETY CHECK 2: Double-check the order is still pending
        const { data: currentOrder, error: checkError } = await supabaseAdmin
          .from("orders")
          .select("payment_status, order_status")
          .eq("id", order.id)
          .single();

        if (checkError || !currentOrder) {
          console.log(`   ℹ️ Order no longer exists - already cleaned up`);
          continue;
        }

        if (currentOrder.payment_status !== "pending" || currentOrder.order_status !== "placed") {
          console.log(`   ❌ SKIP: Order state changed (payment: ${currentOrder.payment_status}, status: ${currentOrder.order_status})`);
          skipped++;
          continue;
        }

        // Delete the stale pending order
        const { error: deleteError } = await supabaseAdmin
          .from("orders")
          .delete()
          .eq("id", order.id)
          .eq("payment_status", "pending") // Extra safety: only delete if still pending
          .eq("order_status", "placed");

        if (deleteError) {
          console.error(`   ❌ Failed to delete order: ${deleteError.message}`);
          errors.push(`Order ${order.id}: ${deleteError.message}`);
          continue;
        }

        console.log(`   ✅ Order deleted`);
        deleted++;

        // Unarchive the listing if no other active orders exist
        if (order.listing_id) {
          try {
            // Check for other active orders on this listing
            const { data: otherOrders, error: otherError } = await supabaseAdmin
              .from("orders")
              .select("id")
              .eq("listing_id", order.listing_id)
              .not("order_status", "in", '("cancelled","completed")')
              .limit(1);

            if (otherError) {
              console.log(`   ⚠️ Could not check for other orders: ${otherError.message}`);
            } else if (!otherOrders || otherOrders.length === 0) {
              // No other active orders - safe to unarchive
              const { error: unarchiveError } = await supabaseAdmin
                .from("listings")
                .update({ archived: false })
                .eq("id", order.listing_id);

              if (!unarchiveError) {
                console.log(`   ✅ Listing unarchived`);
              } else {
                console.log(`   ⚠️ Could not unarchive listing: ${unarchiveError.message}`);
              }
            } else {
              console.log(`   ℹ️ Listing not unarchived - other active orders exist`);
            }
          } catch (listingError: any) {
            console.log(`   ⚠️ Error handling listing: ${listingError.message}`);
          }
        }

      } catch (orderError: any) {
        console.error(`   ❌ Error processing order ${order.id}: ${orderError.message}`);
        errors.push(`Order ${order.id}: ${orderError.message}`);
      }
    }

    console.log(`\n✅ Cleanup complete:`);
    console.log(`   Deleted: ${deleted}`);
    console.log(`   Skipped: ${skipped}`);
    console.log(`   Errors: ${errors.length}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Cleaned up ${deleted} stale pending orders`,
        deleted,
        skipped,
        total: stalePendingOrders.length,
        errors: errors.length > 0 ? errors : undefined,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error("Error cleaning up stale pending orders:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to cleanup stale pending orders",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
