// Rating Service - Handles rating-related API calls
import { supabase } from '../config/supabase';
import { UserRatingsSummary, Rating, getTrustLevelFromScore } from '../types/rating';

/**
 * Get user ratings summary
 */
export const getRatingsSummary = async (userId: string): Promise<UserRatingsSummary> => {
  // Fetch all approved ratings for this user
  const { data: ratings, error } = await supabase
    .from('ratings')
    .select('rating, created_at')
    .eq('rated_id', userId)
    .eq('moderation_status', 'approved')
    .eq('is_hidden', false);

  if (error) {
    console.error('Error fetching ratings:', error);
    throw error;
  }

  if (!ratings || ratings.length === 0) {
    // Return empty summary for users with no ratings
    // New users start with a 5-star rating (trust_score: 100)
    return {
      user_id: userId,
      average_rating: 5,
      total_ratings: 0,
      trust_score: 100, // Default 5-star rating for new users
      ratings_breakdown: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
      recent_ratings: [],
    };
  }

  // Calculate statistics
  const totalRatings = ratings.length;
  const sumRatings = ratings.reduce((sum, r) => sum + r.rating, 0);
  const averageRating = sumRatings / totalRatings;

  // Build breakdown
  const breakdown: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  ratings.forEach((r) => {
    breakdown[r.rating] = (breakdown[r.rating] || 0) + 1;
  });

  // Calculate trust score (simplified formula)
  // Base score on average rating and number of ratings
  const ratingScore = (averageRating / 5) * 70; // Max 70 points from rating
  const volumeScore = Math.min(totalRatings * 2, 30); // Max 30 points from volume
  const trustScore = Math.round(ratingScore + volumeScore);

  return {
    user_id: userId,
    average_rating: averageRating,
    total_ratings: totalRatings,
    trust_score: trustScore,
    ratings_breakdown: breakdown,
    recent_ratings: [], // We don't need to return full rating objects for the summary
  };
};

/**
 * Get user ratings (paginated)
 */
export const getUserRatings = async (
  userId: string,
  limit: number = 10,
  offset: number = 0
): Promise<Rating[]> => {
  const { data, error } = await supabase
    .from('ratings')
    .select(`
      *,
      rater:users!rater_id(id, name, profile_pic),
      order:orders(id, listing_id)
    `)
    .eq('rated_id', userId)
    .eq('moderation_status', 'approved')
    .eq('is_hidden', false)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) {
    console.error('Error fetching ratings:', error);
    throw error;
  }

  return data as Rating[];
};

/**
 * Create a new rating
 */
export const createRating = async (
  orderId: string,
  ratedUserId: string,
  rating: number,
  comment: string | null,
  ratingType: 'buyer_to_seller' | 'seller_to_buyer',
  isAnonymous: boolean = false
): Promise<Rating> => {
  const { data: session } = await supabase.auth.getSession();
  
  if (!session?.session?.user) {
    throw new Error('User not authenticated');
  }

  const { data, error } = await supabase
    .from('ratings')
    .insert({
      order_id: orderId,
      rater_id: session.session.user.id,
      rated_id: ratedUserId,
      rating,
      comment,
      rating_type: ratingType,
      is_anonymous: isAnonymous,
    })
    .select()
    .single();

  if (error) {
    console.error('Error creating rating:', error);
    throw error;
  }

  return data as Rating;
};

/**
 * Check if user can rate an order
 */
export const canRateOrder = async (orderId: string): Promise<boolean> => {
  const { data: session } = await supabase.auth.getSession();
  
  if (!session?.session?.user) {
    return false;
  }

  // Check if rating already exists for this order and user
  const { data, error } = await supabase
    .from('ratings')
    .select('id')
    .eq('order_id', orderId)
    .eq('rater_id', session.session.user.id)
    .maybeSingle();

  if (error) {
    console.error('Error checking rating eligibility:', error);
    return false;
  }

  // Can rate if no rating exists yet
  return !data;
};

/**
 * Report a rating
 */
export const reportRating = async (ratingId: string, reason: string): Promise<void> => {
  const { error } = await supabase
    .from('ratings')
    .update({ is_reported: true })
    .eq('id', ratingId);

  if (error) {
    console.error('Error reporting rating:', error);
    throw error;
  }

  // Optionally create a report record if you have a reports table
  // This would depend on your database schema
};
