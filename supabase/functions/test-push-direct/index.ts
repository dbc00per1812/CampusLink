import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

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
    const { device_token, title, body } = await req.json()

    // APNs environment variables
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV') || 'sandbox'
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'

    if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
      throw new Error('Missing APNs environment variables')
    }

    if (!device_token) {
      throw new Error('Missing device_token')
    }

    console.log('🚀 Testing direct APNs push:', { 
      device_token_length: device_token.length,
      device_token_preview: device_token.substring(0, 20) + '...',
      device_token_full: device_token,
      title, 
      body 
    })

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
          title: title || 'Test Push',
          body: body || 'This is a test push notification from CampusLink!'
        },
        sound: 'default',
        badge: 1,
        'content-available': 1
      }
    }

    console.log('📱 Sending to APNs:', {
      url: apnsUrl,
      device_token: device_token.substring(0, 12) + '...',
      title: title || 'Test Push',
      body: body || 'This is a test push notification from CampusLink!'
    })

    // Send to APNs
    const apnsResponse = await fetch(`${apnsUrl}/3/device/${device_token}`, {
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
      body: responseText
    })

    if (!apnsResponse.ok) {
      let reason = `status ${apnsResponse.status}`
      try {
        const j = JSON.parse(responseText)
        if (j?.reason) reason = j.reason
      } catch {}
      
      console.log('❌ APNs error:', reason)
      return new Response(JSON.stringify({ 
        success: false, 
        error: `APNs error: ${reason}`,
        apns_status: apnsResponse.status,
        apns_response: responseText
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
    }

    console.log('✅ Direct APNs push notification sent successfully')
    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Direct APNs push notification sent successfully!',
      apns_status: apnsResponse.status,
      apns_response: responseText
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
