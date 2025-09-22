import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@1.35.7'

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

    // Create Supabase client with older version
    const supabaseUrl = 'https://vnmzijluyctlufnzxast.supabase.co'
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw'
    
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Try the insert
    const { data, error } = await supabase
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

    return new Response(JSON.stringify({
      success: !error,
      data: data,
      error: error
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 500 
    })
  }
})
