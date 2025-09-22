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
    const { user_id, title, body, type = 'new_message', data = {} } = await req.json()

    console.log('📝 Saving notification to database:', { user_id, title, body, type })

    // Create Supabase client
    const supabaseUrl = 'https://vnmzijluyctlufnzxast.supabase.co'
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw'
    
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Save notification to database using SQL function to bypass RLS
    const { error: saveError } = await supabase
      .rpc('insert_notification', {
        p_user_id: user_id,
        p_type: type,
        p_title: title,
        p_body: body,
        p_data: data,
        p_is_delivered: false,
        p_delivered_at: null
      })

    if (saveError) {
      console.error('❌ Failed to save notification:', saveError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to save notification',
        details: saveError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ Notification saved successfully')
    return new Response(JSON.stringify({
      success: true,
      message: 'Notification saved successfully!'
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    console.error('❌ Error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 500 
    })
  }
})
