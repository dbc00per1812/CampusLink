// Supabase Edge Function to capture a Stripe PaymentIntent
// Called when buyer confirms delivery to release funds to seller

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

    console.log(`💰 Capturing payment: ${payment_intent_id}`);

    // Initialize Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    // Capture the payment
    const paymentIntent = await stripe.paymentIntents.capture(payment_intent_id);

    console.log(`✅ Payment captured successfully`);
    console.log(`   Status: ${paymentIntent.status}`);
    console.log(`   Amount: $${paymentIntent.amount / 100}`);

    return new Response(
      JSON.stringify({
        success: true,
        payment_intent_id: paymentIntent.id,
        status: paymentIntent.status,
        amount: paymentIntent.amount,
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

