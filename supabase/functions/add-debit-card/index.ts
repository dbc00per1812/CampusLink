// Supabase Edge Function to add debit card for instant payouts
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

  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        error: `Method ${req.method} not allowed. Use POST.`,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 405,
      }
    );
  }

  try {
    // Get the authorization header
    const authHeader = req.headers.get("Authorization");
    console.log(`🔐 Auth header present: ${!!authHeader}`);
    console.log(`🔐 Auth header length: ${authHeader?.length || 0}`);
    
    if (!authHeader) {
      console.error("❌ No authorization header found");
      console.log("Available headers:", JSON.stringify(Array.from(req.headers.entries())));
      throw new Error("No authorization header");
    }

    // Extract the JWT token
    const token = authHeader.replace("Bearer ", "");
    console.log(`🔐 Token extracted, length: ${token.length}, starts with: ${token.substring(0, 20)}...`);

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

    console.log(`🔐 Verifying user token with Supabase...`);
    
    // Verify the user's JWT token and get user ID
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      console.error("❌ Auth verification failed");
      console.error("Auth error type:", authError?.name);
      console.error("Auth error message:", authError?.message);
      console.error("Auth error details:", JSON.stringify(authError));
      console.error("User object:", JSON.stringify(user));
      throw new Error(`Authentication failed: ${authError?.message || 'Unknown error'}`);
    }
    
    console.log(`✅ User authenticated: ${user.id}`);

    const userId = user.id;
    console.log(`💳 Adding debit card for user: ${userId}`);

    // Parse request body
    const body = await req.json();
    const { token_id } = body; // Stripe token from mobile app

    if (!token_id) {
      throw new Error("token_id is required");
    }

    // Get user's Stripe Connect account
    const { data: userProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("stripe_connect_id")
      .eq("id", userId)
      .single();

    if (profileError || !userProfile?.stripe_connect_id) {
      throw new Error("Stripe Connect account not found. Please complete payout setup first.");
    }

    // Initialize Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    console.log(`🔄 Creating external account with token: ${token_id}`);
    
    // First, retrieve the token to get card details
    const tokenDetails = await stripe.tokens.retrieve(token_id);
    console.log(`Token details:`, JSON.stringify(tokenDetails));
    
    if (tokenDetails.type !== 'card' || !tokenDetails.card) {
      throw new Error('Invalid token type. Expected card token.');
    }
    
    const cardInfo = tokenDetails.card;
    console.log(`Card info: ${cardInfo.brand} ****${cardInfo.last4}, funding: ${cardInfo.funding}`);

    // For Connect accounts, we need to create the external account using the token
    let createdAccount: any;
    try {
      createdAccount = await stripe.accounts.createExternalAccount(
        userProfile.stripe_connect_id,
        {
          external_account: token_id,
        }
      );
      console.log(`✅ External account created successfully: ${createdAccount.id}`);
    } catch (stripeError: any) {
      console.error(`❌ Stripe API error:`, stripeError);
      console.error(`Full error details:`, JSON.stringify(stripeError, null, 2));
      
      // If token method doesn't work, provide detailed error
      throw new Error(
        `Stripe error: ${stripeError.message || 'Unknown error'}. ` +
        `Note: Adding cards to Connect accounts requires completing onboarding first. ` +
        `Please ensure Stripe Connect setup is complete.`
      );
    }

    console.log(`✅ Debit card added: ${createdAccount.id}`);

    // Verify it's a debit card and supports instant payouts
    if (createdAccount.object === "card") {
      const card = createdAccount as any;
      console.log(`   Card: ****${card.last4}`);
      console.log(`   Brand: ${card.brand}`);
      console.log(`   Funding: ${card.funding}`); // Should be "debit"
      console.log(
        `   Instant payouts: ${card.available_payout_methods?.includes("instant")}`
      );

      // Check if it's actually a debit card
      if (card.funding !== "debit") {
        // Remove the card since it's not a debit card
        await stripe.accounts.deleteExternalAccount(
          userProfile.stripe_connect_id,
          createdAccount.id
        );
        throw new Error(
          "Only debit cards are supported for instant payouts. Credit cards cannot be used."
        );
      }

      // Check if instant payouts are available
      if (!card.available_payout_methods?.includes("instant")) {
        console.warn(
          "⚠️ This debit card may not support instant payouts"
        );
      }
    }

    // Update user profile to mark that they have a debit card
    const { error: updateError } = await supabaseAdmin
      .from("users")
      .update({
        has_debit_card: true,
        updated_at: new Date().toISOString(),
      })
      .eq("id", userId);

    if (updateError) {
      console.error("Error updating user profile:", updateError);
      // Don't throw - card is already added to Stripe
    }

    return new Response(
      JSON.stringify({
        success: true,
        card_id: createdAccount.id,
        last4: createdAccount.object === "card"
          ? (createdAccount as any).last4
          : null,
        brand: createdAccount.object === "card"
          ? (createdAccount as any).brand
          : null,
        instant_available: createdAccount.object === "card"
          ? (createdAccount as any).available_payout_methods?.includes(
            "instant",
          )
          : false,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("❌ Error adding debit card:", error);
    console.error("❌ Error type:", error.constructor.name);
    console.error("❌ Error message:", error.message);
    if (error.type) console.error("❌ Stripe error type:", error.type);
    if (error.code) console.error("❌ Stripe error code:", error.code);
    if (error.param) console.error("❌ Stripe error param:", error.param);

    // Return detailed error message
    let errorMessage = error.message || "Failed to add debit card";
    
    // Add more context for Stripe errors
    if (error.type === "StripeInvalidRequestError") {
      errorMessage = `Stripe error: ${error.message}`;
    }

    return new Response(
      JSON.stringify({
        error: errorMessage,
        error_type: error.type || error.constructor.name,
        error_code: error.code,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

