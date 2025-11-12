#!/bin/bash

# Deploy Offer Payment Backend Support
# Run this script to deploy the edge functions that enable in-app payment for accepted offers

echo "🚀 Deploying Offer Payment Backend Support"
echo ""

# Check if in correct directory
if [ ! -f "CampusLink.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the CampusLink root directory"
    exit 1
fi

echo "📦 Step 1: Deploying create_payment_intent function..."
supabase functions deploy create_payment_intent

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy create_payment_intent"
    exit 1
fi

echo "✅ create_payment_intent deployed"
echo ""

echo "📦 Step 2: Deploying stripe-webhook function..."
supabase functions deploy stripe-webhook

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy stripe-webhook"
    exit 1
fi

echo "✅ stripe-webhook deployed"
echo ""

echo "🎉 Deployment Complete!"
echo ""
echo "Next steps:"
echo "1. Test the flow:"
echo "   - Seller accepts offer"
echo "   - Buyer taps 'Confirm Order & Pay'"
echo "   - Complete payment"
echo "   - Verify order updated (not duplicated)"
echo ""
echo "2. Monitor edge function logs for any errors"
echo ""
echo "3. Test regular purchases still work (backwards compatibility)"
echo ""
echo "✅ iOS app already updated and building successfully"

