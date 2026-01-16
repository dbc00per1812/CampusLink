#!/bin/bash
# Fix OneSignal App Group ID case mismatch
# This script replaces the wrong case with the correct one in entitlements files

echo "[fix-appgroup] Fixing App Group IDs..."

WRONG_GROUP="group.darragh.CampusLink.onesignal"
CORRECT_GROUP="group.darragh.campuslink.onesignal"

# Fix main app entitlements
MAIN_ENTITLEMENTS="ios/CampusLink/CampusLink.entitlements"
if [ -f "$MAIN_ENTITLEMENTS" ]; then
  if grep -q "$WRONG_GROUP" "$MAIN_ENTITLEMENTS"; then
    # Replace wrong with correct (not delete)
    sed -i '' "s|$WRONG_GROUP|$CORRECT_GROUP|g" "$MAIN_ENTITLEMENTS"
    echo "[fix-appgroup] Fixed main app entitlements"
  else
    echo "[fix-appgroup] Main app entitlements already correct"
  fi
else
  echo "[fix-appgroup] Main app entitlements not found"
fi

# Fix extension entitlements
EXT_ENTITLEMENTS="ios/OneSignalNotificationServiceExtension/OneSignalNotificationServiceExtension.entitlements"
if [ -f "$EXT_ENTITLEMENTS" ]; then
  if grep -q "$WRONG_GROUP" "$EXT_ENTITLEMENTS"; then
    # Replace wrong with correct
    sed -i '' "s|$WRONG_GROUP|$CORRECT_GROUP|g" "$EXT_ENTITLEMENTS"
    echo "[fix-appgroup] Fixed extension entitlements"
  else
    echo "[fix-appgroup] Extension entitlements already correct"
  fi
else
  echo "[fix-appgroup] Extension entitlements not found"
fi

echo "[fix-appgroup] Done!"

# Show results
echo "[fix-appgroup] Verification:"
grep -A2 "application-groups" "$MAIN_ENTITLEMENTS" 2>/dev/null || true
grep -A2 "application-groups" "$EXT_ENTITLEMENTS" 2>/dev/null || true
