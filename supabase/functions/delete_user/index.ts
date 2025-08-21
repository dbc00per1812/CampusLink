// Supabase Edge Function: delete_user
// Allows authenticated users to delete their own account

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Method not allowed" });
  }

  // Get the JWT from the Authorization header
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return jsonResponse(401, { ok: false, error: "Missing or invalid authorization header" });
  }

  const token = authHeader.replace("Bearer ", "");
  
  // Create a Supabase client with the anon key and the user's token for verification
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
  });

  // Verify the caller's identity
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  
  if (authError || !user) {
    return jsonResponse(401, { ok: false, error: "Invalid token or user not found" });
  }

  // Use the authenticated user's ID for deletion (self-deletion only)
  const userIdToDelete = user.id;

  try {
    // Create admin client with service role key for deletion
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Delete the user from Auth
    const { error: deleteError } = await admin.auth.admin.deleteUser(userIdToDelete);
    if (deleteError) {
      throw new Error(deleteError.message || "Failed to delete user from auth");
    }

    // Clean up related data in your own tables
    const { error: cleanupError } = await admin.from("users").delete().eq("id", userIdToDelete);
    if (cleanupError) {
      console.error("Failed to cleanup user data:", cleanupError);
      // Don't throw here - user is already deleted from auth
    }

    return jsonResponse(200, { ok: true, message: "Account successfully deleted" });
  } catch (error) {
    console.error("Delete account error:", error);
    return jsonResponse(500, { 
      ok: false, 
      error: error instanceof Error ? error.message : "Failed to delete account" 
    });
  }
});