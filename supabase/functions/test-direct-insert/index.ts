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

    console.log('🚀 DEBUG: Testing direct insert for user:', user_id)

    // Initialize Supabase client
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Try direct insert (this should fail due to RLS, but let's see the error)
    console.log('💾 DEBUG: Trying direct insert...')
    const { data: notificationData, error: saveError } = await supabase
      .from('notifications')
      .insert({
        user_id,
        type: type,
        title,
        body,
        data: {},
        is_delivered: false,
        delivered_at: null
      })
      .select()

    console.log('💾 DEBUG: Direct insert result:', { notificationData, saveError })

    if (saveError) {
      console.error('⚠️ DEBUG: Direct insert failed (expected due to RLS):', saveError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Direct insert failed (expected due to RLS)',
        details: saveError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ DEBUG: Direct insert successful (unexpected!)')

    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Direct insert successful!',
      notificationData
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ DEBUG: Direct insert error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
