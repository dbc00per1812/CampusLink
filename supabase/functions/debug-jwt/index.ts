import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV') || 'sandbox'
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'

    console.log('🔍 Environment Variables:')
    console.log('APNS_TEAM_ID:', APNS_TEAM_ID)
    console.log('APNS_KEY_ID:', APNS_KEY_ID)
    console.log('APNS_PRIVATE_KEY length:', APNS_PRIVATE_KEY?.length)
    console.log('APNS_ENV:', APNS_ENV)
    console.log('BUNDLE_ID:', BUNDLE_ID)

    if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
      return new Response(JSON.stringify({
        error: 'Missing environment variables',
        APNS_TEAM_ID: !!APNS_TEAM_ID,
        APNS_KEY_ID: !!APNS_KEY_ID,
        APNS_PRIVATE_KEY: !!APNS_PRIVATE_KEY
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    // Test JWT creation
    try {
      const header = {
        alg: 'ES256',
        kid: APNS_KEY_ID
      }
      
      const now = Math.floor(Date.now() / 1000)
      const payload = {
        iss: APNS_TEAM_ID,
        iat: now,
        exp: now + 3600
      }
      
      console.log('📝 JWT Header:', header)
      console.log('📝 JWT Payload:', payload)
      
      // Convert PEM to DER format
      const pemContent = APNS_PRIVATE_KEY
        .replace(/-----BEGIN PRIVATE KEY-----/, '')
        .replace(/-----END PRIVATE KEY-----/, '')
        .replace(/\s/g, '')
      
      const der = Uint8Array.from(atob(pemContent), c => c.charCodeAt(0))
      
      // Test key import
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
      
      console.log('✅ Key imported successfully')
      
      // Create unsigned token
      const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
      const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
      const unsignedToken = `${headerB64}.${payloadB64}`
      
      console.log('📝 Unsigned token:', unsignedToken.substring(0, 100) + '...')
      
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
      
      const jwt = `${unsignedToken}.${signatureB64}`
      
      console.log('✅ JWT created successfully')
      console.log('📝 JWT length:', jwt.length)
      console.log('📝 JWT preview:', jwt.substring(0, 100) + '...')
      
      return new Response(JSON.stringify({
        success: true,
        jwt_length: jwt.length,
        jwt_preview: jwt.substring(0, 100) + '...',
        header: header,
        payload: payload,
        unsigned_token: unsignedToken.substring(0, 100) + '...'
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
      
    } catch (jwtError) {
      console.error('❌ JWT creation failed:', jwtError)
      return new Response(JSON.stringify({
        error: 'JWT creation failed',
        details: jwtError.message,
        stack: jwtError.stack
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ Debug error:', message)
    return new Response(JSON.stringify({ 
      error: message,
      stack: (error as Error)?.stack
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
