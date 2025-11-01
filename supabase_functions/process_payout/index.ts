// Supabase Edge Function to process payouts via Stripe Connect
// Deploy this function via Supabase Dashboard
//
// Required Environment Variables:
// - STRIPE_SECRET_KEY (your Stripe secret key)
// - SUPABASE_URL (automatically available)
// - SUPABASE_SERVICE_ROLE_KEY (automatically available)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get the authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("No authorization header");
    }

    // Extract the JWT token
    const token = authHeader.replace("Bearer ", "");

    // Create Supabase client with service role key for admin operations
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Verify the user's JWT token and get user ID
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      console.error("Auth error:", authError);
      throw new Error("Invalid or expired token");
    }

    const userId = user.id;
    console.log(`🔄 Processing payout for user: ${userId}`);

    // Parse request body
    const body = await req.json();
    const { payout_id } = body;

    if (!payout_id) {
      throw new Error("payout_id is required");
    }

    // Get payout record
    const { data: payout, error: payoutError } = await supabaseAdmin
      .from("payouts")
      .select("*")
      .eq("id", payout_id)
      .eq("user_id", userId) // Ensure user owns this payout
      .single();

    if (payoutError || !payout) {
      throw new Error("Payout not found or unauthorized");
    }

    // Check if payout is already processed
    if (payout.status !== "pending") {
      return new Response(
        JSON.stringify({
          error: `Payout is already ${payout.status}`,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        }
      );
    }

    // Get user's Stripe Connect account
    const { data: userProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("stripe_connect_id")
      .eq("id", userId)
      .single();

    if (profileError || !userProfile?.stripe_connect_id) {
      throw new Error("Stripe Connect account not found");
    }

    // Initialize Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    console.log(`💳 Creating Stripe payout for ${payout.net_amount_cents / 100}`);

    // Create payout in Stripe
    // Note: Payouts go to the default external account (bank account) that was set up during onboarding
    const stripePayout = await stripe.payouts.create(
      {
        amount: payout.net_amount_cents, // Amount in cents
        currency: "usd",
        description: `CampusLink payout for ${new Date().toISOString().split("T")[0]}`,
        metadata: {
          payout_id: payout_id,
          user_id: userId,
        },
      },
      {
        stripeAccount: userProfile.stripe_connect_id, // Important: Create payout on the Connect account
      }
    );

    console.log(`✅ Stripe payout created: ${stripePayout.id}`);

    // Update payout record with Stripe payout ID and status
    const { error: updateError } = await supabaseAdmin
      .from("payouts")
      .update({
        stripe_payout_id: stripePayout.id,
        status: "processing", // Will be updated to 'completed' via webhook when Stripe confirms
        updated_at: new Date().toISOString(),
      })
      .eq("id", payout_id);

    if (updateError) {
      console.error("Error updating payout:", updateError);
      throw updateError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        payout_id: payout_id,
        stripe_payout_id: stripePayout.id,
        status: "processing",
        estimated_arrival: stripePayout.arrival_date
          ? new Date(stripePayout.arrival_date * 1000).toISOString()
          : null,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error processing payout:", error);

    return new Response(
      JSON.stringify({
        error: error.message || "Failed to process payout",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

