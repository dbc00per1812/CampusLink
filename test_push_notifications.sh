#!/bin/bash

# Test Push Notifications Script
# This manually triggers the queue processor for testing

echo "🧪 Testing Push Notification System..."

# Step 1: Send a test message
echo "📤 Sending test message..."
curl -X POST "https://vnmzijluyctlufnzxast.supabase.co/functions/v1/test-messaging" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "fa4c2be3-3d26-4777-a8b5-b030d4d7b4af",
    "sender_id": "d4c8cd57-c182-4eed-a961-b24651061676",
    "content": "Test message from script"
  }'

# Wait a moment for the trigger to fire
echo "⏳ Waiting for trigger to process..."
sleep 2

# Step 2: Process the queue
echo "🔄 Processing notification queue..."
curl -X POST "https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw" \
  -H "Content-Type: application/json"

echo "✅ Test complete!"

