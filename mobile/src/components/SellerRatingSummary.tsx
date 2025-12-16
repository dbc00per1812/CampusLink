// Seller Rating Summary Component - Displays compact seller ratings
import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing } from '../utils/spacing';
import { UserRatingsSummary, getTrustLevelFromScore, TrustLevelEmoji } from '../types/rating';
import { getRatingsSummary } from '../services/ratingService';

interface SellerRatingSummaryProps {
  userId: string;
}

export const SellerRatingSummary: React.FC<SellerRatingSummaryProps> = ({ userId }) => {
  const colors = useColors();
  const [summary, setSummary] = useState<UserRatingsSummary | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadSummary = async () => {
      try {
        const data = await getRatingsSummary(userId);
        setSummary(data);
      } catch (error) {
        console.error('Failed to load rating summary:', error);
        // Silently fail - just show fallback
      } finally {
        setLoading(false);
      }
    };

    loadSummary();
  }, [userId]);

  if (loading) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="small" color={colors.textSecondary} />
      </View>
    );
  }

  if (!summary || summary.total_ratings === 0) {
    // New users start with a 5-star rating
    return (
      <View style={styles.container}>
        <StarRating rating={5} />
        <Text style={[styles.ratingText, { color: colors.textSecondary }]}>New Seller</Text>
      </View>
    );
  }

  const trustLevel = getTrustLevelFromScore(summary.trust_score);
  const trustEmoji = TrustLevelEmoji[trustLevel];

  return (
    <View style={styles.container}>
      <StarRating rating={summary.average_rating} />
      <Text style={[styles.ratingText, { color: colors.textPrimary }]}>
        {summary.average_rating.toFixed(1)}
      </Text>
      <Text style={[styles.countText, { color: colors.textSecondary }]}>
        ({summary.total_ratings})
      </Text>
      <Text style={styles.trustEmoji}>{trustEmoji}</Text>
    </View>
  );
};

// Star Rating Component
interface StarRatingProps {
  rating: number;
  size?: number;
}

const StarRating: React.FC<StarRatingProps> = ({ rating, size = 14 }) => {
  const colors = useColors();
  const fullStars = Math.floor(rating);
  const hasHalfStar = rating % 1 >= 0.5;

  return (
    <View style={styles.starsContainer}>
      {[...Array(5)].map((_, index) => {
        if (index < fullStars) {
          return (
            <Ionicons
              key={index}
              name="star"
              size={size}
              color="#FFD700"
              style={styles.star}
            />
          );
        } else if (index === fullStars && hasHalfStar) {
          return (
            <Ionicons
              key={index}
              name="star-half"
              size={size}
              color="#FFD700"
              style={styles.star}
            />
          );
        } else {
          return (
            <Ionicons
              key={index}
              name="star-outline"
              size={size}
              color={colors.textTertiary}
              style={styles.star}
            />
          );
        }
      })}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
  },
  starsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  star: {
    marginRight: 1,
  },
  ratingText: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  countText: {
    ...Typography.caption1,
  },
  trustEmoji: {
    fontSize: 14,
    marginLeft: 2,
  },
});
