// Listing Service - Core listing operations
import { supabase } from '../config/supabase';
import { Listing, ListingCreate, ListingWithUser } from '../types';

// Get current user ID
const getCurrentUserId = async (): Promise<string | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.user.id ?? null;
};

// Get current user's email domain
const getCurrentUserDomain = async (): Promise<string | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  const email = session?.user.email;
  if (!email) return null;
  const domain = email.split('@')[1];
  return domain ?? null;
};

// Get all listings (with optional campus filter)
export const getListings = async (
  options: {
    limit?: number;
    offset?: number;
    filterByCampus?: boolean;
    category?: string;
    listingType?: 'product' | 'service';
    intent?: 'offer' | 'seek';
    excludeArchived?: boolean;
    excludeSold?: boolean;
  } = {}
): Promise<ListingWithUser[]> => {
  const {
    limit = 20,
    offset = 0,
    filterByCampus = false,
    category,
    listingType,
    intent,
    excludeArchived = true,
    excludeSold = true,
  } = options;

  let query = supabase
    .from('listings')
    .select('*, user:users(*)');

  // Apply filters
  if (excludeArchived) {
    query = query.or('archived.eq.false,archived.is.null');
  }

  if (excludeSold) {
    query = query.eq('is_sold', false);
  }

  if (category) {
    query = query.eq('category', category);
  }

  if (listingType) {
    query = query.eq('listing_type', listingType);
  }

  if (intent) {
    query = query.eq('intent', intent);
  }

  // Campus filter - filter by user email domain
  if (filterByCampus) {
    const domain = await getCurrentUserDomain();
    if (domain) {
      // This requires the user's email to be joined
      // For now, we'll filter client-side if needed
    }
  }

  const { data, error } = await query
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return data ?? [];
};

// Get a single listing by ID
export const getListing = async (listingId: string): Promise<ListingWithUser | null> => {
  const { data, error } = await supabase
    .from('listings')
    .select('*, user:users(*)')
    .eq('id', listingId)
    .single();

  if (error) {
    if (error.code === 'PGRST116') return null; // Not found
    throw error;
  }
  return data;
};

// Get current user's listings
export const getMyListings = async (
  options: { includeArchived?: boolean; includeSold?: boolean } = {}
): Promise<Listing[]> => {
  const { includeArchived = false, includeSold = false } = options;
  const userId = await getCurrentUserId();
  
  if (!userId) throw new Error('Not authenticated');

  let query = supabase
    .from('listings')
    .select('*')
    .eq('user_id', userId);

  if (!includeArchived) {
    query = query.or('archived.eq.false,archived.is.null');
  }

  if (!includeSold) {
    query = query.eq('is_sold', false);
  }

  const { data, error } = await query.order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
};

// Create a new listing
export const createListing = async (listing: ListingCreate): Promise<Listing> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('listings')
    .insert({
      ...listing,
      user_id: userId,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Update a listing
export const updateListing = async (
  listingId: string,
  updates: Partial<ListingCreate>
): Promise<Listing> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Verify ownership
  const existing = await getListing(listingId);
  if (!existing) throw new Error('Listing not found');
  if (existing.user_id !== userId) throw new Error('Unauthorized');

  const { data, error } = await supabase
    .from('listings')
    .update(updates)
    .eq('id', listingId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Delete (archive) a listing
export const deleteListing = async (listingId: string): Promise<void> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Soft delete by archiving
  const { error } = await supabase
    .from('listings')
    .update({ archived: true })
    .eq('id', listingId)
    .eq('user_id', userId);

  if (error) throw error;
};

// Mark listing as sold
export const markAsSold = async (listingId: string): Promise<Listing> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('listings')
    .update({ is_sold: true })
    .eq('id', listingId)
    .eq('user_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Search listings
export const searchListings = async (
  query: string,
  options: {
    category?: string;
    minPrice?: number;
    maxPrice?: number;
    limit?: number;
  } = {}
): Promise<ListingWithUser[]> => {
  const { category, minPrice, maxPrice, limit = 20 } = options;

  // Use RPC for full-text search
  const { data, error } = await supabase.rpc('search_listings', {
    p_query: query,
    p_category: category,
    p_min_price: minPrice,
    p_max_price: maxPrice,
    p_limit: limit,
  });

  if (error) {
    console.error('Search RPC error:', error);
    // Fallback to simple ILIKE search
    return fallbackSearch(query, options);
  }

  return data ?? [];
};

// Fallback search using ILIKE
const fallbackSearch = async (
  query: string,
  options: { category?: string; minPrice?: number; maxPrice?: number; limit?: number }
): Promise<ListingWithUser[]> => {
  const { category, minPrice, maxPrice, limit = 20 } = options;

  let dbQuery = supabase
    .from('listings')
    .select('*, user:users(*)')
    .or(`title.ilike.%${query}%,description.ilike.%${query}%`)
    .eq('is_sold', false)
    .or('archived.eq.false,archived.is.null');

  if (category) {
    dbQuery = dbQuery.eq('category', category);
  }

  if (minPrice !== undefined) {
    dbQuery = dbQuery.gte('price', minPrice);
  }

  if (maxPrice !== undefined) {
    dbQuery = dbQuery.lte('price', maxPrice);
  }

  const { data, error } = await dbQuery
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
};

// Get listings by category
export const getListingsByCategory = async (
  category: string,
  limit = 20
): Promise<ListingWithUser[]> => {
  const { data, error } = await supabase
    .from('listings')
    .select('*, user:users(*)')
    .eq('category', category)
    .eq('is_sold', false)
    .or('archived.eq.false,archived.is.null')
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
};

export default {
  getListings,
  getListing,
  getMyListings,
  createListing,
  updateListing,
  deleteListing,
  markAsSold,
  searchListings,
  getListingsByCategory,
};

