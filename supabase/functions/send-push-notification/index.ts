// Supabase Edge Function: Send Push Notification via Expo Push Service
// Deploy: supabase functions deploy send-push-notification
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const EXPO_PUSH_URL = 'https://exp.host/--/api/v2/push/send';

interface PushNotificationPayload {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, any>;
  badge?: number;
  sound?: string;
  priority?: 'default' | 'normal' | 'high';
}

serve(async (req) => {
  try {
    // CORS headers
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      });
    }

    // Parse request
    const payload: PushNotificationPayload = await req.json();
    const { user_id, title, body, data, badge, sound, priority } = payload;

    if (!user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: user_id, title, body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get user's push token and preferences
    const { data: prefs, error: prefsError } = await supabase
      .from('user_notification_preferences')
      .select('push_token, push_enabled, push_platform')
      .eq('user_id', user_id)
      .single();

    if (prefsError || !prefs) {
      console.error('Error fetching notification preferences:', prefsError);
      return new Response(
        JSON.stringify({ error: 'User notification preferences not found' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if push is enabled and token exists
    if (!prefs.push_enabled || !prefs.push_token) {
      return new Response(
        JSON.stringify({ message: 'Push notifications disabled or no token' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Prepare Expo push message
    const message = {
      to: prefs.push_token,
      sound: sound || 'default',
      title: title,
      body: body,
      data: data || {},
      badge: badge,
      priority: priority || 'high',
      channelId: 'default', // Android notification channel
    };

    // Send to Expo Push Service
    const expoResponse = await fetch(EXPO_PUSH_URL, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message),
    });

    const expoData = await expoResponse.json();

    // Check for errors
    if (expoData.errors) {
      console.error('Expo push errors:', expoData.errors);
      return new Response(
        JSON.stringify({ error: 'Failed to send push notification', details: expoData.errors }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

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
        ticket: expoData.data,
        message: 'Push notification sent successfully' 
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in send-push-notification:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

