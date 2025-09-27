// Supabase Edge Function: create_offer_payment_intent
// Creates a Stripe PaymentIntent for accepting offers with custom amounts

import Stripe from "npm:stripe@14.25.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

interface CreateOfferPaymentIntentRequest {
  offer_id: string;
  buyer_id: string;
}

async function getAuthenticatedUserId(req: Request): Promise<string> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new Error("No authorization header");
  
  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error } = await supabase.auth.getUser(token);
  
  if (error || !user) throw new Error("Invalid auth token");
  return user.id;
}

async function fetchOffer(offerId: string) {
  const { data, error } = await supabase
    .from("offers")
    .select("*, seek_listing:listings!offers_seek_listing_id_fkey(id, user_id)")
    .eq("id", offerId)
    .single();
    
  if (error || !data) {
    throw new Error(`Offer not found: ${offerId}`);
  }
  
  if (data.status !== "pending") {
    throw new Error("Offer has already been processed");
  }
  
  return data;
}

Deno.serve(async (req: Request) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await getAuthenticatedUserId(req);
    const body = await req.json() as CreateOfferPaymentIntentRequest;
    
    if (!body.offer_id) {
      throw new Error("Missing offer_id");
    }
    
    // Fetch offer details
    const offer = await fetchOffer(body.offer_id);
    
    // Verify the current user is the seeker (buyer)
    if (offer.seeker_id !== userId) {
      throw new Error("Unauthorized: Only the seeker can accept this offer");
    }
    
    // Get the offer amount
    const amountInCents = offer.price_cents;
    if (!amountInCents || amountInCents <= 0) {
      throw new Error("Invalid offer amount");
    }
    
    // Calculate Stripe fees
    const stripeFeePercentage = 0.029; // 2.9%
    const stripeFeeFixed = 30; // 30 cents
    const stripeFee = Math.round(amountInCents * stripeFeePercentage) + stripeFeeFixed;
    const totalAmountWithFees = amountInCents + stripeFee;
    
    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: totalAmountWithFees,
      currency: "usd",
      capture_method: "manual",
      automatic_payment_methods: { enabled: true },
      metadata: {
        offer_id: offer.id,
        buyer_id: userId,
        seller_id: offer.seller_id,
        seek_listing_id: offer.seek_listing_id,
        base_amount_cents: amountInCents.toString(),
        stripe_fee_cents: stripeFee.toString(),
        total_amount_cents: totalAmountWithFees.toString(),
      },
    });
    
    // Insert payment record
    const { error: paymentError } = await supabase.from("payments").insert({
      buyer_id: userId,
      seller_id: offer.seller_id,
      listing_id: offer.seek_listing_id,
      amount: totalAmountWithFees,
      payment_intent_id: paymentIntent.id,
      status: "requires_capture",
      marketplace_fee_cents: stripeFee,
    });
    
    if (paymentError) {
      // Cancel the payment intent if we couldn't create the payment record
      await stripe.paymentIntents.cancel(paymentIntent.id);
      throw new Error(`Failed to create payment record: ${paymentError.message}`);
    }
    
    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        base_amount_cents: amountInCents,
        stripe_fee_cents: stripeFee,
        total_amount_cents: totalAmountWithFees,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
    
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
