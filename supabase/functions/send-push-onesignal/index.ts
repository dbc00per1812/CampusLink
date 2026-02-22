// Supabase Edge Function: Send Push Notification via OneSignal API
// Deploy: supabase functions deploy send-push-onesignal
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';

const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';

interface PushNotificationPayload {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, any>;
  badge?: number;
  sound?: string;
  priority?: 'default' | 'normal' | 'high';
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get OneSignal credentials from environment
    const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID');
    const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY');

    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      throw new Error('Missing OneSignal credentials in environment variables');
    }

    // Parse request payload
    const payload: PushNotificationPayload = await req.json();
    const { user_id, title, body, data, badge, sound, priority } = payload;

    if (!user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: user_id, title, body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`📤 Sending push notification to user: ${user_id}`);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Check user's notification preferences
    const { data: prefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_enabled, push_token')
      .eq('user_id', user_id)
      .single();

    if (prefsError || !prefs) {
      console.error('User notification preferences not found:', prefsError);
      return new Response(
        JSON.stringify({ error: 'User notification preferences not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if push is enabled
    if (!prefs.push_enabled) {
      console.log('Push notifications disabled for user');
      return new Response(
        JSON.stringify({ message: 'Push notifications disabled for user' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Prepare OneSignal notification payload
    // Using include_aliases for OneSignal API v2 (external_id is set via OneSignal.login())
    const oneSignalPayload = {
      app_id: ONESIGNAL_APP_ID,
      // Target user by external_id (set when user logs in via OneSignal.login(userId))
      include_aliases: { external_id: [user_id] },
      target_channel: 'push',
      headings: { en: title },
      contents: { en: body },
      data: data || {},
      priority: priority === 'high' ? 10 : 5,
      ios_badgeType: badge !== undefined ? 'SetTo' : 'None',
      ios_badgeCount: badge,
      ios_sound: sound || 'default',
      android_sound: sound || 'default',
      android_channel_id: 'default',
    };

    console.log('OneSignal payload:', JSON.stringify(oneSignalPayload, null, 2));

    // Send to OneSignal API
    const oneSignalResponse = await fetch(ONESIGNAL_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(oneSignalPayload),
    });

    const oneSignalData = await oneSignalResponse.json();

    // Check for errors
    if (!oneSignalResponse.ok || oneSignalData.errors) {
      console.error('OneSignal API error:', oneSignalData);
      return new Response(
        JSON.stringify({
          error: 'Failed to send push notification',
          details: oneSignalData.errors || oneSignalData,
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Notification sent successfully:', oneSignalData);

    // Create notification record in database
    await supabase.from('notifications').insert({
      user_id: user_id,
      type: data?.type || 'marketplace_activity',
      title: title,
      body: body,
      data: data || {},
      is_delivered: true,
      delivered_at: new Date().toISOString(),
      order_id: data?.order_id,
      listing_id: data?.listing_id,
      message_id: data?.message_id,
      related_user_id: data?.related_user_id,
    });

    return new Response(
      JSON.stringify({
        success: true,
        notification_id: oneSignalData.id,
        recipients: oneSignalData.recipients,
        message: 'Push notification sent successfully',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('❌ Error in send-push-onesignal:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

