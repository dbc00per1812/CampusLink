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

/**
 * Block a user
 */
export const blockUser = async (blockerId: string, blockedId: string): Promise<void> => {
  // Check if already blocked
  const { data: existing } = await supabase
    .from('blocked_users')
    .select('id')
    .eq('blocker_id', blockerId)
    .eq('blocked_id', blockedId)
    .maybeSingle();

  if (existing) {
    // Already blocked, nothing to do
    return;
  }

  const { error } = await supabase
    .from('blocked_users')
    .insert({
      blocker_id: blockerId,
      blocked_id: blockedId,
    });

  if (error) {
    console.error('Error blocking user:', error);
    throw error;
  }
};

/**
 * Unblock a user
 */
export const unblockUser = async (blockerId: string, blockedId: string): Promise<void> => {
  const { error } = await supabase
    .from('blocked_users')
    .delete()
    .eq('blocker_id', blockerId)
    .eq('blocked_id', blockedId);

  if (error) {
    console.error('Error unblocking user:', error);
    throw error;
  }
};

/**
 * Check if a user is blocked
 */
export const isUserBlocked = async (blockerId: string, blockedId: string): Promise<boolean> => {
  const { data, error } = await supabase
    .from('blocked_users')
    .select('id')
    .eq('blocker_id', blockerId)
    .eq('blocked_id', blockedId)
    .maybeSingle();

  if (error) {
    console.error('Error checking blocked status:', error);
    return false;
  }

  return !!data;
};

/**
 * Get all blocked user IDs (both users we blocked and users who blocked us)
 * This is used to filter out content from blocked users
 */
export const getBlockedUserIds = async (userId: string): Promise<string[]> => {
  try {
    // Get users we blocked
    const { data: blockedByMe, error: error1 } = await supabase
      .from('blocked_users')
      .select('blocked_id')
      .eq('blocker_id', userId);

    if (error1) {
      console.error('Error fetching users blocked by me:', error1);
    }

    // Get users who blocked us
    const { data: blockedMe, error: error2 } = await supabase
      .from('blocked_users')
      .select('blocker_id')
      .eq('blocked_id', userId);

    if (error2) {
      console.error('Error fetching users who blocked me:', error2);
    }

    // Combine both lists into unique set
    const blockedIds = new Set<string>();
    
    if (blockedByMe) {
      blockedByMe.forEach(b => blockedIds.add(b.blocked_id));
    }
    if (blockedMe) {
      blockedMe.forEach(b => blockedIds.add(b.blocker_id));
    }

    console.log(`🚫 Found ${blockedIds.size} blocked users for filtering`);
    return Array.from(blockedIds);
  } catch (error) {
    console.error('Error getting blocked user IDs:', error);
    return [];
  }
};

/**
 * Check if there's a blocking relationship between two users
 * Returns true if either user has blocked the other
 */
export const hasBlockingRelationship = async (userId1: string, userId2: string): Promise<boolean> => {
  try {
    const { data, error } = await supabase
      .from('blocked_users')
      .select('id')
      .or(`and(blocker_id.eq.${userId1},blocked_id.eq.${userId2}),and(blocker_id.eq.${userId2},blocked_id.eq.${userId1})`)
      .limit(1);

    if (error) {
      console.error('Error checking blocking relationship:', error);
      return false;
    }

    return data && data.length > 0;
  } catch (error) {
    console.error('Error checking blocking relationship:', error);
    return false;
  }
};

export default {
  getUserById,
  getUserListings,
  updateUserProfile,
  blockUser,
  unblockUser,
  isUserBlocked,
  getBlockedUserIds,
  hasBlockingRelationship,
};
