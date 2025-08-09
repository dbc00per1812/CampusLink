// Supabase Edge Function: create_payment_intent
// - Creates a Stripe PaymentIntent (manual capture)
// - Inserts a row into the payments table
// - Returns the PaymentIntent client_secret to the caller

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

type CreatePaymentIntentRequest = {
  listing_id: string;
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

async function fetchListing(listingId: string): Promise<{ id: string; price: number; user_id: string }> {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("listings")
    .select("id, price, user_id")
    .eq("id", listingId)
    .single();

  if (error || !data) {
    throw new Error("Listing not found");
  }

  // Expect price to be in the smallest currency unit (e.g., cents). If not, adjust before calling Stripe.
  return data as { id: string; price: number; user_id: string };
}

async function createPaymentIntent(amountInCents: number, metadata: Record<string, string>): Promise<Stripe.Response<Stripe.PaymentIntent>> {
  const stripe = getStripe();
  const paymentIntent = await stripe.paymentIntents.create({
    amount: amountInCents,
    currency: "usd",
    capture_method: "manual",
    automatic_payment_methods: { enabled: true },
    metadata,
  });
  return paymentIntent;
}

async function insertPaymentRow(params: {
  buyerId: string;
  sellerId: string;
  amountInCents: number;
  paymentIntentId: string;
}): Promise<void> {
  const supabase = getSupabaseServiceClient();
  const { error } = await supabase.from("payments").insert({
    buyer_id: params.buyerId,
    seller_id: params.sellerId,
    amount: params.amountInCents,
    payment_intent_id: params.paymentIntentId,
    status: "requires_capture",
  });
  if (error) {
    throw new Error(`Failed to insert payment row: ${error.message}`);
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
    const body = (await req.json()) as CreatePaymentIntentRequest;
    const listingId = body?.listing_id;
    if (!listingId || typeof listingId !== "string") {
      return jsonResponse(400, { error: "Missing or invalid 'listing_id'" });
    }

    const listing = await fetchListing(listingId);
    if (listing.user_id === userId) {
      return jsonResponse(400, { error: "Sellers cannot purchase their own listings" });
    }

    // Convert price from dollars to cents (Stripe expects cents)
    const amountInCents = Math.round(Number(listing.price) * 100);
    if (!Number.isFinite(amountInCents) || amountInCents <= 0) {
      return jsonResponse(400, { error: "Listing price is invalid" });
    }

    const paymentIntent = await createPaymentIntent(amountInCents, {
      listing_id: listing.id,
      buyer_id: userId,
      seller_id: listing.user_id,
    });

    await insertPaymentRow({
      buyerId: userId,
      sellerId: listing.user_id,
      amountInCents,
      paymentIntentId: paymentIntent.id,
    });

    return jsonResponse(200, { client_secret: paymentIntent.client_secret });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(400, { error: message });
  }
});


