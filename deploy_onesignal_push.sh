#!/bin/bash
# Deploy OneSignal Push Notification Edge Function to Supabase

set -e

echo "🚀 Deploying OneSignal Push Notification Edge Function..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

echo ""
echo "${YELLOW}📋 Setting environment secrets...${NC}"

# Set OneSignal App ID
echo "Setting ONESIGNAL_APP_ID..."
supabase secrets set ONESIGNAL_APP_ID=cb72afc9-84c6-4cfc-8cc3-64f63d1700c1

# Set OneSignal REST API Key
echo "Setting ONESIGNAL_REST_API_KEY..."
supabase secrets set ONESIGNAL_REST_API_KEY=os_v2_app_znzk7smeyzgpzdgdmt3d2fyaygrqwhvvis5ub6e6dzatew45bwht56hbk3ossykighoaexsq3q67qmkrrjb4zwvpaq3hc7bnhdoigey

echo ""
echo "${YELLOW}📦 Deploying edge function...${NC}"

# Deploy the function
supabase functions deploy send-push-onesignal

echo ""
echo "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Test the function:"
echo "  supabase functions invoke send-push-onesignal --data '{\"user_id\":\"your-uuid\",\"title\":\"Test\",\"body\":\"Hello\"}'"
echo ""
echo "View logs:"
echo "  supabase functions logs send-push-onesignal"
echo ""

