// Supabase Edge Function to cancel a Stripe PaymentIntent
// Called when an order is cancelled to void the authorization
// This releases the hold on the buyer's card immediately

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
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
    // Parse request body
    const { payment_intent_id } = await req.json();
    
    if (!payment_intent_id) {
      throw new Error("payment_intent_id is required");
    }

    console.log(`🚫 Canceling payment intent: ${payment_intent_id}`);

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

