Short answer: because push is a 3-system handshake (Apple ↔ your server/edge ↔ your database/app) where any tiny mismatch silently fails. With Swift + APNs + Supabase, there are a lot of places to misconfigure—often with no error surfaced in the spot you’re looking.

Here’s why it’s been so hard (and where things usually break):

APNs gotchas (iOS side)

Dev vs Prod tokens: debug builds get sandbox tokens; release/TestFlight get production tokens. Sending a sandbox token to the prod APNs host (or vice-versa) = no delivery, no error.

apns-topic mismatch: the topic must equal your bundle ID (or .voip/NSE when relevant). Wrong topic → silent drop.

Entitlements/capabilities: Push Notifications capability + correct team/bundle. A missing/incorrect entitlement kills delivery.

Token handling: Don’t base64 your deviceToken; send the hex string. Update it on every app launch (tokens rotate).

User/device filters: Focus modes, notification settings, and “Deliver Quietly” look like “server is broken” when it’s really iOS.

Edge Function ↔ APNs (server side)

APNs auth: p8 key (token-based) or certs (deprecated path). Wrong Key ID/Team ID/Bundle or expired key → APNs rejects. If you don’t log and surface APNs responses (HTTP/2 status, reason), you won’t see why.

Wrong APNs host: api.sandbox.push.apple.com for dev tokens; api.push.apple.com for prod tokens.

Headers: apns-push-type (alert/background) must match payload. Wrong push-type = drop.

Postgres trigger ↔ Edge Function (Supabase side)

RLS/permissions confusion: Triggers run in the DB, not as your client. If your trigger function queries tables with RLS and isn’t SECURITY DEFINER (or sets a privileged role), it can fail silently before the HTTP call.

HTTP from Postgres: You’re relying on pg_net/http to net.http_post out of the DB. If the extension isn’t enabled, egress is blocked, timeouts are too low, or the call isn’t committed (trigger timing), it won’t reach your function.

Auth to the function: Most Edge Functions require a valid Supabase JWT. From Postgres, you must include an Authorization: Bearer <service_role> (or make the function verify_jwt: false for testing). Missing/invalid token = the function never “counts” as invoked.

Wrong URL: Calling the project’s function URL (not localhost), exact function path, and region. A tiny path/region mismatch yields 404s that you won’t see unless you capture the response in SQL.

No telemetry: If the SQL trigger ignores the net.http_post result (status/body) and doesn’t RAISE NOTICE or write to a log table, you won’t see the error—and Functions will show “0 invocations,” making you chase RLS instead.

Architecture friction (design choice)

DB triggers that “phone out” are brittle. A more reliable pattern is:

Insert into notifications table.

Background worker (Edge Function on schedule/queue) pulls new rows and pushes to APNs, with retries + dead-letter.

This keeps secrets out of SQL, gives you logs/retries, and avoids Postgres-to-HTTP flakiness.

A deterministic path to green (do these now)

In SQL, log the HTTP call: capture status, body, attempted_url, and headers from net.http_post into a notification_logs table; add RAISE NOTICE for failures.

Temporarily set the Edge Function to verify_jwt: false. Call it from the trigger without auth first; confirm the invocation count increments. Then re-enable auth and pass service_role in the Authorization header.

From the SQL editor, manually call the function URL via net.http_post with a tiny { "ping": true } payload. Verify 200 in the returned JSON; store it.

In the Edge Function, log APNs responses (HTTP/2 status + JSON reason) and persist failures.

Verify the APNs environment: print first 8 chars of deviceToken in the app and tag it as sandbox vs prod. Make sure your server uses the matching APNs host.

Confirm apns-topic == bundle identifier and correct apns-push-type.

Re-register for remote notifications on app launch; ensure the token saved in Supabase matches the device’s latest.

Run a single end-to-end test: insert one row, see one Edge invocation, see one APNs response, then one notification on device.

Add retry with backoff + a status column (pending/sending/sent/failed) in notifications.

(Optional but recommended) Move to a queue/cron worker: let an Edge Function run every minute (or use Supabase Queues) to process pending rows; remove the DB-to-HTTP trigger.