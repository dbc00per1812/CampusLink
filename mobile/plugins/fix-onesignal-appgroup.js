/**
 * Custom Expo Config Plugin to fix OneSignal App Group ID case mismatch
 * 
 * The OneSignal plugin generates App Group ID based on bundle identifier (darragh.CampusLink)
 * but Apple has it registered as lowercase (group.darragh.campuslink.onesignal)
 * 
 * This plugin runs AFTER OneSignal and fixes the case by using withEntitlementsPlist.
 */
const { withEntitlementsPlist, withDangerousMod } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

// The wrong App Group ID that OneSignal generates
const WRONG_APP_GROUP = 'group.darragh.CampusLink.onesignal';
// The correct App Group ID registered in Apple Developer Portal
const CORRECT_APP_GROUP = 'group.darragh.campuslink.onesignal';

/**
 * Fix the main app entitlements using withEntitlementsPlist
 * This runs in the same phase as OneSignal's plugin, but AFTER it (due to plugin order)
 */
const withFixedAppGroupEntitlements = (config) => {
  return withEntitlementsPlist(config, (config) => {
    const entitlements = config.modResults;
    const APP_GROUP_KEY = 'com.apple.security.application-groups';
    
    // Get current app groups
    let appGroups = entitlements[APP_GROUP_KEY] || [];
    
    console.log('[fix-onesignal-appgroup] Before fix:', appGroups);
    
    // Replace wrong case with correct case
    appGroups = appGroups.map(group => 
      group === WRONG_APP_GROUP ? CORRECT_APP_GROUP : group
    );
    
    // Remove duplicates
    appGroups = [...new Set(appGroups)];
    
    console.log('[fix-onesignal-appgroup] After fix:', appGroups);
    
    entitlements[APP_GROUP_KEY] = appGroups;
    
    return config;
  });
};

/**
 * Fix the notification service extension entitlements
 * Uses withDangerousMod to modify the file after it's been created
 */
const withFixedExtensionEntitlements = (config) => {
  return withDangerousMod(config, [
    'ios',
    async (config) => {
      const projectRoot = config.modRequest.projectRoot;
      const extensionEntitlementsPath = path.join(
        projectRoot,
        'ios',
        'OneSignalNotificationServiceExtension',
        'OneSignalNotificationServiceExtension.entitlements'
      );
      
      // Wait a bit for the file to be created by OneSignal plugin
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Check if extension entitlements file exists
      if (fs.existsSync(extensionEntitlementsPath)) {
        let content = fs.readFileSync(extensionEntitlementsPath, 'utf8');
        
        // Replace wrong case with correct case
        if (content.includes(WRONG_APP_GROUP)) {
          content = content.replace(new RegExp(WRONG_APP_GROUP.replace(/\./g, '\\.'), 'g'), CORRECT_APP_GROUP);
          fs.writeFileSync(extensionEntitlementsPath, content);
          console.log('[fix-onesignal-appgroup] Fixed extension entitlements');
        } else {
          console.log('[fix-onesignal-appgroup] Extension already correct or not created yet');
        }
      } else {
        console.log('[fix-onesignal-appgroup] Extension entitlements not found yet (will be fixed by build script)');
      }
      
      return config;
    },
  ]);
};

/**
 * Main plugin export
 */
module.exports = (config) => {
  config = withFixedAppGroupEntitlements(config);
  config = withFixedExtensionEntitlements(config);
  return config;
};
