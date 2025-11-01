// Supabase Edge Function to process payouts via Stripe Connect
// Supports both standard (bank account) and instant (debit card) payouts
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

    console.log(
      `💳 Processing payout for $${payout.net_amount_cents / 100}`
    );
    console.log(`   Type: ${payout.payout_type || "standard"}`);
    console.log(`   Method: ${payout.payout_method || "bank_account"}`);

    // NOTE: We use DESTINATION CHARGES, so money is already in the Connect account
    // No need to transfer - just create the payout directly
    console.log(`💳 Creating payout directly from Connect account (money already there from destination charge)...`);

    // Determine payout method and destination
    let payoutParams: any = {
      amount: payout.net_amount_cents,
      currency: "usd",
      description: `CampusLink payout for ${
        new Date().toISOString().split("T")[0]
      }`,
      metadata: {
        payout_id: payout_id,
        user_id: userId,
        payout_type: payout.payout_type || "standard",
      },
    };

    // Handle instant payouts to debit card
    if (
      payout.payout_type === "instant" &&
      payout.payout_method === "debit_card"
    ) {
      console.log("🚀 Processing INSTANT payout to debit card");

      // Get the user's saved debit card from Stripe
      // First, get their external accounts (debit cards)
      const externalAccounts = await stripe.accounts.listExternalAccounts(
        userProfile.stripe_connect_id,
        {
          object: "card",
          limit: 10,
        }
      );

      console.log(
        `   Found ${externalAccounts.data.length} external accounts`
      );

      // Find a card marked for instant payouts (or use the default)
      const debitCard = externalAccounts.data.find(
        (account: any) =>
          account.object === "card" &&
          account.available_payout_methods?.includes("instant")
      ) || externalAccounts.data[0];

      if (!debitCard) {
        console.error("❌ No debit card found for instant payout");
        throw new Error(
          "No debit card on file. Please add a debit card for instant payouts."
        );
      }

      console.log(`   Using card: ${debitCard.id} (****${debitCard.last4})`);

      // Set method to instant and specify the card
      payoutParams.method = "instant";
      payoutParams.destination = debitCard.id;
    } else {
      console.log("🏦 Processing STANDARD payout to bank account");
      // Standard payout - goes to default external account (bank)
      payoutParams.method = "standard";
    }

    // Create payout in Stripe
    const stripePayout = await stripe.payouts.create(payoutParams, {
      stripeAccount: userProfile.stripe_connect_id,
    });

    console.log(`✅ Stripe payout created: ${stripePayout.id}`);
    console.log(`   Method: ${stripePayout.method}`);
    console.log(`   Arrival: ${stripePayout.arrival_date}`);

    // Update payout record with Stripe transfer ID, payout ID and status
    const { error: updateError } = await supabaseAdmin
      .from("payouts")
      .update({
        stripe_payout_id: stripePayout.id,
        status: "processing",
        updated_at: new Date().toISOString(),
      })
      .eq("id", payout_id);

    if (updateError) {
      console.error("Error updating payout:", updateError);
      throw updateError;
    }

    console.log(`✅ Payout complete!`);
    console.log(`   Payout ID: ${stripePayout.id}`);
    console.log(`   Method: ${stripePayout.method}`);
    console.log(`   Status: processing`);
    console.log(`   Note: Money was already in Connect account from destination charge`);

    return new Response(
      JSON.stringify({
        success: true,
        payout_id: payout_id,
        stripe_payout_id: stripePayout.id,
        status: "processing",
        method: stripePayout.method,
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

