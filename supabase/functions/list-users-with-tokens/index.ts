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
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get all users with push tokens
    console.log('🔍 DEBUG: Fetching users with push tokens...')
    const { data: users, error } = await supabase
      .from('user_notification_preferences')
      .select('user_id, push_enabled, push_token, created_at')
      .not('push_token', 'is', null)
      .eq('push_enabled', true)

    if (error) {
      console.error('❌ Failed to fetch users:', error)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to fetch users',
        details: error
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      })
    }

    console.log('✅ DEBUG: Found users with push tokens:', users?.length || 0)

    // Return user list with token previews (for security)
    const userList = users?.map(user => ({
      user_id: user.user_id,
      push_enabled: user.push_enabled,
      has_token: !!user.push_token,
      token_preview: user.push_token ? user.push_token.substring(0, 12) + '...' : null,
      created_at: user.created_at
    })) || []

    return new Response(JSON.stringify({
      success: true,
      message: `Found ${userList.length} users with push tokens`,
      users: userList,
      total_count: userList.length
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    const message = (error as Error)?.message || String(error)
    console.error('❌ DEBUG: List users error:', message)
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})
