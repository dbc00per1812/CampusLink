#!/bin/bash

# ============================================
# TRIGGER PUSH NOTIFICATION PROCESSING NOW
# ============================================
# This will process all 15 waiting notifications
# ============================================

echo "🔄 Triggering push notification processing..."
echo ""

# You need to set your service role key
# Get it from: Supabase Dashboard → Settings → API → service_role key (secret)

if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "❌ ERROR: SUPABASE_SERVICE_ROLE_KEY not set"
    echo ""
    echo "Run this first:"
    echo "export SUPABASE_SERVICE_ROLE_KEY='your-service-role-key-here'"
    echo ""
    exit 1
fi

# Call the edge function
response=$(curl -s -X POST \
  'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue' \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}')

echo "Response:"
echo "$response"
echo ""
echo "✅ Done! Check your phone for notifications!"
echo ""
echo "Verify in Supabase:"
echo "SELECT COUNT(*) FROM push_notification_queue WHERE processed = true;"


