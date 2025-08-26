#!/bin/bash

# Test script for Stripe webhook events
# Usage: ./test_webhooks.sh

echo "=========================================="
echo "Testing Stripe Webhook Events for CampusLink"
echo "=========================================="
echo ""

# Payment Intent Events
echo "📱 Testing Payment Intent Events..."
echo "-----------------------------------"

echo "1. Testing payment_intent.succeeded..."
stripe trigger payment_intent.succeeded
sleep 2

echo "2. Testing payment_intent.payment_failed..."
stripe trigger payment_intent.payment_failed
sleep 2

echo "3. Testing payment_intent.canceled..."
stripe trigger payment_intent.canceled
sleep 2

echo "4. Testing payment_intent.processing..."
stripe trigger payment_intent.processing
sleep 2

echo "5. Testing payment_intent.requires_action..."
stripe trigger payment_intent.requires_action
sleep 2

# Charge Events
echo ""
echo "💳 Testing Charge Events..."
echo "-----------------------------------"

echo "6. Testing charge.dispute.created..."
stripe trigger charge.dispute.created
sleep 2

echo "7. Testing charge.succeeded..."
stripe trigger charge.succeeded
sleep 2

# Transfer Events (require Connect setup)
echo ""
echo "💸 Testing Transfer Events (Connect)..."
echo "-----------------------------------"
echo "Note: These require Stripe Connect to be configured"

echo "8. Attempting transfer.created..."
stripe trigger transfer.created 2>/dev/null || echo "⚠️ Transfer events require Connect setup"
sleep 2

echo "9. Attempting transfer.updated..."
stripe trigger transfer.updated 2>/dev/null || echo "⚠️ Transfer events require Connect setup"
sleep 2

# Account Events (require Connect setup)
echo ""
echo "👤 Testing Account Events (Connect)..."
echo "-----------------------------------"
echo "Note: These require Stripe Connect to be configured"

echo "10. Attempting account.updated..."
stripe trigger account.updated 2>/dev/null || echo "⚠️ Account events require Connect setup"

echo ""
echo "=========================================="
echo "✅ Test Summary"
echo "=========================================="
echo ""
echo "Payment Events: Should work immediately ✅"
echo "  - payment_intent.succeeded"
echo "  - payment_intent.payment_failed"
echo "  - payment_intent.canceled"
echo "  - payment_intent.processing"
echo "  - payment_intent.requires_action"
echo "  - charge.dispute.created"
echo "  - charge.succeeded"
echo ""
echo "Connect Events: Require Stripe Connect setup ⚠️"
echo "  - transfer.created"
echo "  - transfer.updated"
echo "  - transfer.paid"
echo "  - transfer.failed"
echo "  - account.updated"
echo ""
echo "Check your Stripe Dashboard for event details:"
echo "https://dashboard.stripe.com/test/webhooks"
echo ""
echo "Check your Supabase Edge Function logs:"
echo "https://app.supabase.com/project/vnmzijluyctlufnzxast/functions"
