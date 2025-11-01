#!/bin/bash

# Quick script to create a test user and get auth token

SUPABASE_URL="https://vnmzijluyctlufnzxast.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw"

TEST_EMAIL="test+payment@campuslink.com"
TEST_PASSWORD="TestPassword123!"

echo "🔧 Creating test user..."
echo "Email: $TEST_EMAIL"
echo ""

# Try to sign up
echo "Attempting signup..."
SIGNUP_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/signup" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${TEST_EMAIL}\",
    \"password\": \"${TEST_PASSWORD}\"
  }")

echo "$SIGNUP_RESPONSE" | jq '.'
echo ""

# Try to sign in (works even if user already exists)
echo "Getting auth token..."
LOGIN_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${TEST_EMAIL}\",
    \"password\": \"${TEST_PASSWORD}\"
  }")

ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" != "null" ] && [ -n "$ACCESS_TOKEN" ]; then
  echo "✅ Success! Auth token:"
  echo ""
  echo "$ACCESS_TOKEN"
  echo ""
  echo "📝 Copy this token and paste it into test_payment_intent.sh on line 29"
else
  echo "❌ Failed to get token. Response:"
  echo "$LOGIN_RESPONSE" | jq '.'
fi

