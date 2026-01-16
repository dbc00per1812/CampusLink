/**
 * Expo config plugin to strip bitcode from SnapSDK frameworks.
 * Apple deprecated bitcode and rejects apps containing it.
 * The snap-kit-react-native package uses SnapSDK 1.15.0 which still has bitcode.
 */
const { withDangerousMod } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

function withSnapKitFix(config) {
  return withDangerousMod(config, [
    'ios',
    async (config) => {
      const podfilePath = path.join(config.modRequest.platformProjectRoot, 'Podfile');
      
      let podfileContent = fs.readFileSync(podfilePath, 'utf-8');
      
      // Add bitcode stripping script to post_install
      const stripBitcodeScript = `
    # Strip bitcode from SnapSDK frameworks (they ship with bitcode but Apple no longer accepts it)
    snap_frameworks = ['SCSDKCoreKit', 'SCSDKCreativeKit', 'SCSDKLoginKit']
    pods_dir = installer.sandbox.root
    snap_frameworks.each do |framework_name|
      framework_path = File.join(pods_dir, 'SnapSDK', framework_name + '.xcframework')
      if Dir.exist?(framework_path)
        Dir.glob(File.join(framework_path, '**', framework_name)).each do |binary|
          if File.file?(binary)
            puts "Stripping bitcode from: #{binary}"
            system("xcrun bitcode_strip -r \\"#{binary}\\" -o \\"#{binary}\\" 2>/dev/null || true")
          end
        end
      end
    end
`;
      
      // Insert before the closing of post_install block
      if (!podfileContent.includes("Strip bitcode from SnapSDK")) {
        // Find post_install block and add our script before the end
        podfileContent = podfileContent.replace(
          /post_install do \|installer\|([\s\S]*?)(^\s*end\s*$)/m,
          (match, content, endStatement) => {
            return `post_install do |installer|${content}${stripBitcodeScript}${endStatement}`;
          }
        );
        
        fs.writeFileSync(podfilePath, podfileContent);
      }
      
      return config;
    },
  ]);
}

module.exports = withSnapKitFix;
