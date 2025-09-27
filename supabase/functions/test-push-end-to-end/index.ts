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
    
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    console.log('🧪 End-to-end push test for user:', user_id)
    
    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    // Step 1: Check user has push token (audit recommendation)
    console.log('🔍 Step 1: Checking user push token...')
    const { data: userPrefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled')
      .eq('user_id', user_id)
      .single()
    
    if (prefsError) {
      console.error('❌ Step 1 failed:', prefsError)
      return new Response(JSON.stringify({
        success: false,
        step: 1,
        error: 'Failed to fetch user preferences',
        details: prefsError.message
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }
    
    if (!userPrefs?.push_enabled || !userPrefs?.push_token) {
      console.log('❌ Step 1 failed: No push token or disabled')
      return new Response(JSON.stringify({
        success: false,
        step: 1,
        error: 'User has no push token or notifications disabled',
        details: {
          push_enabled: userPrefs?.push_enabled,
          has_token: !!userPrefs?.push_token,
          token_length: userPrefs?.push_token?.length || 0
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      })
    }
    
    console.log('✅ Step 1 passed: User has push token')
    
    // Step 2: Call debug push function (audit recommendation)
    console.log('🔍 Step 2: Calling debug push function...')
    const debugResponse = await fetch(`${SUPABASE_URL}/functions/v1/debug-push-complete`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        user_id,
        title: 'End-to-End Test',
        body: 'This is a comprehensive push notification test',
        data: { test: true, timestamp: new Date().toISOString() },
        type: 'e2e_test'
      })
    })
    
    const debugResult = await debugResponse.json()
    console.log('🔍 Step 2 result:', {
      status: debugResponse.status,
      success: debugResult.success,
      debug_info: debugResult.debug_info
    })
    
    if (!debugResponse.ok || !debugResult.success) {
      console.error('❌ Step 2 failed: Debug push function failed')
      return new Response(JSON.stringify({
        success: false,
        step: 2,
        error: 'Debug push function failed',
        details: debugResult
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }
    
    console.log('✅ Step 2 passed: Debug push function succeeded')
    
    // Step 3: Check notification was saved to database
    console.log('🔍 Step 3: Verifying notification in database...')
    const { data: notifications, error: notifError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user_id)
      .eq('type', 'e2e_test')
      .order('created_at', { ascending: false })
      .limit(1)
    
    if (notifError) {
      console.error('❌ Step 3 failed:', notifError)
      return new Response(JSON.stringify({
        success: false,
        step: 3,
        error: 'Failed to fetch notification from database',
        details: notifError.message
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }
    
    if (!notifications || notifications.length === 0) {
      console.error('❌ Step 3 failed: No notification found in database')
      return new Response(JSON.stringify({
        success: false,
        step: 3,
        error: 'No notification found in database',
        details: 'Notification was not saved'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      })
    }
    
    console.log('✅ Step 3 passed: Notification saved to database')
    
    // Step 4: Check notification logs (audit recommendation)
    console.log('🔍 Step 4: Checking notification logs...')
    const { data: logs, error: logsError } = await supabase
      .from('notification_logs')
      .select('*')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(1)
    
    if (logsError) {
      console.log('⚠️ Step 4 warning: Could not fetch logs:', logsError.message)
    } else if (!logs || logs.length === 0) {
      console.log('⚠️ Step 4 warning: No logs found')
    } else {
      console.log('✅ Step 4 passed: Notification logs found')
    }
    
    // Return comprehensive test results (audit recommendation)
    return new Response(JSON.stringify({
      success: true,
      message: 'End-to-end push notification test completed successfully',
      steps_completed: 4,
      test_results: {
        step_1: {
          description: 'User push token check',
          passed: true,
          details: {
            push_enabled: userPrefs.push_enabled,
            has_token: !!userPrefs.push_token,
            token_length: userPrefs.push_token.length,
            token_prefix: userPrefs.push_token.substring(0, 8)
          }
        },
        step_2: {
          description: 'Debug push function call',
          passed: true,
          details: debugResult.debug_info
        },
        step_3: {
          description: 'Database notification verification',
          passed: true,
          details: {
            notification_id: notifications[0].id,
            is_delivered: notifications[0].is_delivered,
            delivery_status: notifications[0].delivery_status
          }
        },
        step_4: {
          description: 'Notification logs check',
          passed: logs && logs.length > 0,
          details: {
            logs_found: logs?.length || 0,
            latest_log: logs?.[0] ? {
              response_status: logs[0].response_status,
              created_at: logs[0].created_at
            } : null
          }
        }
      },
      summary: {
        user_id,
        notification_id: notifications[0].id,
        apns_success: debugResult.success,
        database_saved: true,
        logs_available: logs && logs.length > 0
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })
    
  } catch (error) {
    console.error('❌ End-to-end test failed with error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: 'Unexpected error during test',
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
