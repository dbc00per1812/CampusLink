// Process Notification Queue
// This function processes the push notification queue and sends push notifications via APNs

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import * as jwt from 'https://deno.land/x/jose@v5.2.3/index.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Apple Push Notification Service configuration
const APNS_HOST = Deno.env.get('APNS_HOST') || 'api.push.apple.com'
const APNS_PORT = 443
const APNS_PATH = '/3/device/'
const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'com.campus.CampusLink'
const TEAM_ID = Deno.env.get('APPLE_TEAM_ID') || ''
const KEY_ID = Deno.env.get('APPLE_KEY_ID') || ''
const PRIVATE_KEY = Deno.env.get('APPLE_PRIVATE_KEY') || ''

async function createJWT(): Promise<string> {
  if (!TEAM_ID || !KEY_ID || !PRIVATE_KEY) {
    throw new Error('Missing Apple Push Notification credentials')
  }

  const header = {
    alg: 'ES256',
    kid: KEY_ID,
  }

  const payload = {
    iss: TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
  }

  // Decode base64 private key if needed
  let privateKeyData = PRIVATE_KEY
  if (PRIVATE_KEY.includes('BEGIN PRIVATE KEY')) {
    privateKeyData = PRIVATE_KEY
  } else {
    // Assume it's base64 encoded
    privateKeyData = atob(PRIVATE_KEY)
  }

  const privateKey = await jwt.importPKCS8(privateKeyData, 'ES256')
  const token = await new jwt.SignJWT(payload)
    .setProtectedHeader(header)
    .sign(privateKey)

  return token
}

async function sendPushNotification(
  token: string,
  title: string,
  body: string,
  data: any,
  authToken: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const payload = {
      aps: {
        alert: {
          title,
          body,
        },
        sound: 'default',
        badge: 1,
      },
      data,
    }

    const response = await fetch(`https://${APNS_HOST}${APNS_PATH}${token}`, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${authToken}`,
        'apns-topic': BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
    })

    if (response.ok) {
      return { success: true }
    } else {
      const errorText = await response.text()
      console.error('APNS error:', response.status, errorText)
      return { success: false, error: `APNS error: ${response.status} ${errorText}` }
    }
  } catch (error) {
    console.error('Error sending push notification:', error)
    return { success: false, error: error.message }
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get unprocessed notifications from the queue
    const { data: notifications, error: fetchError } = await supabase
      .rpc('get_unprocessed_push_notifications', { batch_size: 20 })

    if (fetchError) {
      throw fetchError
    }

    if (!notifications || notifications.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No notifications to process' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create JWT for APNS
    const authToken = await createJWT()
    
    // Process each notification
    const results = []
    const processedIds = []
    const failedIds = []

    for (const notification of notifications) {
      if (!notification.push_token) {
        console.log(`Skipping notification ${notification.id}: No push token`)
        failedIds.push(notification.id)
        continue
      }

      const result = await sendPushNotification(
        notification.push_token,
        notification.title,
        notification.body,
        notification.data,
        authToken
      )

      if (result.success) {
        processedIds.push(notification.id)
      } else {
        failedIds.push(notification.id)
      }

      results.push({
        id: notification.id,
        success: result.success,
        error: result.error,
      })
    }

    // Mark processed notifications
    if (processedIds.length > 0) {
      const { error: updateError } = await supabase
        .rpc('mark_push_notifications_processed', {
          notification_ids: processedIds,
          error_msg: null
        })

      if (updateError) {
        console.error('Error marking notifications as processed:', updateError)
      }
    }

    // Mark failed notifications with error
    if (failedIds.length > 0) {
      const { error: updateError } = await supabase
        .rpc('mark_push_notifications_processed', {
          notification_ids: failedIds,
          error_msg: 'Failed to send push notification'
        })

      if (updateError) {
        console.error('Error marking failed notifications:', updateError)
      }
    }

    return new Response(
      JSON.stringify({
        processed: processedIds.length,
        failed: failedIds.length,
        results,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error processing notification queue:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
