-- Debug helpers to see full HTTP response bodies from pg_net
-- This solves the common issue where net.http_post returns a bytea body
-- that prints as numbers (e.g., 52, 53, 54...) instead of readable text.

-- Ensure pg_net is available
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Helper: POST JSON and return decoded body text
-- Usage:
--   select * from util_http_post_json_debug(
--     'https://<project>.functions.supabase.co/debug-notification-save',
--     jsonb_build_object('user_id', '<uuid>', 'title', 'Hello', 'body', 'World')::jsonb,
--     jsonb_build_object('Authorization', 'Bearer ' || '<service_or_anon_key>')
--   );
-- Returns status, headers, and body_text for easy inspection.
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

  -- Decode bytea body to readable UTF-8 text
  RETURN QUERY
  SELECT
    resp.status,
    resp.headers,
    convert_from(resp.body, 'UTF8') AS body_text;
END;
$$;

-- Variant: call and raise if non-2xx, returning the decoded body on success
CREATE OR REPLACE FUNCTION util_call_edge_or_raise(
  p_edge_url text,
  p_payload  jsonb,
  p_bearer   text
) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
  r RECORD;
BEGIN
  SELECT * INTO r
  FROM util_call_edge_json_debug(p_edge_url, p_payload, p_bearer);

  IF r.status < 200 OR r.status >= 300 THEN
    RAISE EXCEPTION 'Edge Function failed (status=%): %', r.status, r.body_text
      USING ERRCODE = 'P0001';
  END IF;

  RETURN r.body_text;
END;
$$;

-- Convenience helper specialized for calling Supabase Edge Functions with a Bearer token.
-- Provide the full function URL, or build it outside this function.
CREATE OR REPLACE FUNCTION util_call_edge_json_debug(
  p_edge_url text,
  p_payload  jsonb,
  p_bearer   text
) RETURNS TABLE(
  status     integer,
  headers    jsonb,
  body_text  text
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM util_http_post_json_debug(
    p_edge_url,
    p_payload,
    jsonb_build_object(
      'Authorization', 'Bearer ' || p_bearer,
      'Accept', 'application/json'
    )
  );
END;
$$;
