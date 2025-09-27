HTTP debug helpers for pg_net

Why you’re seeing numbers like 52, 53, 54…
- pg_net’s `net.http_post` returns the response body as `bytea`.
- When printed directly, Postgres shows the raw byte values (52='4', 53='5', 54='6', 55='7', 56='8'), not the text.
- Decode the body with `convert_from(..., 'UTF8')` to read the JSON/string.

What’s included
- `util_http_post_json_debug(url, body_jsonb, headers_jsonb)`
  - Calls `net.http_post` and returns: `status`, `headers`, and `body_text` (UTF‑8 decoded).
- `util_call_edge_json_debug(edge_url, payload_jsonb, bearer)`
  - Convenience wrapper for Supabase Edge Functions using a Bearer token.

Enable and use
1) Run the helper SQL (requires `pg_net`):
   - File: `supabase/sql/http_debug.sql`

2) Example: call your Edge Function and view the real error/details
```
select *
from util_http_post_json_debug(
  'https://<project-ref>.functions.supabase.co/debug-notification-save',
  jsonb_build_object(
    'user_id', '<uuid>',
    'title', 'Test',
    'body',  'Hello world',
    'type',  'new_message'
  )::jsonb,
  jsonb_build_object(
    'Authorization', 'Bearer ' || '<SERVICE_OR_ANON_KEY>',
    'Accept', 'application/json'
  )
);
```

3) If you prefer the dedicated wrapper with Bearer
```
select *
from util_call_edge_json_debug(
  'https://<project-ref>.functions.supabase.co/debug-notification-save',
  jsonb_build_object(
    'user_id', '<uuid>',
    'title', 'Test',
    'body',  'Hello world'
  )::jsonb,
  '<SERVICE_OR_ANON_KEY>'
);
```

Tips
- Ensure your Edge Function returns JSON and sets `Content-Type: application/json` on both success and error paths.
- Log server-side with `console.error(...)` inside the function; check Supabase Function logs for stack traces.
- If RLS is on, use the service role key inside the function (`SUPABASE_SERVICE_ROLE_KEY`) or add proper policies.
- If you still get empty bodies, verify CORS preflight handling and that non‑200 responses still return a JSON payload.

