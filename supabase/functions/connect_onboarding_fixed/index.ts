// Supabase Edge Function for Stripe Connect onboarding
// This creates Connect accounts and generates onboarding links
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
    if (!authHeader) {
      throw new Error("No authorization header");
    }

    // Extract the JWT token
    const token = authHeader.replace("Bearer ", "");

    // Create Supabase client with service role key
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
    const userEmail = user.email;
    console.log(`🔄 Connect onboarding for user: ${userId} (${userEmail})`);

    // Parse request body
    const body = await req.json();
    const { return_url, refresh_url } = body;

    if (!return_url || !refresh_url) {
      throw new Error("return_url and refresh_url are required");
    }

    // Get user's profile
    const { data: userProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("stripe_connect_id, email, full_name")
      .eq("id", userId)
      .single();

    if (profileError) {
      console.error("Profile error:", profileError);
      throw new Error("Failed to load user profile");
    }

    // Initialize Stripe
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    let accountId = userProfile.stripe_connect_id;
    let account: Stripe.Account;

    // Create Connect account if doesn't exist
    if (!accountId) {
      console.log("📝 Creating new Stripe Connect account...");

      // Create account with ALL required capabilities upfront
      account = await stripe.accounts.create({
        type: "express",
        email: userProfile.email || userEmail,
        capabilities: {
          // Enable all capabilities needed for the platform
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_type: "individual",
        settings: {
          payouts: {
            // Request instant payout capability (requires debit card)
            schedule: {
              interval: "manual", // Manual payouts allow instant payouts
            },
          },
        },
        metadata: {
          user_id: userId,
          platform: "CampusLink",
        },
      });

      accountId = account.id;
      console.log(`✅ Created Connect account: ${accountId}`);

      // Save to database
      const { error: updateError } = await supabaseAdmin
        .from("users")
        .update({
          stripe_connect_id: accountId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (updateError) {
        console.error("Failed to save stripe_connect_id:", updateError);
        // Don't throw - account is created in Stripe
      }
    } else {
      console.log(`✅ Existing Connect account: ${accountId}`);
      
      // Retrieve existing account
      account = await stripe.accounts.retrieve(accountId);

      // Update capabilities if missing
      const needsCapabilityUpdate = 
        !account.capabilities?.transfers || 
        account.capabilities.transfers === "inactive";

      if (needsCapabilityUpdate) {
        console.log("🔧 Updating account capabilities...");
        account = await stripe.accounts.update(accountId, {
          capabilities: {
            card_payments: { requested: true },
            transfers: { requested: true },
          },
        });
      }
    }

    // Check if onboarding is complete
    const onboardingComplete =
      account.details_submitted &&
      account.charges_enabled &&
      account.payouts_enabled;

    if (onboardingComplete) {
      console.log("✅ Onboarding already complete!");
      return new Response(
        JSON.stringify({
          onboarding_complete: true,
          account_id: accountId,
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // Generate Account Link for onboarding
    console.log("🔗 Creating Account Link for onboarding...");
    console.log("   Requesting collection of: bank account + debit card (for instant payouts)");
    
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: refresh_url,
      return_url: return_url,
      type: "account_onboarding",
      collect: "eventually_due", // Collect ALL required information including external accounts
      collection_options: {
        fields: "eventually_due",
        future_requirements: "include", // Also collect future requirements (like instant payout cards)
      },
    });

    console.log(`✅ Account Link created: ${accountLink.url}`);

    return new Response(
      JSON.stringify({
        onboarding_url: accountLink.url,
        account_id: accountId,
        onboarding_complete: false,
        expires_at: accountLink.expires_at,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("❌ Error in connect_onboarding:", error);
    console.error("❌ Error type:", error.constructor.name);
    console.error("❌ Error message:", error.message);
    if (error.type) console.error("❌ Stripe error type:", error.type);
    if (error.code) console.error("❌ Stripe error code:", error.code);

    return new Response(
      JSON.stringify({
        error: error.message || "Failed to create onboarding link",
        error_type: error.type || error.constructor.name,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

