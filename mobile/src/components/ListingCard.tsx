// ListingCard Component - Reusable grid card for listings
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  Dimensions,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { ListingWithUser } from '../types';
import Colors from '../utils/colors';

const { width } = Dimensions.get('window');
const CARD_WIDTH = (width - 36) / 2; // 2 columns with padding

interface ListingCardProps {
  listing: ListingWithUser;
  onPress: () => void;
  showSeller?: boolean;
}

const ListingCard: React.FC<ListingCardProps> = ({
  listing,
  onPress,
  showSeller = true,
}) => {
  const imageUrl = listing.photos?.[0] || listing.photo || null;
  const isSeek = listing.intent === 'seek';
  const isService = listing.listing_type === 'service';

  const formatPrice = (): string => {
    if (listing.price === null) {
      if (isSeek && listing.budget_min !== null && listing.budget_max !== null) {
        return `$${listing.budget_min} - $${listing.budget_max}`;
      }
      return 'Make an offer';
    }
    return `$${listing.price.toFixed(2)}`;
  };

  return (
    <TouchableOpacity style={styles.card} onPress={onPress} activeOpacity={0.8}>
      {/* Image */}
      <View style={styles.imageContainer}>
        {imageUrl ? (
          <Image source={{ uri: imageUrl }} style={styles.image} resizeMode="cover" />
        ) : (
          <View style={styles.imagePlaceholder}>
            <Ionicons
              name={isService ? 'construct-outline' : 'image-outline'}
              size={32}
              color={Colors.textTertiary}
            />
          </View>
        )}

        {/* Badges */}
        <View style={styles.badgeContainer}>
          {isSeek && (
            <View style={[styles.badge, styles.seekBadge]}>
              <Text style={styles.badgeText}>WANTED</Text>
            </View>
          )}
          {isService && !isSeek && (
            <View style={[styles.badge, styles.serviceBadge]}>
              <Text style={styles.badgeText}>SERVICE</Text>
            </View>
          )}
        </View>

        {/* Sold overlay */}
        {listing.is_sold && (
          <View style={styles.soldOverlay}>
            <Text style={styles.soldText}>SOLD</Text>
          </View>
        )}
      </View>

      {/* Content */}
      <View style={styles.content}>
        <Text style={styles.title} numberOfLines={2}>
          {listing.title}
        </Text>
        <Text style={styles.price}>{formatPrice()}</Text>
        {showSeller && listing.user && (
          <Text style={styles.seller} numberOfLines={1}>
            {listing.user.name || 'Unknown'}
          </Text>
        )}
      </View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  card: {
    width: CARD_WIDTH,
    backgroundColor: Colors.surface,
    borderRadius: 12,
    overflow: 'hidden',
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  imageContainer: {
    width: '100%',
    aspectRatio: 1,
    backgroundColor: Colors.surfaceSecondary,
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
  },
  badgeContainer: {
    position: 'absolute',
    top: 8,
    left: 8,
    flexDirection: 'row',
    gap: 4,
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  seekBadge: {
    backgroundColor: Colors.warning,
  },
  serviceBadge: {
    backgroundColor: Colors.primary,
  },
  badgeText: {
    fontSize: 9,
    fontWeight: '700',
    color: Colors.textInverse,
    letterSpacing: 0.5,
  },
  soldOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  soldText: {
    fontSize: 18,
    fontWeight: '700',
    color: Colors.textInverse,
    letterSpacing: 2,
  },
  content: {
    padding: 10,
  },
  title: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.textPrimary,
    marginBottom: 4,
    lineHeight: 18,
  },
  price: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.primary,
    marginBottom: 4,
  },
  seller: {
    fontSize: 12,
    color: Colors.textSecondary,
  },
});

export default ListingCard;

