// Rating Types - Converted from RatingModels.swift

import { Order } from './order';
import { User } from './product';

export type RatingType = 'buyer_to_seller' | 'seller_to_buyer';
export type ModerationStatus = 'pending' | 'approved' | 'rejected';
export type TrustLevel = 'trusted' | 'reliable' | 'new' | 'caution' | 'risk';

// Display helpers
export const RatingTypeDisplay: Record<RatingType, string> = {
  buyer_to_seller: 'Rate Seller',
  seller_to_buyer: 'Rate Buyer',
};

export const ModerationStatusDisplay: Record<ModerationStatus, string> = {
  pending: 'Pending Review',
  approved: 'Approved',
  rejected: 'Rejected',
};

export const TrustLevelDisplay: Record<TrustLevel, string> = {
  trusted: 'Trusted',
  reliable: 'Reliable',
  new: 'New',
  caution: 'Caution',
  risk: 'High Risk',
};

export const TrustLevelEmoji: Record<TrustLevel, string> = {
  trusted: '🥇',
  reliable: '🥈',
  new: '🥉',
  caution: '⚠️',
  risk: '🚫',
};

export const TrustLevelColor: Record<TrustLevel, string> = {
  trusted: '#FFD700', // gold
  reliable: '#C0C0C0', // silver
  new: '#CD7F32', // bronze
  caution: '#F97316', // orange
  risk: '#EF4444', // red
};

export const TrustLevelDescription: Record<TrustLevel, string> = {
  trusted: 'Highly trusted member with excellent feedback',
  reliable: 'Reliable member with good feedback',
  new: 'New member building their reputation',
  caution: 'Mixed feedback - proceed with caution',
  risk: 'Poor feedback - high risk',
};

// Rating interface
export interface Rating {
  id: string;
  order_id: string;
  rater_id: string;
  rated_id: string;
  rating: number; // 1-5 stars
  comment: string | null;
  rating_type: RatingType;
  is_anonymous: boolean;
  created_at: string;
  updated_at: string | null;
  is_reported: boolean;
  is_hidden: boolean;
  moderation_status: ModerationStatus;
  // Joined data
  rater?: User | null;
  rated_user?: User | null;
  order?: Order | null;
}

// Rating Create (for inserting new ratings)
export interface RatingCreate {
  order_id: string;
  rater_id: string;
  rated_id: string;
  rating: number;
  comment: string | null;
  rating_type: RatingType;
  is_anonymous: boolean;
}

// Rating helper functions
export const isPositiveRating = (rating: Rating): boolean => {
  return rating.rating >= 4;
};

export const isNeutralRating = (rating: Rating): boolean => {
  return rating.rating === 3;
};

export const isNegativeRating = (rating: Rating): boolean => {
  return rating.rating <= 2;
};

export const getRatingText = (rating: number): string => {
  switch (rating) {
    case 1: return 'Poor';
    case 2: return 'Fair';
    case 3: return 'Good';
    case 4: return 'Very Good';
    case 5: return 'Excellent';
    default: return 'Unknown';
  }
};

// User Ratings Summary
export interface UserRatingsSummary {
  user_id: string;
  average_rating: number;
  total_ratings: number;
  trust_score: number;
  ratings_breakdown: Record<number, number>; // Star count -> Count
  recent_ratings: Rating[];
}

// Summary helper functions
export const hasRatings = (summary: UserRatingsSummary): boolean => {
  return summary.total_ratings > 0;
};

export const getTrustLevelFromScore = (score: number): TrustLevel => {
  if (score >= 80) return 'trusted';
  if (score >= 60) return 'reliable';
  if (score >= 40) return 'new';
  if (score >= 20) return 'caution';
  return 'risk';
};

export const getDisplayRating = (summary: UserRatingsSummary): string => {
  if (hasRatings(summary)) {
    return summary.average_rating.toFixed(1);
  }
  // New users start with a default 5.0 star rating
  return '5.0';
};

// Rating Statistics
export interface RatingStats {
  totalRatings: number;
  averageRating: number;
  breakdown: Record<number, number>;
  trustScore: number;
  trustLevel: TrustLevel;
}

export const getDisplayStars = (stats: RatingStats): string => {
  if (stats.totalRatings === 0) return 'No ratings yet';
  return '⭐'.repeat(Math.round(stats.averageRating));
};

// Sample data
export const sampleRating: Rating = {
  id: 'sample-rating-id',
  order_id: 'sample-order-id',
  rater_id: 'sample-rater-id',
  rated_id: 'sample-rated-id',
  rating: 5,
  comment: 'Excellent seller! Item was exactly as described and shipped quickly.',
  rating_type: 'buyer_to_seller',
  is_anonymous: false,
  created_at: new Date().toISOString(),
  updated_at: null,
  is_reported: false,
  is_hidden: false,
  moderation_status: 'approved',
};

export const sampleRatingsSummary: UserRatingsSummary = {
  user_id: 'sample-user-id',
  average_rating: 4.7,
  total_ratings: 23,
  trust_score: 85.5,
  ratings_breakdown: { 5: 18, 4: 4, 3: 1, 2: 0, 1: 0 },
  recent_ratings: [sampleRating],
};

