import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Create JWT for APNs authentication
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
    // APNs environment variables
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV') || 'sandbox'
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'

    console.log('🔍 DEBUG: APNs Auth Test Starting...')
    console.log('🔍 Environment variables check:', {
      has_team_id: !!APNS_TEAM_ID,
      has_key_id: !!APNS_KEY_ID,
      has_private_key: !!APNS_PRIVATE_KEY,
      apns_env: APNS_ENV,
      bundle_id: BUNDLE_ID,
      team_id_preview: APNS_TEAM_ID ? APNS_TEAM_ID.substring(0, 4) + '...' : 'missing',
      key_id_preview: APNS_KEY_ID ? APNS_KEY_ID.substring(0, 4) + '...' : 'missing'
    })

    // Check if all required environment variables are present
    if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing APNs environment variables',
        details: {
          has_team_id: !!APNS_TEAM_ID,
          has_key_id: !!APNS_KEY_ID,
          has_private_key: !!APNS_PRIVATE_KEY,
          apns_env: APNS_ENV,
          bundle_id: BUNDLE_ID
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }

    // Test JWT creation
    console.log('🔍 Testing JWT creation...')
    let jwt
    try {
      jwt = await createJWT(APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY)
      console.log('✅ JWT created successfully')
    } catch (jwtError) {
      console.error('❌ JWT creation failed:', jwtError)
      return new Response(JSON.stringify({
        success: false,
        error: 'JWT creation failed',
        details: {
          error: jwtError.message,
          has_private_key: !!APNS_PRIVATE_KEY,
          private_key_length: APNS_PRIVATE_KEY.length,
          private_key_preview: APNS_PRIVATE_KEY.substring(0, 50) + '...'
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }

    // Test APNs endpoint connectivity (without sending actual push)
    const apnsHost = APNS_ENV === 'production' ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'
    const testUrl = `https://${apnsHost}/3/device/test-token`
    
    console.log('🔍 Testing APNs endpoint connectivity...')
    console.log('🔍 APNs host:', apnsHost)
    console.log('🔍 Test URL:', testUrl)

    try {
      // Test with a dummy token to see if we get authentication errors vs other errors
      const testResponse = await fetch(testUrl, {
        method: 'POST',
        headers: {
          'Authorization': `bearer ${jwt}`,
          'apns-topic': BUNDLE_ID,
          'apns-push-type': 'alert',
          'apns-priority': '10',
          'apns-expiration': '0',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          aps: {
            alert: 'Test'
          }
        })
      })

      const responseText = await testResponse.text()
      console.log('🔍 APNs test response:', {
        status: testResponse.status,
        statusText: testResponse.statusText,
        body: responseText
      })

      // Parse response if it's JSON
      let responseData
      try {
        responseData = JSON.parse(responseText)
      } catch {
        responseData = responseText
      }

      return new Response(JSON.stringify({
        success: true,
        message: 'APNs authentication test completed',
        results: {
          environment_variables: {
            has_team_id: !!APNS_TEAM_ID,
            has_key_id: !!APNS_KEY_ID,
            has_private_key: !!APNS_PRIVATE_KEY,
            apns_env: APNS_ENV,
            bundle_id: BUNDLE_ID
          },
          jwt_creation: {
            success: true,
            jwt_preview: jwt.substring(0, 50) + '...'
          },
          apns_connectivity: {
            host: apnsHost,
            test_url: testUrl,
            status: testResponse.status,
            status_text: testResponse.statusText,
            response: responseData
          }
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      })

    } catch (connectivityError) {
      console.error('❌ APNs connectivity test failed:', connectivityError)
      return new Response(JSON.stringify({
        success: false,
        error: 'APNs connectivity test failed',
        details: {
          error: connectivityError.message,
          host: apnsHost,
          test_url: testUrl
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }

  } catch (error) {
    console.error('❌ APNs auth debug error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: 'Unexpected error during APNs auth test',
      details: {
        message: error.message,
        stack: error.stack
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    })
  }
})
