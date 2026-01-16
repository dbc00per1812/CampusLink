// Performance Optimization Utilities
// Lightning-fast React Native optimizations

import { Platform } from 'react-native';
import { InteractionManager } from 'react-native';

/**
 * Run heavy operations after interactions are complete
 * Use this for non-critical tasks that shouldn't block UI
 */
export const runAfterInteractions = (callback: () => void) => {
  InteractionManager.runAfterInteractions(() => {
    callback();
  });
};

/**
 * Debounce function for search and scroll events
 */
export const debounce = <T extends (...args: any[]) => any>(
  func: T,
  wait: number
): ((...args: Parameters<T>) => void) => {
  let timeout: NodeJS.Timeout;
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
};

/**
 * Throttle function for high-frequency events
 */
export const throttle = <T extends (...args: any[]) => any>(
  func: T,
  limit: number
): ((...args: Parameters<T>) => void) => {
  let inThrottle: boolean;
  return (...args: Parameters<T>) => {
    if (!inThrottle) {
      func(...args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
};

/**
 * Memoize expensive computations
 */
export const memoize = <T extends (...args: any[]) => any>(fn: T) => {
  const cache = new Map();
  return (...args: Parameters<T>): ReturnType<T> => {
    const key = JSON.stringify(args);
    if (cache.has(key)) {
      return cache.get(key);
    }
    const result = fn(...args);
    cache.set(key, result);
    return result;
  };
};

/**
 * Get optimal FlatList configuration based on device
 */
export const getOptimalFlatListConfig = () => {
  // iOS handles large lists better
  const isIOS = Platform.OS === 'ios';
  
  return {
    // How many items to render initially
    initialNumToRender: isIOS ? 10 : 8,
    
    // How many items to render per batch
    maxToRenderPerBatch: isIOS ? 10 : 8,
    
    // How long to wait before rendering next batch (ms)
    updateCellsBatchingPeriod: 50,
    
    // How many screens worth of content to keep in memory
    windowSize: isIOS ? 5 : 3,
    
    // Remove views outside viewport
    removeClippedSubviews: true,
    
    // When to trigger onEndReached
    onEndReachedThreshold: 0.5,
  };
};

/**
 * Batch state updates to reduce re-renders
 */
export const batchUpdates = (updates: () => void) => {
  if (Platform.OS === 'ios') {
    // Use unstable_batchedUpdates for React Native
    // @ts-ignore
    if (typeof requestAnimationFrame !== 'undefined') {
      requestAnimationFrame(updates);
    } else {
      updates();
    }
  } else {
    updates();
  }
};

/**
 * Check if device has enough memory for high-quality images
 */
export const shouldUseHighQualityImages = () => {
  // For now, return true. In production, you could check device specs
  return true;
};

/**
 * Calculate optimal image size based on screen size
 */
export const getOptimalImageSize = (
  screenWidth: number,
  numColumns: number = 2,
  padding: number = 16
): number => {
  const gap = padding;
  const imageWidth = (screenWidth - (padding * 2) - gap) / numColumns;
  
  // Round to nearest 10 for better caching
  return Math.round(imageWidth / 10) * 10;
};

