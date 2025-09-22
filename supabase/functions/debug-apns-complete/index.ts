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

    console.log('🔍 Complete APNs Debug:')
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

    // Step 1: Check private key format
    console.log('📝 Step 1: Checking private key format...')
    const hasBeginHeader = APNS_PRIVATE_KEY.includes('-----BEGIN PRIVATE KEY-----')
    const hasEndHeader = APNS_PRIVATE_KEY.includes('-----END PRIVATE KEY-----')
    const keyContent = APNS_PRIVATE_KEY
      .replace(/-----BEGIN PRIVATE KEY-----/, '')
      .replace(/-----END PRIVATE KEY-----/, '')
      .replace(/\s/g, '')
    
    console.log('Has BEGIN header:', hasBeginHeader)
    console.log('Has END header:', hasEndHeader)
    console.log('Key content length:', keyContent.length)
    console.log('Key content preview:', keyContent.substring(0, 50) + '...')

    // Step 2: Test key import
    console.log('📝 Step 2: Testing key import...')
    let keyImportSuccess = false
    let keyImportError = ''
    try {
      const der = Uint8Array.from(atob(keyContent), c => c.charCodeAt(0))
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
      keyImportSuccess = true
      console.log('✅ Key imported successfully')
    } catch (error) {
      keyImportError = error.message
      console.error('❌ Key import failed:', error.message)
    }

    // Step 3: Test JWT creation
    console.log('📝 Step 3: Testing JWT creation...')
    let jwtSuccess = false
    let jwtError = ''
    let jwt = ''
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
      
      if (keyImportSuccess) {
        const der = Uint8Array.from(atob(keyContent), c => c.charCodeAt(0))
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
        
        const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
        const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
        const unsignedToken = `${headerB64}.${payloadB64}`
        
        const signature = await crypto.subtle.sign(
          { name: 'ECDSA', hash: 'SHA-256' },
          key,
          new TextEncoder().encode(unsignedToken)
        )
        
        const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
          .replace(/=/g, '')
          .replace(/\+/g, '-')
          .replace(/\//g, '_')
        
        jwt = `${unsignedToken}.${signatureB64}`
        jwtSuccess = true
        console.log('✅ JWT created successfully')
      }
    } catch (error) {
      jwtError = error.message
      console.error('❌ JWT creation failed:', error.message)
    }

    // Step 4: Test APNs connection
    console.log('📝 Step 4: Testing APNs connection...')
    let apnsSuccess = false
    let apnsError = ''
    let apnsStatus = 0
    let apnsResponse = ''
    
    if (jwtSuccess) {
      try {
        const apnsUrl = APNS_ENV === 'production' 
          ? 'https://api.push.apple.com'
          : 'https://api.sandbox.push.apple.com'

        const apnsPayload = {
          aps: {
            alert: {
              title: 'Debug Test',
              body: 'This is a debug test from CampusLink!'
            },
            sound: 'default',
            badge: 1
          }
        }

        console.log('Sending to APNs:', apnsUrl)
        console.log('JWT length:', jwt.length)
        console.log('Bundle ID:', BUNDLE_ID)

        const apnsResponseObj = await fetch(`${apnsUrl}/3/device/0000000000000000000000000000000000000000000000000000000000000000`, {
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

        apnsStatus = apnsResponseObj.status
        apnsResponse = await apnsResponseObj.text()
        
        if (apnsResponseObj.ok) {
          apnsSuccess = true
          console.log('✅ APNs connection successful')
        } else {
          apnsError = `Status ${apnsStatus}: ${apnsResponse}`
          console.error('❌ APNs connection failed:', apnsError)
        }
      } catch (error) {
        apnsError = error.message
        console.error('❌ APNs connection error:', error.message)
      }
    }

    return new Response(JSON.stringify({
      success: true,
      debug: {
        environment_variables: {
          APNS_TEAM_ID: APNS_TEAM_ID,
          APNS_KEY_ID: APNS_KEY_ID,
          APNS_PRIVATE_KEY_length: APNS_PRIVATE_KEY?.length,
          APNS_ENV: APNS_ENV,
          BUNDLE_ID: BUNDLE_ID
        },
        key_format: {
          has_begin_header: hasBeginHeader,
          has_end_header: hasEndHeader,
          content_length: keyContent.length,
          content_preview: keyContent.substring(0, 50) + '...'
        },
        key_import: {
          success: keyImportSuccess,
          error: keyImportError
        },
        jwt_creation: {
          success: jwtSuccess,
          error: jwtError,
          jwt_length: jwt.length,
          jwt_preview: jwt.substring(0, 100) + '...'
        },
        apns_connection: {
          success: apnsSuccess,
          error: apnsError,
          status: apnsStatus,
          response: apnsResponse
        }
      }
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

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
