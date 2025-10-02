#!/bin/bash

# Test the delete_user edge function
SUPABASE_URL="https://vnmzijluyctlufnzxast.supabase.co"
FUNCTION_URL="$SUPABASE_URL/functions/v1/delete_user"

echo "Testing delete_user edge function..."
echo "URL: $FUNCTION_URL"

# Test with invalid token (should get 401)
echo "Testing with invalid token..."
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid-token" \
  -d '{}' \
  -w "\nHTTP Status: %{http_code}\n" \
  -s

echo -e "\n\nTesting with no token..."
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{}' \
  -w "\nHTTP Status: %{http_code}\n" \
  -s

echo -e "\n\nTesting with GET method (should get 405)..."
curl -X GET "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s
