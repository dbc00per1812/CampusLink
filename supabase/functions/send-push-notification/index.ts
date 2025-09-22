import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, title, body, data, type = 'general' } = await req.json()

    // Env for APNs auth key (JWT) and Supabase
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = (Deno.env.get('APNS_ENV') || 'sandbox').toLowerCase()
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'https://vnmzijluyctlufnzxast.supabase.co'
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
      throw new Error('Missing APNs environment variables (APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)')
    }
    if (!SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY')
    }

    console.log('🚀 Push notification request:', { user_id, title, type, env: APNS_ENV })

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

    if (!userPrefs?.push_enabled || !userPrefs?.push_token) {
      console.log('❌ No push token or push disabled:', { user_id, push_enabled: userPrefs?.push_enabled, has_token: !!userPrefs?.push_token })
      return new Response(JSON.stringify({
        success: false,
        message: 'User has no push token or disabled notifications'
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    // Prepare payload for APNs
    const notification = {
      aps: {
        alert: { title, body },
        sound: 'default',
        badge: 1,
      },
      data: data || {},
      type,
    }

    // Build APNs JWT using Auth Key (.p8)
    const alg = 'ES256'
    const privateKey = await importPKCS8(APNS_PRIVATE_KEY, alg)
    const jwt = await new SignJWT({})
      .setProtectedHeader({ alg, kid: APNS_KEY_ID })
      .setIssuer(APNS_TEAM_ID)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(privateKey)

    const host = APNS_ENV === 'production' ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com'
    const apnsUrl = `${host}/3/device/${userPrefs.push_token}`

    console.log('📱 Sending to APNs:', {
      url: apnsUrl,
      token_prefix: userPrefs.push_token.substring(0, 12) + '…',
      topic: BUNDLE_ID,
      env: APNS_ENV,
    })

    const apnsResponse = await fetch(apnsUrl, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': '0',
        'content-type': 'application/json',
      },
      body: JSON.stringify(notification),
    })

    const responseText = await apnsResponse.text()
    console.log('📱 APNs response:', {
      status: apnsResponse.status,
      body: responseText,
      headers: Object.fromEntries(apnsResponse.headers.entries()),
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
    const { error: saveError } = await supabase
      .from('notifications')
      .insert({
        user_id,
        type: type || 'general',
        title,
        body,
        data: data || {},
        is_delivered: true,
        delivered_at: new Date().toISOString(),
      })

    if (saveError) {
      console.error('⚠️ Failed to save notification record:', saveError)
    }

    console.log('✅ Push notification sent successfully')
    return new Response(JSON.stringify({ success: true, message: 'Push notification sent successfully!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ Push notification error:', message)
    return new Response(JSON.stringify({ success: false, error: message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})
