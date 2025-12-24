// User Interest Service
import { supabase } from '../config/supabase';
import { UserInterest, UserInterestCreate } from '../types/userInterest';
import { getCurrentUserId } from './authService';

/**
 * Save user interests to database
 */
export const saveUserInterests = async (
  interests: Omit<UserInterestCreate, 'user_id'>[]
): Promise<void> => {
  try {
    const userId = await getCurrentUserId();
    if (!userId) {
      throw new Error('User not authenticated');
    }

    console.log('💾 Saving user interests:', interests.length);

    // Convert interests to database format
    const interestsToSave = interests.map(interest => ({
      user_id: userId,
      category: interest.category,
      listing_type: interest.listing_type,
    }));

    const { error } = await supabase
      .from('user_interests')
      .insert(interestsToSave);

    if (error) throw error;

    console.log('✅ User interests saved successfully');
  } catch (error) {
    console.error('❌ Error saving user interests:', error);
    throw error;
  }
};

/**
 * Get user's interests
 */
export const getUserInterests = async (): Promise<UserInterest[]> => {
  try {
    const userId = await getCurrentUserId();
    if (!userId) {
      throw new Error('User not authenticated');
    }

    const { data, error } = await supabase
      .from('user_interests')
      .select('*')
      .eq('user_id', userId);

    if (error) throw error;

    return data || [];
  } catch (error) {
    console.error('❌ Error fetching user interests:', error);
    throw error;
  }
};

/**
 * Delete all user interests
 */
export const deleteUserInterests = async (): Promise<void> => {
  try {
    const userId = await getCurrentUserId();
    if (!userId) {
      throw new Error('User not authenticated');
    }

    const { error } = await supabase
      .from('user_interests')
      .delete()
      .eq('user_id', userId);

    if (error) throw error;

    console.log('✅ User interests deleted successfully');
  } catch (error) {
    console.error('❌ Error deleting user interests:', error);
    throw error;
  }
};

/**
 * Update user interests (delete old, insert new)
 */
export const updateUserInterests = async (
  interests: Omit<UserInterestCreate, 'user_id'>[]
): Promise<void> => {
  try {
    // Delete existing interests first
    await deleteUserInterests();

    // Save new interests
    if (interests.length > 0) {
      await saveUserInterests(interests);
    }

    console.log('✅ User interests updated successfully');
  } catch (error) {
    console.error('❌ Error updating user interests:', error);
    throw error;
  }
};

export default {
  saveUserInterests,
  getUserInterests,
  deleteUserInterests,
  updateUserInterests,
};

