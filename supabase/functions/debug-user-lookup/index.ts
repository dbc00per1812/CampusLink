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
    const { user_id } = await req.json()

    console.log('🚀 DEBUG: Looking up user:', user_id)

    // Initialize Supabase client
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get user's push token
    console.log('🔍 DEBUG: Fetching user preferences for user_id:', user_id)
    const { data: userPrefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled, user_id')
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

    if (!userPrefs) {
      console.log('❌ No user preferences found for user_id:', user_id)
      return new Response(JSON.stringify({
        success: false,
        message: 'No user preferences found',
        user_id
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
    }

    if (!userPrefs.push_enabled || !userPrefs.push_token) {
      console.log('❌ No push token or push disabled:', { 
        user_id, 
        push_enabled: userPrefs.push_enabled, 
        has_token: !!userPrefs.push_token 
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

    console.log('✅ DEBUG: User has valid push token and notifications enabled')

    return new Response(JSON.stringify({
      success: true,
      message: 'User lookup successful',
      userPrefs: {
        user_id: userPrefs.user_id,
        push_enabled: userPrefs.push_enabled,
        has_token: !!userPrefs.push_token,
        token_preview: userPrefs.push_token ? userPrefs.push_token.substring(0, 12) + '...' : null
      }
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ DEBUG: User lookup error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
