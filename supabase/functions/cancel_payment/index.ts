// Supabase Edge Function to cancel a Stripe PaymentIntent
// Called when an order is cancelled to void the authorization
// This releases the hold on the buyer's card immediately
// SECURITY: Validates authorization before cancelling

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

    console.log(`🚫 Canceling payment intent: ${payment_intent_id}`);
    console.log(`👤 Requested by user: ${user.id}`);

    // ===== VERIFY ORDER OWNERSHIP =====
    // Look up order by payment intent to verify the caller is authorized
    const { data: order, error: orderError } = await supabaseAdmin
      .from("orders")
      .select("id, buyer_id, seller_id, order_status")
      .eq("stripe_payment_intent_id", payment_intent_id)
      .single();

    if (orderError || !order) {
      console.error("Order lookup failed:", orderError);
      throw new Error("Order not found for this payment intent");
    }

    // Both buyer and seller can cancel (buyer can cancel before seller confirms, 
    // seller might cancel if they can't fulfill)
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

    // Cancel the payment intent (voids the auth)
    const paymentIntent = await stripe.paymentIntents.cancel(payment_intent_id);

    console.log(`✅ Payment cancelled/voided successfully`);
    console.log(`   Status: ${paymentIntent.status}`);

    return new Response(
      JSON.stringify({
        success: true,
        payment_intent_id: paymentIntent.id,
        status: paymentIntent.status,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error canceling payment:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to cancel payment",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
