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

  // Get current user's campus for filtering (before building query)
  let currentUserCampus: string | null = null;
  if (filterByCampus) {
    const userId = await getCurrentUserId();
    if (userId) {
      try {
        const { data: currentUser, error: userError } = await supabase
          .from('users')
          .select('campus')
          .eq('id', userId)
          .single();
        
        if (!userError && currentUser?.campus) {
          currentUserCampus = currentUser.campus;
          console.log(`🔍 Campus Filter (Server-Side): Filtering by campus: ${currentUserCampus}`);
        } else {
          console.log('🔍 Campus Filter: Current user has no campus set, showing all listings');
        }
      } catch (err) {
        console.error('❌ Campus Filter: Error fetching user campus:', err);
      }
    }
  }

  let query = supabase
    .from('listings')
    .select('*, user:users!inner(*)'); // Use inner join to enable filtering on user fields

  // Apply filters - match iOS implementation exactly
  // Always filter for active status (excludes deleted/inactive posts)
  query = query.eq('status', 'active');
  
  if (excludeArchived) {
    // Match iOS: .neq("archived", value: true) - excludes archived posts
    query = query.neq('archived', true);
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

  // Server-side campus filter - filter at database level BEFORE pagination
  // Using inner join allows us to filter on the related user's campus field
  if (currentUserCampus) {
    query = query.eq('user.campus', currentUserCampus);
    console.log(`🔍 Campus Filter: Applied server-side filter for campus: ${currentUserCampus}`);
  }

  const { data, error } = await query
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) {
    console.error('❌ Database query error:', error);
    throw error;
  }
  
  const listings = data ?? [];
  
  if (currentUserCampus) {
    console.log(`✅ Campus Filter: Fetched ${listings.length} listings for campus ${currentUserCampus}`);
  }
  
  return listings;
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

  // Match iOS: always filter for active status by default
  // Only show non-active when explicitly including archived
  if (!includeArchived) {
    query = query.eq('status', 'active');
    query = query.neq('archived', true);
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
  if (!userId) {
    console.error('❌ Archive failed: Not authenticated');
    throw new Error('Not authenticated');
  }

  console.log('🗄️ Archiving listing:', listingId, 'for user:', userId);

  // First verify the listing exists and user owns it
  try {
    const { data: listing, error: fetchError } = await supabase
      .from('listings')
      .select('id, user_id, title')
      .eq('id', listingId)
      .single();

    if (fetchError) {
      console.error('❌ Error fetching listing:', fetchError);
      throw new Error(`Failed to fetch listing: ${fetchError.message}`);
    }

    if (!listing) {
      console.error('❌ Listing not found:', listingId);
      throw new Error('Listing not found');
    }

    if (listing.user_id !== userId) {
      console.error('❌ Unauthorized: User', userId, 'does not own listing', listingId);
      throw new Error('You do not have permission to archive this listing');
    }

    console.log('✅ Ownership verified for listing:', listing.title);
  } catch (err) {
    console.error('❌ Verification failed:', err);
    throw err;
  }

  // Now archive the listing
  const { data, error } = await supabase
    .from('listings')
    .update({ archived: true })
    .eq('id', listingId)
    .eq('user_id', userId)
    .select();

  if (error) {
    console.error('❌ Archive database error:', error);
    console.error('❌ Error details:', JSON.stringify(error, null, 2));
    throw new Error(`Failed to archive listing: ${error.message}`);
  }

  if (!data || data.length === 0) {
    console.error('❌ Update returned no data - possible RLS policy issue');
    throw new Error('Failed to archive listing - no rows updated');
  }

  console.log('✅ Listing archived successfully:', data[0].title);
};

// Alias for archiveListing (same as deleteListing)
export const archiveListing = deleteListing;

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
    .eq('status', 'active')
    .eq('is_sold', false)
    .neq('archived', true);

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
    .eq('status', 'active')
    .eq('is_sold', false)
    .neq('archived', true)
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
  archiveListing,
  markAsSold,
  searchListings,
  getListingsByCategory,
};

