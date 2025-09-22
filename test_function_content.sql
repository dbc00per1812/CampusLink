-- Test to get the actual response content from the function
-- This will show us what the function is actually returning

WITH function_response AS (
  SELECT 
    net.http_post(
      url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/debug-user-lookup',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw',
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'user_id', 'd4c8cd57-c182-4eed-a961-b24651061676'
      )
    ) as status_code
)
SELECT 
  status_code,
  'Status code: ' || status_code as interpretation
FROM function_response;
