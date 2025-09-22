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

    // OneSignal environment variables
    const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')
    const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_API_KEY')
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    if (!ONESIGNAL_APP_ID || !ONESIGNAL_API_KEY) {
      throw new Error('Missing OneSignal environment variables (ONESIGNAL_APP_ID, ONESIGNAL_API_KEY)')
    }

    console.log('🚀 OneSignal push notification request:', { user_id, title, type })

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get user's OneSignal player ID (we'll store this instead of push token)
    const { data: userPrefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled')
      .eq('user_id', user_id)
      .single()

    if (prefsError) {
      console.error('❌ Failed to fetch user preferences:', prefsError)
    }

    if (!userPrefs?.push_enabled || !userPrefs?.push_token) {
      console.log('❌ No OneSignal player ID or push disabled:', { 
        user_id, 
        push_enabled: userPrefs?.push_enabled, 
        has_token: !!userPrefs?.push_token 
      })
      return new Response(JSON.stringify({
        success: false,
        message: 'User has no OneSignal player ID or disabled notifications'
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
    }

    // Prepare OneSignal notification payload
    const notification = {
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: [userPrefs.push_token], // OneSignal player ID
      headings: { en: title },
      contents: { en: body },
      data: data || {},
      ios_badgeType: "SetTo",
      ios_badgeCount: 1,
      ios_sound: "default"
    }

    console.log('📱 Sending to OneSignal:', {
      app_id: ONESIGNAL_APP_ID,
      player_id: userPrefs.push_token.substring(0, 12) + '…',
      title,
      body
    })

    // Send to OneSignal
    const oneSignalResponse = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${ONESIGNAL_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(notification)
    })

    const responseText = await oneSignalResponse.text()
    console.log('📱 OneSignal response:', {
      status: oneSignalResponse.status,
      body: responseText
    })

    if (!oneSignalResponse.ok) {
      let reason = `status ${oneSignalResponse.status}`
      try {
        const j = JSON.parse(responseText)
        if (j?.errors) reason = j.errors.join(', ')
      } catch {}
      throw new Error(`OneSignal error: ${reason}`)
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
        delivered_at: new Date().toISOString()
      })

    if (saveError) {
      console.error('⚠️ Failed to save notification record:', saveError)
    }

    console.log('✅ OneSignal push notification sent successfully')
    return new Response(JSON.stringify({ 
      success: true, 
      message: 'OneSignal push notification sent successfully!' 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ OneSignal push notification error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
