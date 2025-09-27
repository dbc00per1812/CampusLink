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
    console.log('🔄 Processing push notification queue...')

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get pending push notifications
    const { data: pendingNotifications, error: fetchError } = await supabase
      .from('pending_push_notifications')
      .select('*')
      .limit(10) // Process 10 at a time

    if (fetchError) {
      console.error('❌ Failed to fetch pending notifications:', fetchError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to fetch pending notifications',
        details: fetchError
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }

    console.log(`📋 Found ${pendingNotifications?.length || 0} pending notifications`)

    const results = []
    
    // Process each notification
    for (const notif of pendingNotifications || []) {
      try {
        console.log(`📤 Processing notification ${notif.notification_id} for user ${notif.user_id}`)

        // Call send-push-direct for each notification
        const pushResponse = await fetch(`${SUPABASE_URL}/functions/v1/send-push-direct`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            user_id: notif.user_id,
            title: notif.title,
            body: notif.body,
            data: notif.data,
            type: notif.type
          })
        })

        const pushResult = await pushResponse.json()
        
        // Update notification status if push was sent
        if (pushResult.success && pushResult.apnsSuccess) {
          await supabase
            .from('notifications')
            .update({
              is_delivered: true,
              delivered_at: new Date().toISOString()
            })
            .eq('id', notif.notification_id)
        }

        results.push({
          notification_id: notif.notification_id,
          success: pushResult.success,
          apnsSuccess: pushResult.apnsSuccess
        })

      } catch (error) {
        console.error(`❌ Failed to process notification ${notif.notification_id}:`, error)
        results.push({
          notification_id: notif.notification_id,
          success: false,
          error: error.message
        })
      }
    }

    console.log('✅ Queue processing complete')
    
    return new Response(JSON.stringify({
      success: true,
      processed: results.length,
      results: results
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error) {
    console.error('❌ Queue processor error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    })
  }
})
