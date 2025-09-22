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
    const { user_id, title, body, data, type = 'general' } = await req.json()

    console.log('🚀 DEBUG: Received request:', { user_id, title, body, type })

    // APNs environment variables
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV') || 'sandbox'
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    console.log('🔧 DEBUG: Environment variables:', {
      APNS_TEAM_ID: APNS_TEAM_ID ? 'SET' : 'MISSING',
      APNS_KEY_ID: APNS_KEY_ID ? 'SET' : 'MISSING',
      APNS_PRIVATE_KEY: APNS_PRIVATE_KEY ? 'SET' : 'MISSING',
      APNS_ENV,
      BUNDLE_ID,
      SUPABASE_URL: SUPABASE_URL ? 'SET' : 'MISSING',
      SUPABASE_SERVICE_ROLE_KEY: SUPABASE_SERVICE_ROLE_KEY ? 'SET' : 'MISSING'
    })

    if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
      throw new Error('Missing APNs environment variables (APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)')
    }

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get user's push token
    console.log('🔍 DEBUG: Fetching user preferences for user_id:', user_id)
    const { data: userPrefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled')
      .eq('user_id', user_id)
      .single()

    console.log('🔍 DEBUG: User preferences result:', { userPrefs, prefsError })

    if (prefsError) {
      console.error('❌ Failed to fetch user preferences:', prefsError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to fetch user preferences',
        details: prefsError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    if (!userPrefs?.push_enabled || !userPrefs?.push_token) {
      console.log('❌ No push token or push disabled:', { 
        user_id, 
        push_enabled: userPrefs?.push_enabled, 
        has_token: !!userPrefs?.push_token 
      })
      return new Response(JSON.stringify({
        success: false,
        message: 'User has no push token or disabled notifications',
        userPrefs
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
    }

    // Create JWT token
    console.log('🔑 DEBUG: Creating JWT token...')
    const jwt = await createJWT(APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)
    console.log('✅ DEBUG: JWT created successfully')

    // Determine APNs endpoint
    const apnsUrl = APNS_ENV === 'production' 
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com'

    console.log('🌐 DEBUG: Using APNs URL:', apnsUrl)

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

    console.log('📱 DEBUG: Sending to APNs:', {
      url: apnsUrl,
      device_token: userPrefs.push_token.substring(0, 12) + '…',
      title,
      body,
      payload: apnsPayload
    })

    // Send to APNs
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
    console.log('📱 DEBUG: APNs response:', {
      status: apnsResponse.status,
      body: responseText
    })

    if (!apnsResponse.ok) {
      let reason = `status ${apnsResponse.status}`
      try {
        const j = JSON.parse(responseText)
        if (j?.reason) reason = j.reason
      } catch {}
      throw new Error(`APNs error: ${reason}`)
    }

    // Save notification to database
    console.log('💾 DEBUG: Saving notification to database...')
    const { error: saveError } = await supabase
      .from('notifications')
      .insert({
        user_id,
        type: type || 'general',
        title,
        body,
        data: data || {},
        is_delivered: true,
        delivered_at: new Date().toISOString()
      })

    if (saveError) {
      console.error('⚠️ DEBUG: Failed to save notification record:', saveError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to save notification',
        details: saveError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ DEBUG: Notification saved successfully')

    console.log('✅ DEBUG: Direct APNs push notification sent successfully')
    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Debug APNs push notification sent successfully!',
      apnsStatus: apnsResponse.status,
      notificationSaved: !saveError
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ DEBUG: Direct APNs push notification error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
