// Supabase Edge Function to create Stripe PaymentIntent with DESTINATION CHARGES
// This ensures money flows correctly: buyer → seller's Connect account, with platform taking a fee
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

  try {
    // Get user from auth header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Missing authorization header");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      throw new Error("Invalid auth token");
    }

    const userId = user.id;
    console.log(`💳 Creating payment intent for user: ${userId}`);

    // Parse request body - support BOTH listing_id (new purchase) and order_id (accepted offer)
    const { listing_id, order_id } = await req.json();
    
    let sellerUserId: string;
    let sellerPriceCents: number;
    let buyerPriceCents: number;
    let listingId: string;
    let listingTitle: string;
    
    if (order_id) {
      // PAYING FOR EXISTING ORDER (accepted offer)
      console.log(`💳 Payment for existing order: ${order_id}`);
      
      const { data: order, error: orderError } = await supabaseAdmin
        .from("orders")
        .select("id, buyer_id, seller_id, buyer_price_cents, seller_price_cents, listing_id, payment_status")
        .eq("id", order_id)
        .single();

      if (orderError || !order) {
        console.error("Order fetch error:", orderError);
        throw new Error("Order not found");
      }

      // Verify current user is the buyer
      if (order.buyer_id !== userId) {
        throw new Error("Unauthorized - you are not the buyer of this order");
      }

      // Verify order is unpaid
      if (order.payment_status !== 'pending') {
        throw new Error("Order already paid");
      }

      sellerUserId = order.seller_id;
      sellerPriceCents = order.seller_price_cents;
      buyerPriceCents = order.buyer_price_cents;
      listingId = order.listing_id;
      
      // Get listing title separately
      const { data: listing } = await supabaseAdmin
        .from("listings")
        .select("title")
        .eq("id", order.listing_id)
        .single();
      
      listingTitle = listing?.title || "Order";
      
      console.log(`📦 Order: ${listingTitle}, Buyer Price: $${buyerPriceCents / 100}`);
      console.log(`👤 Seller ID: ${sellerUserId}`);
      
    } else if (listing_id) {
      // EXISTING FLOW: New purchase
    console.log(`📦 Listing ID: ${listing_id}`);

    // Get listing details including seller info
    const { data: listing, error: listingError } = await supabaseAdmin
      .from("listings")
      .select(`
        id,
        price,
        title,
        user_id
      `)
      .eq("id", listing_id)
      .single();

    if (listingError || !listing) {
      console.error("Listing fetch error:", listingError);
      throw new Error("Listing not found");
    }

    console.log(`📦 Listing: ${listing.title}, Price: $${listing.price}`);
    console.log(`👤 Seller ID: ${listing.user_id}`);

    // Verify buyer is not the seller
    if (listing.user_id === userId) {
      throw new Error("Cannot purchase your own listing");
      }
      
      sellerUserId = listing.user_id;
      listingId = listing.id;
      listingTitle = listing.title;
      
      // Calculate prices (will be set below in existing code flow)
      
    } else {
      throw new Error("Either listing_id or order_id is required");
    }

    // Initialize Stripe (needed for capability checks)
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
      apiVersion: "2023-10-16",
    });

    // Get seller's Stripe Connect account ID
    const { data: sellerProfile, error: sellerError } = await supabaseAdmin
      .from("users")
      .select("stripe_connect_id")
      .eq("id", sellerUserId)
      .single();

    if (sellerError || !sellerProfile) {
      console.error("Seller profile error:", sellerError);
      throw new Error("Seller not found");
    }

    // Note: We allow listings from sellers who haven't completed Connect onboarding yet
    // (deferred onboarding). The money will be held in escrow until they complete setup.
    const sellerStripeConnectId = sellerProfile.stripe_connect_id;
    
    // Check if seller's Connect account has active transfers capability
    let canUseDestinationCharges = false;
    
    if (!sellerStripeConnectId) {
      console.log("⚠️ Seller hasn't completed Stripe Connect onboarding - will hold in escrow");
    } else {
      console.log(`✅ Seller Connect ID: ${sellerStripeConnectId}`);
      
      // Retrieve seller's account to check capabilities
      try {
        const sellerAccount = await stripe.accounts.retrieve(sellerStripeConnectId);
        
        console.log(`   Charges enabled: ${sellerAccount.charges_enabled}`);
        console.log(`   Payouts enabled: ${sellerAccount.payouts_enabled}`);
        console.log(`   Transfers capability: ${sellerAccount.capabilities?.transfers || 'none'}`);
        
        // Only use destination charges if transfers capability is ACTIVE
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

    // Calculate pricing - NO platform fee, only Stripe processing fee
    if (listing_id && !order_id) {
      // NEW PURCHASE: Calculate prices from listing
      const { data: listing, error: listingError } = await supabaseAdmin
        .from("listings")
        .select("price")
        .eq("id", listing_id)
        .single();
      
      if (listingError || !listing) {
        throw new Error("Listing not found for price calculation");
      }
      
      sellerPriceCents = Math.round(listing.price * 100);
    
      // Calculate Stripe processing fee (2.9% + $0.30)
      const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30);
    
      // Buyer pays exact amount: seller price + Stripe fee (no rounding, no platform fee)
      buyerPriceCents = sellerPriceCents + stripeFeeCents;
    }
    // For order_id case, prices are already set from the order query above
    
    // Calculate Stripe fee and set platform cut to $0 (no platform fee)
    const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30);
    const campusLinkCutCents = 0;  // No platform fee
    
    // Application fee = only Stripe processing fee (no platform profit)
    const applicationFeeCents = stripeFeeCents;

    console.log("💰 Pricing breakdown (NO platform fee):");
    console.log(`   Seller price: $${sellerPriceCents / 100}`);
    console.log(`   Stripe processing fee: $${stripeFeeCents / 100}`);
    console.log(`   Buyer pays: $${buyerPriceCents / 100}`);
    console.log(`   Platform cut: $0 (no platform fee)`);
    console.log(`   Application fee (covers Stripe): $${applicationFeeCents / 100}`);

    // Seller receives exactly their listing price
    const sellerReceivesCents = sellerPriceCents;

    console.log(`💸 Seller will receive: $${sellerReceivesCents / 100}`);

    // Create PaymentIntent with DESTINATION CHARGES (if seller has Connect account)
    let paymentIntentParams: any = {
      amount: buyerPriceCents,
      currency: "usd",
      capture_method: "manual",
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        listing_id: listingId,
        buyer_id: userId,
        seller_id: sellerUserId,
        seller_price_cents: sellerPriceCents.toString(),
        buyer_price_cents: buyerPriceCents.toString(),
        stripe_fee_cents: stripeFeeCents.toString(),
        campuslink_cut_cents: campusLinkCutCents.toString(),
        ...(order_id ? { order_id: order_id } : {}),  // Include order_id if paying for existing order
        application_fee_cents: applicationFeeCents.toString(),
        seller_receives_cents: sellerReceivesCents.toString(),
      },
    };

    // Only add destination charge params if seller has completed Connect onboarding
    // AND has active transfers capability
    if (canUseDestinationCharges && sellerStripeConnectId) {
      paymentIntentParams.on_behalf_of = sellerStripeConnectId;
      paymentIntentParams.transfer_data = {
        destination: sellerStripeConnectId,
      };
      // Application fee = everything except seller's listing price
      // This ensures seller gets exactly their listing price, platform covers Stripe fee + profit
      paymentIntentParams.application_fee_amount = applicationFeeCents;
      
      console.log("✅ Using DESTINATION CHARGES (no platform fee):");
      console.log(`   → Seller receives: $${sellerReceivesCents / 100} (their listing price)`);
      console.log(`   → Application fee (Stripe only): $${applicationFeeCents / 100}`);
      console.log(`   → Platform profit: $0`);
    } else {
      console.log("⚠️ Using ESCROW MODE:");
      console.log(`   → Payment will be held by platform until seller completes onboarding`);
      console.log(`   → Or seller needs to complete Stripe verification`);
    }

    const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);

    console.log(`✅ PaymentIntent created: ${paymentIntent.id}`);
    console.log(`   Amount: $${paymentIntent.amount / 100}`);
    console.log(`   Status: ${paymentIntent.status}`);

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        seller_price_cents: sellerPriceCents,
        buyer_price_cents: buyerPriceCents,
        stripe_fee_cents: stripeFeeCents,
        campuslink_cut_cents: campusLinkCutCents,
        application_fee_cents: applicationFeeCents,
        seller_receives_cents: sellerReceivesCents,
        payment_intent_id: paymentIntent.id,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error creating payment intent:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Internal server error",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

