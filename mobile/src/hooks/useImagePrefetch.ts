// useImagePrefetch Hook - Prefetch images for next screen
// Improves perceived performance by loading images before they're needed

import { useEffect, useCallback } from 'react';
import { Image } from 'expo-image';
import { CACHE_POLICY } from '../config/imageConfig';

interface PrefetchOptions {
  enabled?: boolean;
  cachePolicy?: typeof CACHE_POLICY[keyof typeof CACHE_POLICY];
}

/**
 * Prefetch images in the background for faster loading
 * Use this to load images for the next screen while user is viewing current screen
 */
export const useImagePrefetch = (
  imageUrls: string[],
  options: PrefetchOptions = {}
) => {
  const { enabled = true, cachePolicy = CACHE_POLICY.memoryDisk } = options;

  const prefetchImages = useCallback(async () => {
    if (!enabled || imageUrls.length === 0) return;

    try {
      // Prefetch all images in parallel
      await Promise.all(
        imageUrls
          .filter(url => url && url.length > 0)
          .map(url => 
            Image.prefetch(url, { cachePolicy })
          )
      );
    } catch (error) {
      // Silently fail - prefetching is a nice-to-have
      console.debug('Image prefetch failed:', error);
    }
  }, [imageUrls, enabled, cachePolicy]);

  useEffect(() => {
    prefetchImages();
  }, [prefetchImages]);

  return { prefetchImages };
};

/**
 * Prefetch images for listing cards
 * Call this when listings are loaded to prefetch first image of each listing
 */
export const prefetchListingImages = async (listings: any[]) => {
  const imageUrls = listings
    .map(listing => listing.photos?.[0] || listing.photo)
    .filter(Boolean)
    .slice(0, 20); // Prefetch first 20 images only

  try {
    await Promise.all(
      imageUrls.map(url => 
        Image.prefetch(url, { cachePolicy: CACHE_POLICY.memoryDisk })
      )
    );
  } catch (error) {
    console.debug('Listing image prefetch failed:', error);
  }
};

