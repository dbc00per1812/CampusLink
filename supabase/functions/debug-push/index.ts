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
    // Get environment variables
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID')
    const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
    const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
    const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')
    const APNS_ENV = Deno.env.get('APNS_ENV')
    
    console.log('🔍 Environment Variables Debug:')
    console.log('BUNDLE_ID:', BUNDLE_ID)
    console.log('APNS_TEAM_ID:', APNS_TEAM_ID)
    console.log('APNS_KEY_ID:', APNS_KEY_ID)
    console.log('APNS_ENV:', APNS_ENV)
    console.log('APNS_PRIVATE_KEY length:', APNS_PRIVATE_KEY?.length)
    console.log('APNS_PRIVATE_KEY starts with:', APNS_PRIVATE_KEY?.substring(0, 30))
    console.log('APNS_PRIVATE_KEY ends with:', APNS_PRIVATE_KEY?.substring(APNS_PRIVATE_KEY.length - 30))
    
    // Check if all required vars are present
    const missing = []
    if (!BUNDLE_ID) missing.push('BUNDLE_ID')
    if (!APNS_TEAM_ID) missing.push('APNS_TEAM_ID')
    if (!APNS_KEY_ID) missing.push('APNS_KEY_ID')
    if (!APNS_PRIVATE_KEY) missing.push('APNS_PRIVATE_KEY')
    if (!APNS_ENV) missing.push('APNS_ENV')
    
    if (missing.length > 0) {
      return new Response(JSON.stringify({
        success: false,
        error: `Missing environment variables: ${missing.join(', ')}`
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }
    
    // Try to create JWT
    try {
      const alg = 'ES256'
      const privateKey = await importPKCS8(APNS_PRIVATE_KEY, alg)
      const jwt = await new SignJWT({})
        .setProtectedHeader({ alg, kid: APNS_KEY_ID })
        .setIssuer(APNS_TEAM_ID)
        .setIssuedAt()
        .setExpirationTime('1h')
        .sign(privateKey)
      
      console.log('✅ JWT created successfully')
      console.log('JWT length:', jwt.length)
      console.log('JWT starts with:', jwt.substring(0, 50))
      
      return new Response(JSON.stringify({
        success: true,
        message: 'All environment variables present and JWT created successfully',
        debug: {
          bundleId: BUNDLE_ID,
          teamId: APNS_TEAM_ID,
          keyId: APNS_KEY_ID,
          env: APNS_ENV,
          privateKeyLength: APNS_PRIVATE_KEY.length,
          jwtLength: jwt.length
        }
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
      
    } catch (jwtError) {
      console.error('❌ JWT creation failed:', jwtError)
      return new Response(JSON.stringify({
        success: false,
        error: `JWT creation failed: ${jwtError.message}`,
        debug: {
          bundleId: BUNDLE_ID,
          teamId: APNS_TEAM_ID,
          keyId: APNS_KEY_ID,
          env: APNS_ENV,
          privateKeyLength: APNS_PRIVATE_KEY.length
        }
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ Debug error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
