#!/bin/bash

# Verify Stripe Application Fees
# This script checks recent payments and application fees in your Stripe account

echo "🔍 Checking recent Stripe payments and application fees..."
echo ""

# Check if Stripe CLI is installed
if ! command -v stripe &> /dev/null; then
    echo "❌ Stripe CLI not installed"
    echo ""
    echo "To install:"
    echo "  macOS: brew install stripe/stripe-cli/stripe"
    echo "  Other: https://stripe.com/docs/stripe-cli"
    echo ""
    echo "Or check manually at: https://dashboard.stripe.com/test/payments"
    exit 1
fi

# Check if logged in
if ! stripe config --list &> /dev/null; then
    echo "❌ Not logged in to Stripe CLI"
    echo "Run: stripe login"
    exit 1
fi

echo "📊 Recent Payment Intents (last 5):"
echo "════════════════════════════════════════════════════════════"
stripe payment_intents list --limit 5

echo ""
echo ""
echo "💰 Recent Application Fees (last 10):"
echo "════════════════════════════════════════════════════════════"
stripe application_fees list --limit 10

echo ""
echo ""
echo "📈 Your Balance:"
echo "════════════════════════════════════════════════════════════"
stripe balance retrieve

echo ""
echo "✅ Done! Check the output above for:"
echo "   - Payment Intents with status: succeeded"
echo "   - Application fees collected"
echo "   - Your available balance"


