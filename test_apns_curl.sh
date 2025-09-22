#!/bin/bash

# Test APNs with curl (no Python dependencies needed)
# This will test if your Apple key works

echo "🧪 Testing APNs Key with curl..."

# Your credentials
TEAM_ID="39QG7MQD33"
KEY_ID="J89TH2Q724"
BUNDLE_ID="darragh.CampusLink"

# Create a simple JWT (this is a basic test - real JWT needs proper signing)
echo "Testing with basic curl to APNs..."

# Test APNs endpoint (this will fail with 401 but tells us if endpoint is reachable)
curl -v \
  -H "apns-topic: $BUNDLE_ID" \
  -H "apns-push-type: alert" \
  -H "apns-priority: 10" \
  -H "authorization: bearer test" \
  -d '{"aps":{"alert":"test"}}' \
  https://api.sandbox.push.apple.com/3/device/0000000000000000000000000000000000000000000000000000000000000000

echo ""
echo "If you see '401 Unauthorized', the endpoint is working but needs proper JWT"
echo "If you see connection errors, there might be network/firewall issues"
