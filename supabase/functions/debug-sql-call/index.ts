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

    console.log('🚀 DEBUG: Testing SQL function call for user:', user_id)

    // Initialize Supabase client
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Call the SQL function
    console.log('💾 DEBUG: Calling insert_notification SQL function...')
    const { data: notificationId, error: saveError } = await supabase
      .rpc('insert_notification', {
        p_user_id: user_id,
        p_type: type,
        p_title: title,
        p_body: body,
        p_data: {},
        p_is_delivered: true,
        p_delivered_at: new Date().toISOString()
      })

    console.log('💾 DEBUG: SQL function result:', { notificationId, saveError })

    if (saveError) {
      console.error('⚠️ DEBUG: SQL function call failed:', saveError)
      return new Response(JSON.stringify({
        success: false,
        error: 'SQL function call failed',
        details: saveError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ DEBUG: SQL function call successful, notification ID:', notificationId)

    return new Response(JSON.stringify({ 
      success: true, 
      message: 'SQL function call successful!',
      notificationId
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ DEBUG: SQL function call error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
