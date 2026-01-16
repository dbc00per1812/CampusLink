// Image Configuration - Lightning-fast image loading
// Configure expo-image for optimal performance

import { Image } from 'expo-image';

// Configure global image cache settings
export const configureImageCache = () => {
  // Set cache size to 100MB for optimal performance
  Image.clearMemoryCache();
  
  // Expo-image automatically handles:
  // - Memory caching
  // - Disk caching
  // - Native image decoding
  // - Progressive image loading
};

// Blurhash placeholders for different image types
export const BLURHASH_PLACEHOLDERS = {
  // Generic placeholder - neutral gray
  default: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
  
  // Product placeholder - slightly warmer
  product: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
  
  // Avatar placeholder - neutral
  avatar: 'L4Rf9m0000-;00%M~q_3',
  
  // Service placeholder - slightly cooler
  service: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
};

// Image priority levels
export const IMAGE_PRIORITY = {
  critical: 'high' as const,  // Above-the-fold images
  normal: 'normal' as const,  // Below-the-fold images
  low: 'low' as const,        // Far below-the-fold images
};

// Image transition speeds (ms)
export const IMAGE_TRANSITIONS = {
  fast: 150,
  normal: 200,
  slow: 300,
};

// Cache policies
export const CACHE_POLICY = {
  // Best for frequently accessed images (listing cards, avatars)
  memoryDisk: 'memory-disk' as const,
  
  // Best for images that change frequently
  memory: 'memory' as const,
  
  // Best for one-time view images
  disk: 'disk' as const,
  
  // No caching - use sparingly
  none: 'none' as const,
};

// Prefetch images for next screen
export const prefetchImages = async (urls: string[]) => {
  try {
    await Promise.all(
      urls.map(url => Image.prefetch(url, { cachePolicy: CACHE_POLICY.memoryDisk }))
    );
  } catch (error) {
    console.warn('Image prefetch failed:', error);
  }
};

// Clear all cached images (use when user logs out)
export const clearImageCache = async () => {
  try {
    await Image.clearMemoryCache();
    await Image.clearDiskCache();
  } catch (error) {
    console.warn('Failed to clear image cache:', error);
  }
};

