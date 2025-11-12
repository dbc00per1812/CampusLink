// Get actual Stripe Connect balance - THE ONLY SOURCE OF TRUTH

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("No authorization header");

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
    if (authError || !user) throw new Error("Invalid token");

    // Get Stripe Connect ID
    const { data: userProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("stripe_connect_id")
      .eq("id", user.id)
      .single();

    if (profileError || !userProfile?.stripe_connect_id) {
      return new Response(
        JSON.stringify({
          available_for_standard_cents: 0,
          available_for_instant_cents: 0,
          pending_cents: 0,
          total_cents: 0,
          error: "No Stripe Connect account"
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Get ACTUAL balance from Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    const balance = await stripe.balance.retrieve({
      stripeAccount: userProfile.stripe_connect_id,
    });

    console.log("✅ Retrieved Stripe balance:", balance);

    // Available = what can be paid out now
    const availableAmount = balance.available.reduce((sum, b) => sum + b.amount, 0);
    
    // Pending = what's coming soon
    const pendingAmount = balance.pending.reduce((sum, b) => sum + b.amount, 0);

    // Instant available (if they have instant payout capability)
    const instantAmount = balance.instant_available?.[0]?.amount || availableAmount;

    return new Response(
      JSON.stringify({
        available_for_standard_cents: availableAmount,
        available_for_instant_cents: instantAmount,
        pending_cents: pendingAmount,
        total_cents: availableAmount + pendingAmount,
        currency: "usd",
        connect_account_id: userProfile.stripe_connect_id,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error) {
    console.error("Error getting balance:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    );
  }
});

