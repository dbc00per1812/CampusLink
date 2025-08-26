// Supabase Edge Function: connect_onboarding
// Creates or retrieves Stripe Connect account and generates onboarding link

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

type OnboardingRequest = {
  return_url?: string;
  refresh_url?: string;
};

type HttpJson = Record<string, unknown> | unknown[] | string | number | boolean | null;

function jsonResponse(status: number, body: HttpJson, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      ...init.headers,
    },
  });
}

function getStripe(): Stripe {
  const secretKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!secretKey) {
    throw new Error("Missing STRIPE_SECRET_KEY environment variable");
  }
  return new Stripe(secretKey, { apiVersion: "2024-06-20" });
}

function getSupabaseServiceClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  return createClient(supabaseUrl, serviceRoleKey);
}

function getSupabaseAuthClient(req: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
  }
  return createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: req.headers.get("Authorization") ?? "",
      },
    },
  });
}

function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      },
    });
  }
  return null;
}

async function getAuthenticatedUserId(req: Request): Promise<string> {
  const supabase = getSupabaseAuthClient(req);
  const { data, error } = await supabase.auth.getUser();
  if (error || !data?.user?.id) {
    throw new Error("Unauthorized: unable to resolve authenticated user");
  }
  return data.user.id;
}

async function getUserProfile(userId: string) {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("users")
    .select("stripe_connect_id, email, name")
    .eq("id", userId)
    .single();
  
  if (error || !data) {
    throw new Error("User profile not found");
  }
  
  return data as { stripe_connect_id: string | null; email: string; name: string | null };
}

async function updateUserStripeConnectId(userId: string, connectId: string) {
  const supabase = getSupabaseServiceClient();
  const { error } = await supabase
    .from("users")
    .update({ stripe_connect_id: connectId })
    .eq("id", userId);
  
  if (error) {
    throw new Error(`Failed to update user profile: ${error.message}`);
  }
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  const maybeOptions = handleOptions(req);
  if (maybeOptions) return maybeOptions;

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  try {
    // Get authenticated user
    const userId = await getAuthenticatedUserId(req);
    const userProfile = await getUserProfile(userId);
    
    // Parse request body
    const body = (await req.json()) as OnboardingRequest;
    const returnUrl = body.return_url || "campuslink://settings/payout-success";
    const refreshUrl = body.refresh_url || "campuslink://settings/payout-refresh";

    const stripe = getStripe();
    let accountId = userProfile.stripe_connect_id;

    // Create Stripe Connect account if doesn't exist
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: "express",
        country: "US",
        email: userProfile.email,
        capabilities: {
          transfers: { requested: true },
        },
        business_type: "individual",
        business_profile: {
          product_description: "Campus marketplace seller",
        },
        metadata: {
          user_id: userId,
        },
      });
      
      accountId = account.id;
      
      // Save the Connect account ID
      await updateUserStripeConnectId(userId, accountId);
    } else {
      // Retrieve existing account to check status
      const account = await stripe.accounts.retrieve(accountId);
      
      // If already onboarded, return success without creating new link
      if (account.details_submitted && account.payouts_enabled) {
        return jsonResponse(200, {
          onboarding_complete: true,
          account_id: accountId,
          payouts_enabled: account.payouts_enabled,
          message: "Account already onboarded",
        });
      }
    }

    // Create account onboarding link
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: refreshUrl,
      return_url: returnUrl,
      type: "account_onboarding",
    });

    return jsonResponse(200, {
      onboarding_url: accountLink.url,
      account_id: accountId,
      expires_at: accountLink.expires_at,
      onboarding_complete: false,
    });
    
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(400, { error: message });
  }
});