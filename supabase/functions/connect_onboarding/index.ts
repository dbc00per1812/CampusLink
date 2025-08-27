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
    // Get authenticated user from JWT
    const supabase = getSupabaseAuthClient(req);
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user?.id) {
      return jsonResponse(401, { error: "Unauthorized: unable to resolve authenticated user" });
    }
    
    const userId = user.id;
    
    // Simple test response to see if we get this far
    return jsonResponse(200, {
      message: "Authentication successful",
      userId: userId,
      timestamp: new Date().toISOString()
    });
    
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Connect onboarding error:", err);
    return jsonResponse(400, { error: message, details: err instanceof Error ? err.stack : undefined });
  }
});