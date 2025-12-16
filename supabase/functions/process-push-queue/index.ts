// Supabase Edge Function - Process Push Notification Queue (WORKING VERSION)
// This function reads from push_notification_queue and sends actual push notifications via APNs

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// APNs JWT token generation
async function generateAPNsToken(teamId: string, keyId: string, privateKey: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  
  const header = { alg: "ES256", kid: keyId };
  const payload = { iss: teamId, iat: now };
  
  const base64UrlEncode = (obj: any): string => {
    const json = JSON.stringify(obj);
    const base64 = btoa(json);
    return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  };
  
  const headerEncoded = base64UrlEncode(header);
  const payloadEncoded = base64UrlEncode(payload);
  const dataToSign = `${headerEncoded}.${payloadEncoded}`;
  
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = privateKey.replace(/\\n/g, "\n").replace(pemHeader, "").replace(pemFooter, "").trim();
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));
  
  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
  
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    key,
    encoder.encode(dataToSign)
  );
  
  const signatureArray = new Uint8Array(signature);
  const signatureBase64 = btoa(String.fromCharCode(...signatureArray));
  const signatureBase64Url = signatureBase64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  
  return `${dataToSign}.${signatureBase64Url}`;
}

async function sendToAPNs(
  deviceToken: string,
  title: string,
  body: string,
  data: any,
  apnsToken: string,
  bundleId: string,
  isProduction: boolean
): Promise<{ success: boolean; error?: string; status?: number }> {
  const apnsUrl = isProduction
    ? `https://api.push.apple.com/3/device/${deviceToken}`
    : `https://api.sandbox.push.apple.com/3/device/${deviceToken}`;
  
  const notification = {
    aps: {
      alert: { title: title, body: body },
      sound: "default",
      badge: 1,
    },
    data: data || {},
  };
  
  try {
    const response = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "authorization": `bearer ${apnsToken}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(notification),
    });
    
    if (response.ok) {
      return { success: true, status: response.status };
    } else {
      const errorText = await response.text();
      console.error(`APNs Error: ${response.status} - ${errorText}`);
      return { 
        success: false, 
        error: `APNs returned ${response.status}: ${errorText}`,
        status: response.status
      };
    }
  } catch (error) {
    console.error("Failed to send to APNs:", error);
    return { 
      success: false, 
      error: error instanceof Error ? error.message : "Unknown error" 
    };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🔄 Processing push notification queue...");
    
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY");
    const bundleId = Deno.env.get("BUNDLE_ID") || "darragh.CampusLink";
    const apnsEnv = Deno.env.get("APNS_ENV") || "sandbox";
    
    console.log(`APNS_TEAM_ID: ${apnsTeamId ? '✅' : '❌'}`);
    console.log(`APNS_KEY_ID: ${apnsKeyId ? '✅' : '❌'}`);
    console.log(`APNS_PRIVATE_KEY: ${apnsPrivateKey ? '✅' : '❌'}`);
    console.log(`APNS_ENV: ${apnsEnv}`);
    
    if (!apnsTeamId || !apnsKeyId || !apnsPrivateKey) {
      throw new Error("Missing APNs credentials");
    }
    
    const isProduction = apnsEnv === "production";
    
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );
    
    console.log("🔐 Generating APNs JWT token...");
    const apnsToken = await generateAPNsToken(apnsTeamId, apnsKeyId, apnsPrivateKey);
    
    // Simple query - no JOIN
    console.log("📊 Fetching unprocessed notifications...");
    const { data: queueItems, error: fetchError } = await supabaseAdmin
      .from("push_notification_queue")
      .select("*")
      .eq("processed", false)
      .order("created_at", { ascending: true })
      .limit(100);
    
    if (fetchError) {
      console.error("Error fetching queue:", fetchError);
      throw fetchError;
    }
    
    if (!queueItems || queueItems.length === 0) {
      console.log("✅ No notifications in queue");
      return new Response(
        JSON.stringify({ success: true, processed: 0, message: "No notifications to process" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }
    
    console.log(`📬 Found ${queueItems.length} notifications to process`);
    
    let successCount = 0;
    let errorCount = 0;
    
    // Process each notification
    for (const item of queueItems) {
      try {
        // Get user's push token
        const { data: preferences, error: prefError } = await supabaseAdmin
          .from("user_notification_preferences")
          .select("push_token, push_enabled")
          .eq("user_id", item.user_id)
          .single();
        
        if (prefError || !preferences) {
          console.log(`⚠️ No preferences for user ${item.user_id}`);
          await supabaseAdmin
            .from("push_notification_queue")
            .update({ processed: true, processed_at: new Date().toISOString(), error: "No user preferences found" })
            .eq("id", item.id);
          errorCount++;
          continue;
        }
        
        if (!preferences.push_enabled) {
          console.log(`⚠️ Push disabled for user ${item.user_id}`);
          await supabaseAdmin
            .from("push_notification_queue")
            .update({ processed: true, processed_at: new Date().toISOString(), error: "Push notifications disabled" })
            .eq("id", item.id);
          errorCount++;
          continue;
        }
        
        if (!preferences.push_token) {
          console.log(`⚠️ No push token for user ${item.user_id}`);
          await supabaseAdmin
            .from("push_notification_queue")
            .update({ processed: true, processed_at: new Date().toISOString(), error: "No push token" })
            .eq("id", item.id);
          errorCount++;
          continue;
        }
        
        // Send to APNs
        console.log(`📤 Sending push to user ${item.user_id}: ${item.title}`);
        const result = await sendToAPNs(
          preferences.push_token,
          item.title,
          item.body,
          item.data,
          apnsToken,
          bundleId,
          isProduction
        );
        
        if (result.success) {
          console.log(`✅ Successfully sent push to user ${item.user_id}`);
          await supabaseAdmin
            .from("push_notification_queue")
            .update({ processed: true, processed_at: new Date().toISOString(), error: null })
            .eq("id", item.id);
          successCount++;
        } else {
          console.log(`❌ Failed to send push to user ${item.user_id}: ${result.error}`);
          await supabaseAdmin
            .from("push_notification_queue")
            .update({ processed: true, processed_at: new Date().toISOString(), error: result.error || "Unknown error" })
            .eq("id", item.id);
          errorCount++;
        }
      } catch (error) {
        console.error(`❌ Error processing notification ${item.id}:`, error);
        await supabaseAdmin
          .from("push_notification_queue")
          .update({ processed: true, processed_at: new Date().toISOString(), error: error instanceof Error ? error.message : "Unknown error" })
          .eq("id", item.id);
        errorCount++;
      }
    }
    
    console.log(`✅ Processing complete: ${successCount} succeeded, ${errorCount} failed`);
    
    return new Response(
      JSON.stringify({ success: true, processed: queueItems.length, succeeded: successCount, failed: errorCount }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error) {
    console.error("Error processing push queue:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Failed to process push queue" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
