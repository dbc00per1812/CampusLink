import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
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
    // Get environment variables
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID')
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV')
    
    console.log('🔍 Testing APNs connection...')
    console.log('BUNDLE_ID:', BUNDLE_ID)
    console.log('APNS_TEAM_ID:', APNS_TEAM_ID)
    console.log('APNS_KEY_ID:', APNS_KEY_ID)
    console.log('APNS_ENV:', APNS_ENV)
    
    // Create JWT
    const alg = 'ES256'
    const privateKey = await importPKCS8(APNS_PRIVATE_KEY, alg)
    const jwt = await new SignJWT({})
      .setProtectedHeader({ alg, kid: APNS_KEY_ID })
      .setIssuer(APNS_TEAM_ID)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(privateKey)
    
    console.log('✅ JWT created successfully')
    
    // Test APNs connection with a dummy device token
    const host = APNS_ENV === 'production' ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com'
    const testDeviceToken = '0000000000000000000000000000000000000000000000000000000000000000'
    const apnsUrl = `${host}/3/device/${testDeviceToken}`
    
    console.log('📱 Testing APNs URL:', apnsUrl)
    
    const testNotification = {
      aps: {
        alert: { title: "Test", body: "APNs connection test" },
        sound: 'default',
        badge: 1,
      }
    }
    
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
      body: JSON.stringify(testNotification),
    })
    
    const responseText = await apnsResponse.text()
    console.log('📱 APNs response:', {
      status: apnsResponse.status,
      body: responseText,
      headers: Object.fromEntries(apnsResponse.headers.entries()),
    })
    
    if (apnsResponse.status === 400) {
      // This is expected for invalid device token, but means our JWT is valid
      return new Response(JSON.stringify({
        success: true,
        message: 'APNs connection successful! JWT is valid. (400 error expected for dummy token)',
        debug: {
          status: apnsResponse.status,
          response: responseText,
          jwtLength: jwt.length
        }
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    } else if (apnsResponse.status === 401) {
      return new Response(JSON.stringify({
        success: false,
        error: 'APNs authentication failed - InvalidProviderToken',
        debug: {
          status: apnsResponse.status,
          response: responseText,
          jwtLength: jwt.length
        }
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    } else {
      return new Response(JSON.stringify({
        success: true,
        message: 'APNs connection successful!',
        debug: {
          status: apnsResponse.status,
          response: responseText,
          jwtLength: jwt.length
        }
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ APNs test error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
