#!/bin/bash

# Direct APNs test script
# This tests the push notification directly without going through Supabase

# Set your values here
TEAM_ID="YOUR_TEAM_ID"
KEY_ID="YOUR_KEY_ID"
BUNDLE_ID="darragh.CampusLink"
DEVICE_TOKEN="d6437f23f221477e9955df8edc2da6c7358ef64bb14139fdd023473fbb77ab5c"

# Create JWT header and payload
HEADER=$(echo -n '{"alg":"ES256","kid":"'$KEY_ID'"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
PAYLOAD=$(echo -n '{"iss":"'$TEAM_ID'","iat":'$(date +%s)'}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

echo "Testing push to token: ${DEVICE_TOKEN:0:20}..."
echo "Bundle ID: $BUNDLE_ID"
echo "Environment: sandbox"

# Note: This requires the private key to be properly formatted
# The actual curl command would be:
# curl -v \
#   -H "authorization: bearer $JWT" \
#   -H "apns-topic: $BUNDLE_ID" \
#   -H "apns-push-type: alert" \
#   -H "apns-priority: 10" \
#   -d '{"aps":{"alert":{"title":"Test","body":"Direct APNs test"},"sound":"default"}}' \
#   https://api.sandbox.push.apple.com/3/device/$DEVICE_TOKEN

