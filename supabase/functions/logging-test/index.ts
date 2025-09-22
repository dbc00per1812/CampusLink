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
    const body = await req.json()
    const { user_id, title, body: messageBody, type = 'new_message' } = body

    // Create Supabase client
    const supabaseUrl = 'https://vnmzijluyctlufnzxast.supabase.co'
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw'
    
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Log start
    await supabase.from('function_logs').insert({
      function_name: 'logging-test',
      message: 'Function started',
      data: { user_id, title, body: messageBody, type }
    })

    // Try the insert
    const { data: insertData, error: insertError } = await supabase
      .from('notifications')
      .insert({
        user_id: user_id,
        type: type,
        title: title,
        body: messageBody,
        data: {},
        is_delivered: false,
        delivered_at: null
      })
      .select()

    // Log result
    await supabase.from('function_logs').insert({
      function_name: 'logging-test',
      message: 'Insert attempt completed',
      data: { 
        success: !insertError,
        insertData: insertData,
        insertError: insertError
      }
    })

    return new Response(JSON.stringify({
      success: !insertError,
      insertData: insertData,
      insertError: insertError
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    // Log error
    const supabaseUrl = 'https://vnmzijluyctlufnzxast.supabase.co'
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw'
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    await supabase.from('function_logs').insert({
      function_name: 'logging-test',
      message: 'Function error',
      data: { error: error.message, stack: error.stack }
    })

    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 500 
    })
  }
})
