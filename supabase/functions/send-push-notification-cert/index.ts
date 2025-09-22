import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

    // Environment variables
    const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'darragh.CampusLink'
    const APNS_ENV = (Deno.env.get('APNS_ENV') || 'sandbox').toLowerCase()
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    // Certificate-based auth
    const PUSH_CERT_BASE64 = Deno.env.get('PUSH_CERT_BASE64')
    const PUSH_CERT_PASSWORD = Deno.env.get('PUSH_CERT_PASSWORD')
    
    if (!PUSH_CERT_BASE64) {
      throw new Error('Missing PUSH_CERT_BASE64 environment variable')
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
      console.log('❌ No push token or push disabled:', { 
        user_id, 
        push_enabled: userPrefs?.push_enabled, 
        has_token: !!userPrefs?.push_token 
      })
      return new Response(JSON.stringify({
        success: false,
        message: 'User has no push token or disabled notifications'
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
    }

    // For certificate-based auth, we need to convert the .p12 to PEM format
    // Since Deno/Edge Functions can't directly use .p12, we'll need to use a different approach
    
    // Option 1: Use a third-party push service (recommended)
    // Option 2: Convert .p12 to PEM locally and upload the PEM parts
    
    // For now, let's save the notification and provide instructions
    const { error: saveError } = await supabase
      .from('notifications')
      .insert({
        user_id,
        type: type || 'general',
        title,
        body,
        data: data || {},
        is_delivered: false, // Will be true when actually sent
        created_at: new Date().toISOString()
      })

    if (saveError) {
      console.error('⚠️ Failed to save notification record:', saveError)
    }

    // Return success with instructions
    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Notification saved. Certificate-based push requires additional setup.',
      instructions: 'See PUSH_SETUP_CERT.md for certificate conversion steps'
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ Push notification error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
