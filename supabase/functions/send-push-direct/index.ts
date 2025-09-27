import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// JWT generation for APNs
async function createJWT(teamId: string, keyId: string, privateKey: string): Promise<string> {
  const header = {
    alg: 'ES256',
    kid: keyId
  }
  
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: teamId,
    iat: now,
    exp: now + 3600 // 1 hour
  }
  
  // Convert PEM to DER format
  const pemContent = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  
  const der = Uint8Array.from(atob(pemContent), c => c.charCodeAt(0))
  
  // Import the private key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    {
      name: 'ECDSA',
      namedCurve: 'P-256'
    },
    false,
    ['sign']
  )
  
  // Create JWT
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const unsignedToken = `${headerB64}.${payloadB64}`
  
  // Sign the token
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(unsignedToken)
  )
  
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
  
  return `${unsignedToken}.${signatureB64}`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, title, body, data, type = 'new_message' } = await req.json()

    // APNs environment variables
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV') || 'sandbox'
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
      throw new Error('Missing APNs environment variables (APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)')
    }

    console.log('🚀 Direct APNs push notification request:', { user_id, title, type })

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get user's push token
    const { data: userPrefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled')
      .eq('user_id', user_id)
      .single()

    if (prefsError) {
      console.error('❌ Failed to fetch user preferences:', prefsError)
    }

    // Save notification to database FIRST (using SQL function to bypass RLS)
    console.log('💾 Saving notification to database...')
    const { error: saveError } = await supabase
      .rpc('insert_notification', {
        p_user_id: user_id,
        p_type: type || 'new_message',
        p_title: title,
        p_body: body,
        p_data: data || {},
        p_is_delivered: false, // Will update to true if APNs succeeds
        p_delivered_at: null
      })

    if (saveError) {
      console.error('⚠️ Failed to save notification record:', saveError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to save notification',
        details: saveError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ Notification saved to database')

    // Check if user has push token and notifications enabled for APNs
    if (!userPrefs?.push_enabled || !userPrefs?.push_token) {
      console.log('⚠️ No push token or push disabled - notification saved but no APNs push:', { 
        user_id, 
        push_enabled: userPrefs?.push_enabled, 
        has_token: !!userPrefs?.push_token 
      })
      return new Response(JSON.stringify({
        success: true,
        message: 'Notification saved but no push sent (no token)',
        apnsSuccess: false
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
    }

    // Now try APNs (optional - if it fails, notification is still saved)
    let apnsSuccess = false
    try {
      // Create JWT token
      console.log('🔑 Creating JWT token...')
      const jwt = await createJWT(APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)
      console.log('✅ JWT created successfully')

      // Determine APNs endpoint
      const apnsUrl = APNS_ENV === 'production' 
        ? 'https://api.push.apple.com'
        : 'https://api.sandbox.push.apple.com'

      // Prepare APNs payload
      const apnsPayload = {
        aps: {
          alert: {
            title: title,
            body: body
          },
          sound: 'default',
          badge: 1,
          'content-available': 1
        },
        ...data
      }

      console.log('📱 Sending to APNs:', {
        url: apnsUrl,
        device_token: userPrefs.push_token.substring(0, 12) + '…',
        token_length: userPrefs.push_token.length,
        title,
        body
      })

      // Send to APNs with full token as stored
      const apnsResponse = await fetch(`${apnsUrl}/3/device/${userPrefs.push_token}`, {
        method: 'POST',
        headers: {
          'Authorization': `bearer ${jwt}`,
          'apns-topic': BUNDLE_ID,
          'apns-push-type': 'alert',
          'apns-priority': '10',
          'apns-expiration': '0',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(apnsPayload)
      })

      const responseText = await apnsResponse.text()
      console.log('📱 APNs response:', {
        status: apnsResponse.status,
        statusText: apnsResponse.statusText,
        headers: Object.fromEntries(apnsResponse.headers.entries()),
        body: responseText,
        url: `${apnsUrl}/3/device/${userPrefs.push_token}`,
        tokenUsed: userPrefs.push_token
      })

      if (apnsResponse.ok) {
        apnsSuccess = true
        console.log('✅ APNs push sent successfully')
      } else {
        let reason = `status ${apnsResponse.status}`
        let errorDetails = {}
        try {
          errorDetails = JSON.parse(responseText)
          if (errorDetails?.reason) reason = errorDetails.reason
        } catch {}
        console.error('❌ APNs error:', {
          status: apnsResponse.status,
          reason: reason,
          details: errorDetails,
          token: userPrefs.push_token,
          environment: APNS_ENV
        })
      }
    } catch (apnsError) {
      console.error('❌ APNs failed:', apnsError)
    }

    console.log('✅ Notification processing complete')
    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Notification saved successfully!',
      apnsSuccess: apnsSuccess
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ Direct APNs push notification error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
