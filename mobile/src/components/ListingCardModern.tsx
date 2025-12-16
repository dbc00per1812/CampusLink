// Modern Listing Card - iOS-aligned design with shadows and badges
import React, { memo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  Pressable,
  Dimensions,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius, Shadows } from '../utils/spacing';
import { ListingWithUser } from '../types';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const CARD_GAP = Spacing.md;
const CARD_WIDTH = (SCREEN_WIDTH - Spacing.lg * 2 - CARD_GAP) / 2;

interface ListingCardModernProps {
  listing: ListingWithUser;
  isOwnListing?: boolean;
  onPress: () => void;
}

const ListingCardModern: React.FC<ListingCardModernProps> = memo(({
  listing,
  isOwnListing = false,
  onPress,
}) => {
  const colors = useColors();
  const imageUrl = listing.photos?.[0] || listing.photo || null;
  const photoCount = listing.photos?.length || (listing.photo ? 1 : 0);
  const isSeek = listing.intent === 'seek';
  const hasQuantity = listing.quantity_available && listing.quantity_available > 1;

  const formatPrice = (): string => {
    if (isSeek) {
      if (listing.budget_min && listing.budget_max) {
        return `$${listing.budget_min.toFixed(0)}-$${listing.budget_max.toFixed(0)}`;
      } else if (listing.budget_max) {
        return `Up to $${listing.budget_max.toFixed(0)}`;
      }
    }
    if (listing.price !== null && listing.price !== undefined) {
      return `$${listing.price.toFixed(2)}`;
    }
    return 'Make an offer';
  };

  return (
    <Pressable
      style={({ pressed }) => [
        styles.card,
        { backgroundColor: colors.cardBackground },
        Shadows.card,
        pressed && styles.cardPressed,
      ]}
      onPress={onPress}
    >
      {/* Image Container */}
      <View style={[styles.imageContainer, { backgroundColor: colors.surfaceSecondary }]}>
        {imageUrl ? (
          <Image
            source={{ uri: imageUrl }}
            style={styles.image}
            resizeMode="cover"
          />
        ) : (
          <View style={styles.imagePlaceholder}>
            <Ionicons
              name="image-outline"
              size={36}
              color={colors.textTertiary}
            />
            <Text style={[styles.noPhotoText, { color: colors.textTertiary }]}>
              No photo
            </Text>
          </View>
        )}

        {/* Quantity Badge - Top Left */}
        {hasQuantity && (
          <View style={[styles.quantityBadge, { backgroundColor: colors.overlay }]}>
            <Text style={styles.quantityText}>
              {listing.quantity_available} left
            </Text>
          </View>
        )}

        {/* Photo Count Badge - Top Right */}
        {photoCount > 1 && (
          <View style={[styles.photoCountBadge, { backgroundColor: colors.overlay }]}>
            <Ionicons name="images" size={10} color={colors.textInverse} />
            <Text style={styles.photoCountText}>{photoCount}</Text>
          </View>
        )}

        {/* WANTED Badge - Bottom Left */}
        {isSeek && (
          <View style={[styles.wantedBadge, { backgroundColor: colors.warning }]}>
            <Text style={styles.wantedText}>WANTED</Text>
          </View>
        )}
      </View>

      {/* Content */}
      <View style={styles.content}>
        {/* Price */}
        <Text
          style={[
            styles.price,
            { color: isOwnListing ? colors.primary : colors.success },
          ]}
          numberOfLines={1}
        >
          {formatPrice()}
        </Text>

        {/* Title */}
        <Text
          style={[styles.title, { color: colors.textPrimary }]}
          numberOfLines={2}
        >
          {listing.title}
        </Text>
      </View>
    </Pressable>
  );
});

// Skeleton loading component
export const ListingCardSkeleton: React.FC = memo(() => {
  const colors = useColors();

  return (
    <View style={[styles.card, { backgroundColor: colors.cardBackground }, Shadows.card]}>
      <View style={[styles.imageContainer, styles.skeleton, { backgroundColor: colors.skeletonBase }]} />
      <View style={styles.content}>
        <View style={[styles.skeletonPrice, { backgroundColor: colors.skeletonBase }]} />
        <View style={[styles.skeletonTitle, { backgroundColor: colors.skeletonBase }]} />
        <View style={[styles.skeletonTitleShort, { backgroundColor: colors.skeletonBase }]} />
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  card: {
    width: CARD_WIDTH,
    borderRadius: BorderRadius.lg,
    overflow: 'hidden',
  },
  cardPressed: {
    transform: [{ scale: 0.98 }],
    opacity: 0.9,
  },
  imageContainer: {
    width: '100%',
    aspectRatio: 1,
    position: 'relative',
  },
  image: {
    width: '100%',
    height: '100%',
  },
  imagePlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.xs,
  },
  noPhotoText: {
    ...Typography.caption2,
  },
  quantityBadge: {
    position: 'absolute',
    top: Spacing.sm,
    left: Spacing.sm,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.sm,
  },
  quantityText: {
    ...Typography.captionBold,
    color: '#FFFFFF',
  },
  photoCountBadge: {
    position: 'absolute',
    top: Spacing.sm,
    right: Spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.sm,
  },
  photoCountText: {
    ...Typography.caption2,
    color: '#FFFFFF',
    fontWeight: '500',
  },
  wantedBadge: {
    position: 'absolute',
    bottom: Spacing.sm,
    left: Spacing.sm,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.sm,
  },
  wantedText: {
    ...Typography.badge,
    color: '#FFFFFF',
  },
  content: {
    padding: Spacing.md,
  },
  price: {
    ...Typography.price,
    marginBottom: Spacing.xs,
  },
  title: {
    ...Typography.subheadlineBold,
  },
  // Skeleton styles
  skeleton: {
    overflow: 'hidden',
  },
  skeletonPrice: {
    height: 22,
    width: '60%',
    borderRadius: BorderRadius.xs,
    marginBottom: Spacing.sm,
  },
  skeletonTitle: {
    height: 16,
    width: '100%',
    borderRadius: BorderRadius.xs,
    marginBottom: Spacing.xs,
  },
  skeletonTitleShort: {
    height: 16,
    width: '70%',
    borderRadius: BorderRadius.xs,
  },
});

ListingCardModern.displayName = 'ListingCardModern';
ListingCardSkeleton.displayName = 'ListingCardSkeleton';

export default ListingCardModern;

