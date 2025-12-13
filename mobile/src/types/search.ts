// Search Types

import { ListingType, ListingIntent, DeliveryMethod } from './product';
import { Campus } from './campus';

export type SortOption = 'recent' | 'price_low' | 'price_high' | 'relevance';

export const SortOptionDisplay: Record<SortOption, string> = {
  recent: 'Most Recent',
  price_low: 'Price: Low to High',
  price_high: 'Price: High to Low',
  relevance: 'Relevance',
};

export interface SearchFilters {
  query?: string;
  category?: string;
  campus?: Campus;
  listing_type?: ListingType;
  intent?: ListingIntent;
  delivery_method?: DeliveryMethod;
  min_price?: number;
  max_price?: number;
  sort?: SortOption;
}

export interface SearchResult {
  listings: import('./product').ListingWithUser[];
  total_count: number;
  has_more: boolean;
  query?: string;
}

export interface SearchSuggestion {
  text: string;
  type: 'recent' | 'popular' | 'category';
}

export interface SearchHistory {
  id: string;
  user_id: string;
  query: string;
  created_at: string;
}

// Product categories
export const ProductCategories = [
  'Electronics',
  'Books',
  'Furniture',
  'Clothing',
  'Sports',
  'Tickets',
  'Other',
] as const;

// Service categories
export const ServiceCategories = [
  'Tutoring',
  'Moving',
  'Cleaning',
  'Other',
] as const;

export type ProductCategory = typeof ProductCategories[number];
export type ServiceCategory = typeof ServiceCategories[number];

