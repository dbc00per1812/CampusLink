// Learn more https://docs.expo.io/guides/customizing-metro
const { getDefaultConfig } = require('expo/metro-config');

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

// Add HTML and PDF to asset extensions so we can bundle legal documents
config.resolver.assetExts.push('html', 'pdf');

module.exports = config;
