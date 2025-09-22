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

    console.log('📝 Direct INSERT test:', { user_id, title, body, type })

    // Create Supabase client
    const supabaseUrl = 'https://vnmzijluyctlufnzxast.supabase.co'
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw'
    
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Try direct INSERT instead of RPC
    const { data: insertData, error: insertError } = await supabase
      .from('notifications')
      .insert({
        user_id: user_id,
        type: type,
        title: title,
        body: body,
        data: data,
        is_delivered: false,
        delivered_at: null
      })
      .select()

    console.log('📊 Direct INSERT result:', { insertData, insertError })

    if (insertError) {
      console.error('❌ Direct INSERT failed:', insertError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Direct INSERT failed',
        details: insertError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ Direct INSERT succeeded')
    return new Response(JSON.stringify({
      success: true,
      message: 'Direct INSERT succeeded!',
      data: insertData
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
