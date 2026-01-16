// Supabase Edge Function to archive expired listings
// Auto-archives tickets and seek posts that have passed their expires_at date
//
// Run via cron job: SELECT cron.schedule('process-expired-listings', '*/30 * * * *', ...);

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("📦 Processing expired listings...");

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const now = new Date();
    const nowISO = now.toISOString();

    console.log(`📅 Current time: ${nowISO}`);
    console.log(`📅 Listings with expires_at < ${nowISO} will be archived`);

    // Find listings that:
    // 1. Have an expires_at date set (NOT NULL)
    // 2. expires_at is in the past (< now)
    // 3. Are not already archived
    // 4. Are not already sold
    const { data: expiredListings, error: fetchError } = await supabaseAdmin
      .from("listings")
      .select("id, title, category, expires_at, user_id, intent")
      .not("expires_at", "is", null)
      .lt("expires_at", nowISO)
      .eq("archived", false)
      .eq("is_sold", false);

    if (fetchError) {
      console.error("❌ Error fetching expired listings:", fetchError);
      throw fetchError;
    }

    if (!expiredListings || expiredListings.length === 0) {
      console.log("✅ No expired listings found");
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: "No expired listings found",
          processed: 0 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`⏰ Found ${expiredListings.length} expired listing(s)`);

    let processed = 0;
    let errors: string[] = [];

    for (const listing of expiredListings) {
      try {
        console.log(`\n📦 Processing expired listing: ${listing.id}`);
        console.log(`   Title: ${listing.title}`);
        console.log(`   Category: ${listing.category}`);
        console.log(`   Intent: ${listing.intent}`);
        console.log(`   Expired at: ${listing.expires_at}`);

        // Archive the listing
        const { error: updateError } = await supabaseAdmin
          .from("listings")
          .update({
            archived: true,
            updated_at: now.toISOString(),
          })
          .eq("id", listing.id);

        if (updateError) {
          console.error(`   ❌ Failed to archive listing: ${updateError.message}`);
          errors.push(`Listing ${listing.id}: ${updateError.message}`);
          continue;
        }

        console.log(`   ✅ Listing archived successfully`);

        // Notify the listing owner
        const listingType = listing.category === "Tickets" ? "ticket" : "listing";
        await supabaseAdmin.from("push_notification_queue").insert({
          user_id: listing.user_id,
          title: "Listing Expired",
          body: `Your ${listingType} "${listing.title}" has expired and been archived.`,
          data: {
            type: "listing_expired",
            listing_id: listing.id,
            category: listing.category,
          },
        });

        console.log(`   ✅ Notification queued for user`);
        processed++;

      } catch (listingError: any) {
        console.error(`   ❌ Error processing listing ${listing.id}: ${listingError.message}`);
        errors.push(`Listing ${listing.id}: ${listingError.message}`);
      }
    }

    console.log(`\n✅ Processed ${processed}/${expiredListings.length} expired listings`);
    if (errors.length > 0) {
      console.log(`⚠️ Errors: ${errors.join(", ")}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${processed} expired listings`,
        processed,
        total: expiredListings.length,
        errors: errors.length > 0 ? errors : undefined,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error("❌ Error processing expired listings:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to process expired listings",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

