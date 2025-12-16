// User Service - Handles user-related API calls
import { supabase } from '../config/supabase';
import { User } from '../types';

/**
 * Get user by ID
 */
export const getUserById = async (userId: string): Promise<User | null> => {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) {
    console.error('Error fetching user:', error);
    throw error;
  }

  return data;
};

/**
 * Update user profile
 */
export const updateUserProfile = async (
  userId: string,
  updates: {
    name?: string;
    bio?: string | null;
    profile_pic?: string | null;
  }
): Promise<User> => {
  const { data, error } = await supabase
    .from('users')
    .update(updates)
    .eq('id', userId)
    .select()
    .single();

  if (error) {
    console.error('Error updating user profile:', error);
    throw error;
  }

  return data;
};

/**
 * Get user's listings
 */
export const getUserListings = async (
  userId: string,
  options: {
    includeArchived?: boolean;
    includeSold?: boolean;
    limit?: number;
  } = {}
) => {
  const { includeArchived = false, includeSold = false, limit = 50 } = options;

  let query = supabase
    .from('listings')
    .select('*, user:users(*)')
    .eq('user_id', userId)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(limit);

  if (!includeArchived) {
    query = query.eq('archived', false);
  }

  if (!includeSold) {
    query = query.eq('is_sold', false);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Error fetching user listings:', error);
    throw error;
  }

  return data || [];
};

export default {
  getUserById,
  getUserListings,
  updateUserProfile,
};
