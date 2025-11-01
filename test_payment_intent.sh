#!/bin/bash

# Test script for create_payment_intent edge function
# Usage: ./test_payment_intent.sh <listing_id> <quantity>

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧪 Testing create_payment_intent Edge Function${NC}"
echo ""

# Check if arguments provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Missing listing_id${NC}"
    echo "Usage: ./test_payment_intent.sh <fcada9bd-3fdd-4b00-9cc5-27377aba314b> <1>"
    echo "Example: ./test_payment_intent.sh 123e4567-e89b-12d3-a456-426614174000 2"
    exit 1
fi

LISTING_ID=$1
QUANTITY=${2:-1}  # Default to 1 if not provided

# Get these from your .env or Supabase dashboard
SUPABASE_URL="https://vnmzijluyctlufnzxast.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw"
USER_AUTH_TOKEN="YOUR_USER_JWT_TOKEN"  # 👈 GET THIS: Log into your app, then run in browser console: localStorage.getItem('supabase.auth.token')

echo "📋 Test Parameters:"
echo "   Listing ID: $LISTING_ID"
echo "   Quantity: $QUANTITY"
echo ""

# Make the request
echo -e "${YELLOW}📡 Sending request...${NC}"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${SUPABASE_URL}/functions/v1/create_payment_intent" \
  -H "Authorization: Bearer ${USER_AUTH_TOKEN}" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"listing_id\": \"${LISTING_ID}\",
    \"quantity\": ${QUANTITY}
  }")

# Split response body and status code (macOS compatible)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
HTTP_BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo ""

# Pretty print JSON response
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Success!${NC}"
    echo ""
    echo "Response:"
    echo "$HTTP_BODY" | jq '.' 2>/dev/null || echo "$HTTP_BODY"
    echo ""
    
    # Parse and display pricing breakdown
    SELLER_PRICE=$(echo "$HTTP_BODY" | jq -r '.seller_price_cents // 0')
    BUYER_PRICE=$(echo "$HTTP_BODY" | jq -r '.buyer_price_cents // 0')
    STRIPE_FEE=$(echo "$HTTP_BODY" | jq -r '.stripe_fee_cents // 0')
    CAMPUSLINK_CUT=$(echo "$HTTP_BODY" | jq -r '.campuslink_cut_cents // 0')
    
    if [ "$SELLER_PRICE" != "0" ]; then
        echo -e "${GREEN}💰 Pricing Breakdown:${NC}"
        echo "   Seller receives: \$$(echo "scale=2; $SELLER_PRICE/100" | bc)"
        echo "   Buyer pays: \$$(echo "scale=2; $BUYER_PRICE/100" | bc)"
        echo "   Stripe fee: \$$(echo "scale=2; $STRIPE_FEE/100" | bc)"
        echo "   🎯 CampusLink cut: \$$(echo "scale=2; $CAMPUSLINK_CUT/100" | bc)"
    fi
else
    echo -e "${RED}❌ Error!${NC}"
    echo ""
    echo "Response:"
    echo "$HTTP_BODY" | jq '.' 2>/dev/null || echo "$HTTP_BODY"
fi

echo ""

