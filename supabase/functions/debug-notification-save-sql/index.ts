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

    console.log('🚀 DEBUG: Testing notification save with SQL for user:', user_id)

    // Initialize Supabase client
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Save notification using raw SQL to bypass RLS
    console.log('💾 DEBUG: Saving notification using raw SQL...')
    const { data: notificationData, error: saveError } = await supabase
      .rpc('insert_notification', {
        p_user_id: user_id,
        p_type: type,
        p_title: title,
        p_body: body,
        p_data: {},
        p_is_delivered: true,
        p_delivered_at: new Date().toISOString()
      })

    console.log('💾 DEBUG: Save result:', { notificationData, saveError })

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

    console.log('✅ DEBUG: Notification saved successfully')

    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Notification saved successfully!',
      notificationData
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ DEBUG: Notification save error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
