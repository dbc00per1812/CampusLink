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
    console.log('🚀 Debug function started')
    
    const { user_id, title, body, type = 'new_message', data = {} } = await req.json()
    console.log('📝 Received data:', { user_id, title, body, type, data })

    // Create Supabase client
    const supabaseUrl = 'https://vnmzijluyctlufnzxast.supabase.co'
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw'
    
    console.log('🔗 Creating Supabase client with URL:', supabaseUrl)
    const supabase = createClient(supabaseUrl, supabaseKey)
    console.log('✅ Supabase client created')

    // Test basic connection first
    console.log('🔍 Testing basic connection...')
    const { data: testData, error: testError } = await supabase
      .from('notifications')
      .select('count')
      .limit(1)
    
    if (testError) {
      console.error('❌ Basic connection test failed:', testError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Basic connection test failed',
        details: testError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }
    console.log('✅ Basic connection test passed')

    // Test RPC function exists
    console.log('🔍 Testing RPC function...')
    const { data: rpcData, error: rpcError } = await supabase
      .rpc('insert_notification', {
        p_user_id: user_id,
        p_type: type,
        p_title: title,
        p_body: body,
        p_data: data,
        p_is_delivered: false,
        p_delivered_at: null
      })

    console.log('📊 RPC result:', { rpcData, rpcError })

    if (rpcError) {
      console.error('❌ RPC call failed:', rpcError)
      return new Response(JSON.stringify({
        success: false,
        error: 'RPC call failed',
        details: rpcError
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ RPC call succeeded, returned:', rpcData)

    // Verify the notification was actually saved
    console.log('🔍 Verifying notification was saved...')
    const { data: verifyData, error: verifyError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(1)

    if (verifyError) {
      console.error('❌ Verification query failed:', verifyError)
    } else {
      console.log('📋 Verification result:', verifyData)
    }

    console.log('✅ Debug function completed successfully')
    return new Response(JSON.stringify({
      success: true,
      message: 'Debug completed successfully!',
      rpcResult: rpcData,
      verification: verifyData
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    console.error('❌ Debug function error:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 500 
    })
  }
})
