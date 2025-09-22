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
    
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    console.log('Push notification request:', { user_id, title, body, type })
    
    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    // Get user's push token
    const { data: userPrefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled')
      .eq('user_id', user_id)
      .single()
    
    if (!userPrefs?.push_enabled || !userPrefs?.push_token) {
      return new Response(JSON.stringify({ 
        success: false, 
        message: 'User has no push token or disabled notifications' 
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }
    
    // For now, just save the notification to database
    // You can integrate with a service like OneSignal, Firebase, or Pusher later
    const { error: saveError } = await supabase
      .from('notifications')
      .insert({
        user_id,
        type: type || 'general',
        title,
        body,
        data: data || {},
        is_delivered: false // Will be true when actually sent via APNs
      })
    
    if (saveError) {
      console.error('Failed to save notification:', saveError)
      throw saveError
    }
    
    // TODO: Here you would integrate with your push notification service
    // For example: OneSignal, Firebase Cloud Messaging, or a custom APNs service
    
    return new Response(JSON.stringify({ 
      success: true,
      message: 'Notification saved (push delivery pending service integration)'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
    
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ 
      success: false,
      error: error.message 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
