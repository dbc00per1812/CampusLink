// Supabase Edge Function: create_offer_payment_intent
// Creates a Stripe PaymentIntent for accepting offers with DESTINATION CHARGES
// Ensures money flows correctly: buyer → seller's Connect account
//
// AUDIT FIX (Phase 1.4): Added destination charge routing matching create_payment_intent
// Previously, PaymentIntents were created on the platform account with NO transfer_data,
// meaning sellers never received money from offer-based transactions.

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
    .select("*")
    .eq("id", offerId)
    .single();
    
  if (error || !data) {
    console.error("Offer fetch error:", error);
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
    console.log("Starting create_offer_payment_intent function");
    
    const userId = await getAuthenticatedUserId(req);
    const body = await req.json() as CreateOfferPaymentIntentRequest;
    
    console.log("Request body:", body);
    console.log("User ID:", userId);
    
    if (!body.offer_id) {
      throw new Error("Missing offer_id");
    }
    
    // Fetch offer details
    console.log("Fetching offer:", body.offer_id);
    const offer = await fetchOffer(body.offer_id);
    console.log("Offer fetched:", offer);
    
    // Verify the current user is the seeker (buyer)
    if (offer.seeker_id !== userId) {
      throw new Error("Unauthorized: Only the seeker can accept this offer");
    }
    
    // Get the offer amount
    const amountInCents = offer.price_cents;
    if (!amountInCents || amountInCents <= 0) {
      throw new Error("Invalid offer amount");
    }
    
    // Calculate Stripe fees (matching create_payment_intent logic)
    const stripeFee = Math.round(amountInCents * 0.029) + 30;
    const totalAmountWithFees = amountInCents + stripeFee;

    // ===== DESTINATION CHARGE ROUTING =====
    // Look up seller's Stripe Connect account
    const { data: sellerProfile, error: sellerError } = await supabase
      .from("users")
      .select("stripe_connect_id")
      .eq("id", offer.seller_id)
      .single();

    if (sellerError || !sellerProfile) {
      console.error("Seller profile error:", sellerError);
      throw new Error("Seller not found");
    }

    const sellerStripeConnectId = sellerProfile.stripe_connect_id;
    let canUseDestinationCharges = false;

    if (!sellerStripeConnectId) {
      console.log("⚠️ Seller hasn't completed Stripe Connect onboarding - will hold in escrow");
    } else {
      console.log(`✅ Seller Connect ID: ${sellerStripeConnectId}`);
      
      // Check if seller's Connect account has active transfers capability
      try {
        const sellerAccount = await stripe.accounts.retrieve(sellerStripeConnectId);
        
        console.log(`   Charges enabled: ${sellerAccount.charges_enabled}`);
        console.log(`   Payouts enabled: ${sellerAccount.payouts_enabled}`);
        console.log(`   Transfers capability: ${sellerAccount.capabilities?.transfers || 'none'}`);
        
        if (sellerAccount.capabilities?.transfers === 'active') {
          canUseDestinationCharges = true;
          console.log("   ✅ Transfers capability is ACTIVE - can use destination charges");
        } else {
          console.log(`   ⚠️ Transfers capability is ${sellerAccount.capabilities?.transfers || 'missing'} - will use escrow mode`);
        }
      } catch (accountError: any) {
        console.error(`   ❌ Failed to retrieve seller account:`, accountError.message);
        console.log("   ⚠️ Will use escrow mode as fallback");
      }
    }

    // Application fee = Stripe processing fee only (no platform fee)
    const applicationFeeCents = stripeFee;

    console.log("💰 Offer pricing breakdown:");
    console.log(`   Seller price: $${amountInCents / 100}`);
    console.log(`   Stripe fee: $${stripeFee / 100}`);
    console.log(`   Buyer pays: $${totalAmountWithFees / 100}`);
    console.log(`   Application fee: $${applicationFeeCents / 100}`);

    // Build PaymentIntent params
    let paymentIntentParams: any = {
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
        application_fee_cents: applicationFeeCents.toString(),
      },
    };

    // Add destination charge params if seller has active Connect account
    if (canUseDestinationCharges && sellerStripeConnectId) {
      paymentIntentParams.on_behalf_of = sellerStripeConnectId;
      paymentIntentParams.transfer_data = {
        destination: sellerStripeConnectId,
      };
      paymentIntentParams.application_fee_amount = applicationFeeCents;
      
      console.log("✅ Using DESTINATION CHARGES:");
      console.log(`   → Seller receives: $${amountInCents / 100}`);
      console.log(`   → Application fee (Stripe only): $${applicationFeeCents / 100}`);
    } else {
      console.log("⚠️ Using ESCROW MODE:");
      console.log(`   → Payment will be held by platform until seller completes onboarding`);
    }

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);
    
    console.log(`✅ PaymentIntent created: ${paymentIntent.id}`);

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
        payment_intent_id: paymentIntent.id,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
    
  } catch (error) {
    console.error("Function error:", error);
    return new Response(
      JSON.stringify({ 
        error: error.message || "Unknown error occurred",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
