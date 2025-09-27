-- Push Notification Logging System (Audit Recommendations)
-- This implements the audit's recommendation for comprehensive logging

-- Enable pg_net extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create notification logs table for tracking HTTP calls (audit recommendation)
CREATE TABLE IF NOT EXISTS public.notification_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  notification_id uuid REFERENCES public.notifications(id),
  user_id uuid REFERENCES public.users(id),
  edge_function_url text NOT NULL,
  request_payload jsonb NOT NULL,
  response_status integer,
  response_headers jsonb,
  response_body text,
  apns_status integer,
  apns_error text,
  created_at timestamp with time zone DEFAULT now(),
  error_message text
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON public.notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_created_at ON public.notification_logs(created_at);

-- Helper function to log HTTP calls with decoded body (audit recommendation)
CREATE OR REPLACE FUNCTION util_http_post_json_debug(
  p_url     text,
  p_body    jsonb,
  p_headers jsonb DEFAULT '{}'::jsonb
) RETURNS TABLE(
  status     integer,
  headers    jsonb,
  body_text  text
) LANGUAGE plpgsql AS $$
DECLARE
  resp   net.http_response;
  hdrs   jsonb;
BEGIN
  -- Always send JSON content-type; merge with provided headers
  hdrs := coalesce(p_headers, '{}'::jsonb) || jsonb_build_object('Content-Type', 'application/json');

  -- Perform the HTTP call; pg_net returns a structured response with a bytea body
  resp := net.http_post(
    url     => p_url,
    headers => hdrs,
    body    => p_body::text
  );

  -- Decode bytea body to readable UTF-8 text (audit recommendation)
  RETURN QUERY
  SELECT
    resp.status,
    resp.headers,
    convert_from(resp.body, 'UTF8') AS body_text;
END;
$$;

-- Function to call edge function and log the result (audit recommendation)
CREATE OR REPLACE FUNCTION call_push_notification_with_logging(
  p_user_id text,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_type text DEFAULT 'debug_test'
) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  edge_url text;
  payload jsonb;
  response_status integer;
  response_headers jsonb;
  response_body text;
  log_id uuid;
  result jsonb;
BEGIN
  -- Build the edge function URL
  edge_url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/debug-push-complete';
  
  -- Build the payload
  payload := jsonb_build_object(
    'user_id', p_user_id,
    'title', p_title,
    'body', p_body,
    'data', p_data,
    'type', p_type
  );
  
  -- Call the edge function and get response details (audit recommendation)
  SELECT status, headers, body_text
  INTO response_status, response_headers, response_body
  FROM util_http_post_json_debug(
    edge_url,
    payload,
    jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    )
  );
  
  -- Create log entry (audit recommendation)
  INSERT INTO public.notification_logs (
    user_id,
    edge_function_url,
    request_payload,
    response_status,
    response_headers,
    response_body,
    created_at
  ) VALUES (
    p_user_id::uuid,
    edge_url,
    payload,
    response_status,
    response_headers,
    response_body,
    now()
  ) RETURNING id INTO log_id;
  
  -- Parse response body as JSON if possible
  BEGIN
    result := response_body::jsonb;
  EXCEPTION WHEN OTHERS THEN
    result := jsonb_build_object(
      'success', false,
      'error', 'Failed to parse response',
      'raw_response', response_body
    );
  END;
  
  -- Add log ID to result
  result := result || jsonb_build_object('log_id', log_id);
  
  -- Log the result (audit recommendation)
  RAISE NOTICE 'Push notification call completed: status=%, log_id=%, result=%', 
    response_status, log_id, result;
  
  RETURN result;
END;
$$;

-- Function to test push notifications (audit recommendation)
CREATE OR REPLACE FUNCTION test_push_notification_flow(
  p_user_id text
) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  result jsonb;
  user_prefs record;
BEGIN
  -- Check if user has push token
  SELECT push_token, push_enabled 
  INTO user_prefs
  FROM public.user_notification_preferences 
  WHERE user_id = p_user_id::uuid;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found in notification preferences'
    );
  END IF;
  
  IF NOT user_prefs.push_enabled THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Push notifications disabled for user'
    );
  END IF;
  
  IF user_prefs.push_token IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No push token found for user'
    );
  END IF;
  
  -- Send test notification
  result := call_push_notification_with_logging(
    p_user_id,
    'Test Notification',
    'This is a test push notification from CampusLink',
    jsonb_build_object('test', true),
    'debug_test'
  );
  
  RETURN result;
END;
$$;

-- Function to get push notification logs for debugging (audit recommendation)
CREATE OR REPLACE FUNCTION get_push_notification_logs(
  p_user_id text DEFAULT NULL,
  p_limit integer DEFAULT 10
) RETURNS TABLE(
  log_id uuid,
  user_id uuid,
  notification_id uuid,
  edge_function_url text,
  request_payload jsonb,
  response_status integer,
  response_body text,
  created_at timestamp with time zone,
  error_message text
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    nl.id,
    nl.user_id,
    nl.notification_id,
    nl.edge_function_url,
    nl.request_payload,
    nl.response_status,
    nl.response_body,
    nl.created_at,
    nl.error_message
  FROM public.notification_logs nl
  WHERE (p_user_id IS NULL OR nl.user_id = p_user_id::uuid)
  ORDER BY nl.created_at DESC
  LIMIT p_limit;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION call_push_notification_with_logging(text, text, text, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION test_push_notification_flow(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_push_notification_logs(text, integer) TO authenticated;
GRANT SELECT ON public.notification_logs TO authenticated;

-- Add RLS policies for notification_logs
ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notification logs" ON public.notification_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage notification logs" ON public.notification_logs
  FOR ALL USING (auth.role() = 'service_role');
