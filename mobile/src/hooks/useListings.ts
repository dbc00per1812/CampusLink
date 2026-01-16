// useListings Hook - React Query powered listings with caching
// Lightning-fast data fetching with automatic caching and background updates

import { useQuery, useInfiniteQuery, QueryKey } from '@tanstack/react-query';
import { getListings, getListing } from '../services/listingService';
import { ListingWithUser } from '../types';
import { prefetchListingImages } from './useImagePrefetch';

interface UseListingsOptions {
  limit?: number;
  filterByCampus?: boolean;
  category?: string;
  listingType?: 'product' | 'service';
  intent?: 'offer' | 'seek';
  excludeArchived?: boolean;
  excludeSold?: boolean;
  enabled?: boolean;
}

/**
 * Fetch listings with automatic caching and background updates
 */
export const useListings = (options: UseListingsOptions = {}) => {
  const {
    limit = 20,
    filterByCampus = true, // Default to campus filtering - prevents bypass
    category,
    listingType,
    intent,
    excludeArchived = true,
    excludeSold = true,
    enabled = true,
  } = options;

  return useQuery({
    queryKey: ['listings', { 
      limit, 
      filterByCampus, 
      category, 
      listingType, 
      intent,
      excludeArchived,
      excludeSold,
    }] as QueryKey,
    queryFn: async () => {
      const data = await getListings({
        limit,
        offset: 0,
        filterByCampus,
        category,
        listingType,
        intent,
        excludeArchived,
        excludeSold,
      });
      
      // Prefetch images for instant rendering
      if (data.length > 0) {
        prefetchListingImages(data);
      }
      
      return data;
    },
    enabled,
    staleTime: 2 * 60 * 1000, // Consider fresh for 2 minutes
    gcTime: 10 * 60 * 1000, // Cache for 10 minutes
  });
};

/**
 * Infinite scroll listings with automatic pagination
 */
export const useInfiniteListings = (options: UseListingsOptions = {}) => {
  const {
    limit = 20,
    filterByCampus = true, // Default to campus filtering - prevents bypass
    category,
    listingType,
    intent,
    excludeArchived = true,
    excludeSold = true,
    enabled = true,
  } = options;

  return useInfiniteQuery({
    queryKey: ['listings-infinite', { 
      limit, 
      filterByCampus, 
      category, 
      listingType, 
      intent,
      excludeArchived,
      excludeSold,
    }] as QueryKey,
    queryFn: async ({ pageParam = 0 }) => {
      const data = await getListings({
        limit,
        offset: pageParam * limit,
        filterByCampus,
        category,
        listingType,
        intent,
        excludeArchived,
        excludeSold,
      });
      
      // Prefetch images for smooth scrolling
      if (data.length > 0) {
        prefetchListingImages(data);
      }
      
      return data;
    },
    getNextPageParam: (lastPage, allPages) => {
      if (lastPage.length < limit) return undefined;
      return allPages.length;
    },
    enabled,
    initialPageParam: 0,
    staleTime: 2 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });
};

/**
 * Fetch single listing with caching
 */
export const useListing = (listingId: string, enabled: boolean = true) => {
  return useQuery({
    queryKey: ['listing', listingId] as QueryKey,
    queryFn: async () => {
      const data = await getListing(listingId);
      
      // Prefetch all images in the listing
      if (data?.photos && data.photos.length > 0) {
        prefetchListingImages([data]);
      }
      
      return data;
    },
    enabled: enabled && !!listingId,
    staleTime: 5 * 60 * 1000, // Fresh for 5 minutes
    gcTime: 15 * 60 * 1000, // Cache for 15 minutes
  });
};

