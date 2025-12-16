// Listing Grid Skeleton - Shimmer loading state
import React, { memo, useEffect, useRef } from 'react';
import {
  View,
  StyleSheet,
  Animated,
  Dimensions,
} from 'react-native';
import { useColors } from '../../context/ThemeContext';
import { Spacing, BorderRadius, Shadows } from '../../utils/spacing';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const CARD_GAP = Spacing.md;
const CARD_WIDTH = (SCREEN_WIDTH - Spacing.lg * 2 - CARD_GAP) / 2;

interface ListingGridSkeletonProps {
  count?: number;
}

const SkeletonCard: React.FC = memo(() => {
  const colors = useColors();
  const shimmerAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const shimmer = Animated.loop(
      Animated.sequence([
        Animated.timing(shimmerAnim, {
          toValue: 1,
          duration: 1000,
          useNativeDriver: true,
        }),
        Animated.timing(shimmerAnim, {
          toValue: 0,
          duration: 1000,
          useNativeDriver: true,
        }),
      ])
    );
    shimmer.start();
    return () => shimmer.stop();
  }, [shimmerAnim]);

  const opacity = shimmerAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0.3, 0.7],
  });

  return (
    <View style={[styles.card, { backgroundColor: colors.cardBackground }, Shadows.card]}>
      <Animated.View
        style={[
          styles.imageContainer,
          { backgroundColor: colors.skeletonBase, opacity },
        ]}
      />
      <View style={styles.content}>
        <Animated.View
          style={[
            styles.priceSkeleton,
            { backgroundColor: colors.skeletonBase, opacity },
          ]}
        />
        <Animated.View
          style={[
            styles.titleSkeleton,
            { backgroundColor: colors.skeletonBase, opacity },
          ]}
        />
        <Animated.View
          style={[
            styles.titleSkeletonShort,
            { backgroundColor: colors.skeletonBase, opacity },
          ]}
        />
      </View>
    </View>
  );
});

const ListingGridSkeleton: React.FC<ListingGridSkeletonProps> = memo(({
  count = 6,
}) => {
  const colors = useColors();

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <View style={styles.grid}>
        {Array.from({ length: count }).map((_, index) => (
          <SkeletonCard key={`skeleton-${index}`} />
        ))}
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: Spacing.lg,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: CARD_GAP,
  },
  card: {
    width: CARD_WIDTH,
    borderRadius: BorderRadius.lg,
    overflow: 'hidden',
  },
  imageContainer: {
    width: '100%',
    aspectRatio: 1,
  },
  content: {
    padding: Spacing.md,
  },
  priceSkeleton: {
    height: 22,
    width: '60%',
    borderRadius: BorderRadius.xs,
    marginBottom: Spacing.sm,
  },
  titleSkeleton: {
    height: 16,
    width: '100%',
    borderRadius: BorderRadius.xs,
    marginBottom: Spacing.xs,
  },
  titleSkeletonShort: {
    height: 16,
    width: '70%',
    borderRadius: BorderRadius.xs,
  },
});

SkeletonCard.displayName = 'SkeletonCard';
ListingGridSkeleton.displayName = 'ListingGridSkeleton';

export default ListingGridSkeleton;

