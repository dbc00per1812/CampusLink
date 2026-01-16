/**
 * Expo config plugin to strip bitcode from embedded frameworks.
 * Required because Snapchat SDK xcframeworks contain bitcode, which Apple no longer accepts.
 */
const { withXcodeProject } = require('@expo/config-plugins');

function stripBitcodePlugin(config) {
  return withXcodeProject(config, async (config) => {
    const xcodeProject = config.modResults;
    
    const shellScript = `
# Strip bitcode from all embedded frameworks
echo "Stripping bitcode from embedded frameworks..."
find "\${BUILT_PRODUCTS_DIR}/\${FRAMEWORKS_FOLDER_PATH}" -name "*.framework" -type d 2>/dev/null | while read framework; do
  if [ -d "$framework" ]; then
    binary=$(basename "$framework" .framework)
    binary_path="$framework/$binary"
    if [ -f "$binary_path" ]; then
      echo "Stripping bitcode from $binary"
      xcrun bitcode_strip -r "$binary_path" -o "$binary_path" 2>/dev/null || true
    fi
  fi
done
echo "Bitcode stripping complete"
`;

    // Add a new build phase
    xcodeProject.addBuildPhase(
      [],
      'PBXShellScriptBuildPhase',
      'Strip Bitcode from Frameworks',
      xcodeProject.getFirstTarget().uuid,
      {
        shellPath: '/bin/sh',
        shellScript: shellScript,
      }
    );

    return config;
  });
}

module.exports = stripBitcodePlugin;

