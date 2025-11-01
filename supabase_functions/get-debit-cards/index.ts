// Supabase Edge Function to get user's saved debit cards
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
    console.log(`💳 Getting debit cards for user: ${userId}`);

    // Get user's Stripe Connect account
    const { data: userProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("stripe_connect_id")
      .eq("id", userId)
      .single();

    if (profileError || !userProfile?.stripe_connect_id) {
      return new Response(
        JSON.stringify({
          cards: [],
          message: "No Stripe Connect account found",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // Initialize Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    // Get external accounts (cards)
    const externalAccounts = await stripe.accounts.listExternalAccounts(
      userProfile.stripe_connect_id,
      {
        object: "card",
        limit: 10,
      }
    );

    // Format cards for response
    const cards = externalAccounts.data
      .filter((account: any) => account.object === "card")
      .map((card: any) => ({
        id: card.id,
        last4: card.last4,
        brand: card.brand,
        exp_month: card.exp_month,
        exp_year: card.exp_year,
        funding: card.funding,
        instant_available: card.available_payout_methods?.includes("instant") ||
          false,
        is_default: card.default_for_currency || false,
      }));

    console.log(`✅ Found ${cards.length} debit cards`);

    return new Response(
      JSON.stringify({
        cards: cards,
        count: cards.length,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error getting debit cards:", error);

    return new Response(
      JSON.stringify({
        error: error.message || "Failed to get debit cards",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

