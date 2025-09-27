import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Create JWT for APNs authentication (audit recommendation)
async function createJWT(teamId: string, keyId: string, privateKey: string): Promise<string> {
  const key = await importPKCS8(privateKey, 'ES256')
  
  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuedAt()
    .setIssuer(teamId)
    .setExpirationTime('1h')
    .sign(key)
  
  return jwt
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, title, body, data, type = 'debug_test' } = await req.json()

    // APNs environment variables (audit recommendation: verify these are set)
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV') || 'sandbox'
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    console.log('🔍 DEBUG: Push notification request received:', { 
      user_id, 
      title, 
      type, 
      env: APNS_ENV,
      bundle_id: BUNDLE_ID,
      has_team_id: !!APNS_TEAM_ID,
      has_key_id: !!APNS_KEY_ID,
      has_private_key: !!APNS_PRIVATE_KEY
    })

    // Check environment variables (audit recommendation)
    if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
      const error = 'Missing APNs environment variables (APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)'
      console.error('❌ DEBUG:', error)
      return new Response(JSON.stringify({ 
        success: false, 
        error: error,
        debug_info: {
          has_team_id: !!APNS_TEAM_ID,
          has_key_id: !!APNS_KEY_ID,
          has_private_key: !!APNS_PRIVATE_KEY,
          env: APNS_ENV
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get user's push token (audit recommendation: log this step)
    console.log('🔍 DEBUG: Fetching user preferences for user_id:', user_id)
    const { data: userPrefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled')
      .eq('user_id', user_id)
      .single()

    if (prefsError) {
      console.error('❌ DEBUG: Failed to fetch user preferences:', prefsError)
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Failed to fetch user preferences',
        debug_info: { prefs_error: prefsError.message }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }

    console.log('🔍 DEBUG: User preferences found:', {
      user_id,
      push_enabled: userPrefs?.push_enabled,
      has_push_token: !!userPrefs?.push_token,
      token_length: userPrefs?.push_token?.length || 0,
      token_prefix: userPrefs?.push_token?.substring(0, 8) || 'none'
    })

    if (!userPrefs?.push_enabled || !userPrefs?.push_token) {
      const error = 'User has no push token or disabled notifications'
      console.log('❌ DEBUG:', error, {
        push_enabled: userPrefs?.push_enabled,
        has_token: !!userPrefs?.push_token
      })
      
      return new Response(JSON.stringify({ 
        success: false, 
        error: error,
        debug_info: {
          push_enabled: userPrefs?.push_enabled,
          has_push_token: !!userPrefs?.push_token
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      })
    }

    // Save notification to database with logging (audit recommendation)
    console.log('🔍 DEBUG: Saving notification to database...')
    const { data: savedNotification, error: saveError } = await supabase
      .from('notifications')
      .insert({
        user_id,
        type: type,
        title,
        body,
        data: data || {},
        is_delivered: false,
        created_at: new Date().toISOString()
      })
      .select()
      .single()

    if (saveError) {
      console.error('❌ DEBUG: Failed to save notification:', saveError)
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Failed to save notification',
        debug_info: { save_error: saveError.message }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }

    console.log('✅ DEBUG: Notification saved to database:', {
      notification_id: savedNotification.id,
      title,
      body
    })

    // Create JWT for APNs (audit recommendation)
    console.log('🔍 DEBUG: Creating JWT for APNs authentication...')
    const jwt = await createJWT(APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)
    console.log('✅ DEBUG: JWT created successfully')

    // Prepare APNs payload (audit recommendation: verify headers)
    const apnsPayload = {
      aps: {
        alert: {
          title: title,
          body: body
        },
        sound: "default",
        badge: 1,
        "content-available": 1
      },
      ...(data || {})
    }

    // Determine APNs host (audit recommendation: sandbox vs production)
    const apnsHost = APNS_ENV === 'sandbox' ? 'api.sandbox.push.apple.com' : 'api.push.apple.com'
    const apnsUrl = `https://${apnsHost}/3/device/${userPrefs.push_token}`

    console.log('🔍 DEBUG: Sending to APNs:', {
      url: apnsUrl,
      bundle_id: BUNDLE_ID,
      apns_environment: APNS_ENV,
      token_prefix: userPrefs.push_token.substring(0, 8),
      payload: apnsPayload
    })

    // Send to APNs with comprehensive logging (audit recommendation)
    const apnsResponse = await fetch(apnsUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${jwt}`,
        'apns-topic': BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': '0',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(apnsPayload)
    })

    const responseText = await apnsResponse.text()
    console.log('🔍 DEBUG: APNs response:', {
      status: apnsResponse.status,
      statusText: apnsResponse.statusText,
      headers: Object.fromEntries(apnsResponse.headers.entries()),
      body: responseText
    })

    // Update notification status based on APNs response (audit recommendation)
    let deliveryStatus = 'failed'
    let deliveryError = null

    if (apnsResponse.ok) {
      deliveryStatus = 'sent'
      console.log('✅ DEBUG: Push notification sent successfully')
    } else {
      deliveryError = `APNs error: ${apnsResponse.status} - ${responseText}`
      console.error('❌ DEBUG: APNs error:', deliveryError)
    }

    // Update notification in database
    const { error: updateError } = await supabase
      .from('notifications')
      .update({
        is_delivered: deliveryStatus === 'sent',
        delivered_at: deliveryStatus === 'sent' ? new Date().toISOString() : null,
        delivery_status: deliveryStatus,
        delivery_error: deliveryError
      })
      .eq('id', savedNotification.id)

    if (updateError) {
      console.error('❌ DEBUG: Failed to update notification status:', updateError)
    }

    // Return comprehensive debug response (audit recommendation)
    return new Response(JSON.stringify({
      success: deliveryStatus === 'sent',
      notification_id: savedNotification.id,
      apns_response: {
        status: apnsResponse.status,
        statusText: apnsResponse.statusText,
        body: responseText
      },
      debug_info: {
        user_id,
        token_prefix: userPrefs.push_token.substring(0, 8),
        token_length: userPrefs.push_token.length,
        apns_environment: APNS_ENV,
        bundle_id: BUNDLE_ID,
        apns_host: apnsHost,
        delivery_status: deliveryStatus,
        delivery_error: deliveryError
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: deliveryStatus === 'sent' ? 200 : 400
    })

  } catch (error) {
    console.error('❌ DEBUG: Unexpected error:', error)
    return new Response(JSON.stringify({ 
      success: false, 
      error: 'Unexpected error',
      debug_info: { 
        error_message: error.message,
        error_stack: error.stack
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    })
  }
})
