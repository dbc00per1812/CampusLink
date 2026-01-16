// Supabase Edge Function to capture a Stripe PaymentIntent
// Called when buyer confirms delivery to release funds to seller
// SECURITY: Validates authorization before capturing
// DEFERRED ONBOARDING: If seller has no Connect, records pending payout for later transfer

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ===== AUTHORIZATION CHECK =====
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Missing authorization header");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      throw new Error("Invalid auth token");
    }

    // Parse request body
    const { payment_intent_id } = await req.json();
    
    if (!payment_intent_id) {
      throw new Error("payment_intent_id is required");
    }

    console.log(`💰 Capturing payment: ${payment_intent_id}`);
    console.log(`👤 Requested by user: ${user.id}`);

    // ===== VERIFY ORDER OWNERSHIP =====
    // Look up order by payment intent to verify the caller is authorized
    const { data: order, error: orderError } = await supabaseAdmin
      .from("orders")
      .select("id, buyer_id, seller_id, seller_price_cents, order_status")
      .eq("stripe_payment_intent_id", payment_intent_id)
      .single();

    if (orderError || !order) {
      console.error("Order lookup failed:", orderError);
      throw new Error("Order not found for this payment intent");
    }

    // Only buyer can capture (on delivery confirmation) or seller (on PIN verification)
    // This provides flexibility for both flows
    if (order.buyer_id !== user.id && order.seller_id !== user.id) {
      console.error(`Unauthorized: User ${user.id} is not buyer (${order.buyer_id}) or seller (${order.seller_id})`);
      throw new Error("Unauthorized: You are not a participant in this order");
    }

    console.log(`✅ Authorization verified - Order: ${order.id}`);
    console.log(`   Buyer: ${order.buyer_id}`);
    console.log(`   Seller: ${order.seller_id}`);
    console.log(`   Caller: ${user.id} (${user.id === order.buyer_id ? 'buyer' : 'seller'})`);

    // Initialize Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    // Retrieve PaymentIntent to check if it used destination charges
    const paymentIntentBefore = await stripe.paymentIntents.retrieve(payment_intent_id);
    const usedDestinationCharge = !!paymentIntentBefore.transfer_data?.destination;
    
    console.log(`   Used destination charge: ${usedDestinationCharge}`);

    // Capture the payment
    const paymentIntent = await stripe.paymentIntents.capture(payment_intent_id);

    console.log(`✅ Payment captured successfully`);
    console.log(`   Status: ${paymentIntent.status}`);
    console.log(`   Amount: $${paymentIntent.amount / 100}`);

    // ===== DEFERRED ONBOARDING: Track pending payout if no destination charge =====
    if (!usedDestinationCharge) {
      // Seller didn't have Stripe Connect set up - funds went to platform account
      // Record pending payout so we can transfer when they complete onboarding
      const sellerAmount = order.seller_price_cents || Math.round(paymentIntent.amount * 0.95); // Fallback to 95% if not set
      
      console.log(`📝 Recording pending payout for seller ${order.seller_id}: $${sellerAmount / 100}`);
      
      const { error: pendingError } = await supabaseAdmin
        .from("pending_seller_payouts")
        .insert({
          seller_id: order.seller_id,
          order_id: order.id,
          amount_cents: sellerAmount,
          payment_intent_id: payment_intent_id,
          status: "pending",
        });

      if (pendingError) {
        // Log but don't fail the capture - money is safe, just not tracked
        console.error(`⚠️ Failed to record pending payout: ${pendingError.message}`);
      } else {
        console.log(`✅ Pending payout recorded - seller will receive funds after completing Stripe setup`);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        payment_intent_id: paymentIntent.id,
        status: paymentIntent.status,
        amount: paymentIntent.amount,
        pending_payout: !usedDestinationCharge,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error capturing payment:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to capture payment",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
