// Supabase Edge Function to delete a user account
// Deploy this function via Supabase Dashboard: https://supabase.com/dashboard
//
// 1. Go to your project dashboard
// 2. Navigate to Edge Functions
// 3. Create a new function called "delete_user"
// 4. Copy and paste this code
// 5. Deploy the function
//
// Required Environment Variables:
// - SUPABASE_URL (automatically available)
// - SUPABASE_SERVICE_ROLE_KEY (automatically available)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

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
    // Get the authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("No authorization header");
    }

    // Extract the JWT token
    const token = authHeader.replace("Bearer ", "");

    // Create Supabase client with service role key for admin operations
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Verify the user's JWT token and get user ID
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      console.error("Auth error:", authError);
      throw new Error("Invalid or expired token");
    }

    const userId = user.id;
    console.log(`🔄 Deleting user: ${userId}`);

    // Delete user data from all related tables in correct order to avoid foreign key violations
    // Note: Adjust table names and order based on your database schema

    // 1. Delete from tables with foreign keys to other user tables
    const tablesToCleanup = [
      "wallet_transactions",
      "user_notification_preferences",
      "ratings",
      "reports",
      "time_slot_bookings",
      "payouts",
      "messages",
      "push_notification_queue",
    ];

    for (const table of tablesToCleanup) {
      try {
        const { error } = await supabaseAdmin
          .from(table)
          .delete()
          .eq("user_id", userId);

        if (error) {
          console.error(`Error deleting from ${table}:`, error);
          // Continue with other tables even if one fails
        } else {
          console.log(`✅ Deleted from ${table}`);
        }
      } catch (err) {
        console.error(`Error deleting from ${table}:`, err);
        // Continue with other tables
      }
    }

    // 2. Delete conversations where user is a participant
    try {
      const { error } = await supabaseAdmin
        .from("conversations")
        .delete()
        .or(`user1_id.eq.${userId},user2_id.eq.${userId}`);

      if (error) {
        console.error("Error deleting conversations:", error);
      } else {
        console.log("✅ Deleted conversations");
      }
    } catch (err) {
      console.error("Error deleting conversations:", err);
    }

    // 3. Delete orders where user is buyer or seller
    try {
      const { error } = await supabaseAdmin
        .from("orders")
        .delete()
        .or(`buyer_id.eq.${userId},seller_id.eq.${userId}`);

      if (error) {
        console.error("Error deleting orders:", error);
      } else {
        console.log("✅ Deleted orders");
      }
    } catch (err) {
      console.error("Error deleting orders:", err);
    }

    // 4. Delete offers
    try {
      const { error } = await supabaseAdmin
        .from("offers")
        .delete()
        .eq("buyer_id", userId);

      if (error) {
        console.error("Error deleting offers:", error);
      } else {
        console.log("✅ Deleted offers");
      }
    } catch (err) {
      console.error("Error deleting offers:", err);
    }

    // 5. Delete payments
    try {
      const { error } = await supabaseAdmin
        .from("payments")
        .delete()
        .eq("user_id", userId);

      if (error) {
        console.error("Error deleting payments:", error);
      } else {
        console.log("✅ Deleted payments");
      }
    } catch (err) {
      console.error("Error deleting payments:", err);
    }

    // 6. Delete listings
    try {
      const { error } = await supabaseAdmin
        .from("listings")
        .delete()
        .eq("seller_id", userId);

      if (error) {
        console.error("Error deleting listings:", error);
      } else {
        console.log("✅ Deleted listings");
      }
    } catch (err) {
      console.error("Error deleting listings:", err);
    }

    // 7. Delete disputes
    try {
      const { error } = await supabaseAdmin
        .from("disputes")
        .delete()
        .or(`plaintiff_id.eq.${userId},defendant_id.eq.${userId}`);

      if (error) {
        console.error("Error deleting disputes:", error);
      } else {
        console.log("✅ Deleted disputes");
      }
    } catch (err) {
      console.error("Error deleting disputes:", err);
    }

    // 8. Delete wallet
    try {
      const { error } = await supabaseAdmin
        .from("wallets")
        .delete()
        .eq("user_id", userId);

      if (error) {
        console.error("Error deleting wallet:", error);
      } else {
        console.log("✅ Deleted wallet");
      }
    } catch (err) {
      console.error("Error deleting wallet:", err);
    }

    // 9. Delete user profile
    try {
      const { error } = await supabaseAdmin
        .from("users")
        .delete()
        .eq("id", userId);

      if (error) {
        console.error("Error deleting user profile:", error);
      } else {
        console.log("✅ Deleted user profile");
      }
    } catch (err) {
      console.error("Error deleting user profile:", err);
    }

    // 10. Finally, delete from auth.users (this will invalidate the session)
    const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(
      userId
    );

    if (deleteAuthError) {
      console.error("Error deleting auth user:", deleteAuthError);
      throw new Error(`Failed to delete user from auth: ${deleteAuthError.message}`);
    }

    console.log("✅ User deleted from auth");
    console.log(`✅ Account deletion completed for user: ${userId}`);

    return new Response(
      JSON.stringify({
        message: "Account successfully deleted",
        userId: userId,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error in delete_user function:", error);

    return new Response(
      JSON.stringify({
        error: error.message || "Internal server error",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

