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
    const { user_id, title, body, type = 'new_message' } = await req.json()

    console.log('🚀 DEBUG: Testing database-only notification for user:', user_id)

    // Initialize Supabase client
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get user's push token (to verify user exists)
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

    // Save notification to database using SQL function (skip APNs)
    console.log('💾 DEBUG: Saving notification to database (skipping APNs)...')
    const { data: notificationId, error: saveError } = await supabase
      .rpc('insert_notification', {
        p_user_id: user_id,
        p_type: type,
        p_title: title,
        p_body: body,
        p_data: {},
        p_is_delivered: false, // Mark as not delivered since we skipped APNs
        p_delivered_at: null
      })

    console.log('💾 DEBUG: Database save result:', { notificationId, saveError })

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

    console.log('✅ DEBUG: Notification saved successfully (database only)')

    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Database-only notification saved successfully!',
      notificationId
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ DEBUG: Database-only notification error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
