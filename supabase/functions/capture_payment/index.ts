// Supabase Edge Function: capture_payment
// - Validates that the requester is the seller for the given payment
// - Captures the Stripe PaymentIntent
// - Updates the payments row to reflect capture (final status also updated by webhook)

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

type CapturePaymentRequest = {
  payment_intent_id: string;
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
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variable");
  }
  return createClient(supabaseUrl, serviceRoleKey);
}

function getSupabaseAuthClient(req: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variable");
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

async function getPaymentByIntentId(paymentIntentId: string): Promise<{ id: string; seller_id: string; status: string }> {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("payments")
    .select("id, seller_id, status")
    .eq("payment_intent_id", paymentIntentId)
    .single();
  if (error || !data) {
    throw new Error("Payment record not found");
  }
  return data as { id: string; seller_id: string; status: string };
}

async function markPaymentCaptured(paymentId: string): Promise<void> {
  const supabase = getSupabaseServiceClient();
  const { error } = await supabase
    .from("payments")
    .update({ status: "captured" })
    .eq("id", paymentId);
  if (error) {
    throw new Error(`Failed to update payment status: ${error.message}`);
  }
}

Deno.serve(async (req: Request) => {
  const maybeOptions = handleOptions(req);
  if (maybeOptions) return maybeOptions;

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  try {
    const userId = await getAuthenticatedUserId(req);
    const body = (await req.json()) as CapturePaymentRequest;
    const paymentIntentId = body?.payment_intent_id;
    if (!paymentIntentId || typeof paymentIntentId !== "string") {
      return jsonResponse(400, { error: "Missing or invalid 'payment_intent_id'" });
    }

    const payment = await getPaymentByIntentId(paymentIntentId);
    if (payment.seller_id !== userId) {
      return jsonResponse(403, { error: "Only the seller can capture this payment" });
    }

    const stripe = getStripe();
    await stripe.paymentIntents.capture(paymentIntentId);

    // Optimistic update (final authoritative status will come via webhook)
    await markPaymentCaptured(payment.id);

    return jsonResponse(200, { status: "captured" });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(400, { error: message });
  }
});


