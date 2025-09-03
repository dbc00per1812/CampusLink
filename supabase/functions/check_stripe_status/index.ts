import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@12.18.0?target=deno";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

interface User {
  id: string;
  stripe_connect_id?: string;
  stripe_payouts_enabled?: boolean;
  stripe_details_submitted?: boolean;
}

function jsonResponse(status: number, data: any): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    },
  });
}

function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }
  return null;
}

async function getAuthenticatedUserId(req: Request): Promise<string> {
  const authHeader = req.headers.get("authorization");
  if (!authHeader) {
    throw new Error("Missing authorization header");
  }

  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error } = await supabase.auth.getUser(token);
  
  if (error || !user) {
    throw new Error("Invalid or expired token");
  }
  
  return user.id;
}

async function getUserProfile(userId: string): Promise<User> {
  const { data, error } = await supabase
    .from("users")
    .select("id, stripe_connect_id, stripe_payouts_enabled, stripe_details_submitted")
    .eq("id", userId)
    .single();

  if (error) {
    throw new Error(`Failed to fetch user profile: ${error.message}`);
  }

  return data;
}

async function updateUserStripeStatus(userId: string, payoutsEnabled: boolean, detailsSubmitted: boolean): Promise<void> {
  const { error } = await supabase
    .from("users")
    .update({
      stripe_payouts_enabled: payoutsEnabled,
      stripe_details_submitted: detailsSubmitted,
      updated_at: new Date().toISOString(),
    })
    .eq("id", userId);

  if (error) {
    throw new Error(`Failed to update user Stripe status: ${error.message}`);
  }
}

serve(async (req: Request) => {
  const maybeOptions = handleOptions(req);
  if (maybeOptions) return maybeOptions;

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  try {
    // Authenticate user
    const userId = await getAuthenticatedUserId(req);
    
    // Get user profile
    const userProfile = await getUserProfile(userId);
    
    if (!userProfile.stripe_connect_id) {
      return jsonResponse(200, {
        payouts_enabled: false,
        details_submitted: false,
        message: "No Stripe Connect account found"
      });
    }

    // Check current Stripe account status
    const account = await stripe.accounts.retrieve(userProfile.stripe_connect_id);
    
    const currentPayoutsEnabled = account.payouts_enabled ?? false;
    const currentDetailsSubmitted = account.details_submitted ?? false;

    // Update user profile if status has changed
    if (
      userProfile.stripe_payouts_enabled !== currentPayoutsEnabled ||
      userProfile.stripe_details_submitted !== currentDetailsSubmitted
    ) {
      await updateUserStripeStatus(userId, currentPayoutsEnabled, currentDetailsSubmitted);
      console.log(`Updated user ${userId} Stripe status: payouts=${currentPayoutsEnabled}, details=${currentDetailsSubmitted}`);
    }

    return jsonResponse(200, {
      payouts_enabled: currentPayoutsEnabled,
      details_submitted: currentDetailsSubmitted,
      account_id: userProfile.stripe_connect_id,
      message: "Status checked and updated"
    });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Check Stripe status error:", err);
    
    return jsonResponse(400, { 
      error: message,
      details: err instanceof Error ? err.stack : undefined,
    });
  }
});
