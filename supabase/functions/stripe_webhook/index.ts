// Supabase Edge Function: stripe_webhook
// - Verifies Stripe signature
// - Processes relevant events and updates the payments table

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

type HttpJson = Record<string, unknown> | unknown[] | string | number | boolean | null;

function jsonResponse(status: number, body: HttpJson, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
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

async function updatePaymentStatusByIntentId(paymentIntentId: string, status: string, extra: Record<string, unknown> = {}): Promise<void> {
  const supabase = getSupabaseServiceClient();
  const { error } = await supabase
    .from("payments")
    .update({ status, ...extra })
    .eq("payment_intent_id", paymentIntentId);
  if (error) {
    throw new Error(`Failed to update payment status: ${error.message}`);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "content-type, stripe-signature",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  const stripe = getStripe();
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!webhookSecret) {
    return jsonResponse(500, { error: "Missing STRIPE_WEBHOOK_SECRET" });
  }

  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return jsonResponse(400, { error: "Missing Stripe-Signature header" });
  }

  const payload = await req.text();

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(payload, signature, webhookSecret);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(400, { error: `Webhook signature verification failed: ${message}` });
  }

  try {
    switch (event.type) {
      case "payment_intent.succeeded": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "succeeded");
        break;
      }
      case "payment_intent.payment_failed": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "failed");
        break;
      }
      case "payment_intent.canceled": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "canceled");
        break;
      }
      case "payment_intent.requires_action": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "requires_action");
        break;
      }
      case "payment_intent.processing": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "processing");
        break;
      }
      case "payment_intent.amount_capturable_updated": {
        const pi = event.data.object as Stripe.PaymentIntent;
        await updatePaymentStatusByIntentId(pi.id, "requires_capture");
        break;
      }
      case "charge.dispute.created": {
        const charge = event.data.object as Stripe.Charge;
        const paymentIntentId = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id ?? "";
        if (paymentIntentId) {
          await updatePaymentStatusByIntentId(paymentIntentId, "dispute_created");
        }
        break;
      }
      default: {
        // For unhandled events, do nothing but acknowledge
        break;
      }
    }

    return jsonResponse(200, { received: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(400, { error: message });
  }
});


