// Listing Detail Screen - Modern iOS-aligned design
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  ActivityIndicator,
  Dimensions,
  Alert,
  Share,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { HomeScreenProps } from '../../navigation/types';
import { getListing, deleteListing } from '../../services/listingService';
import { getCurrentUserId } from '../../services/authService';
import { ListingWithUser, ListingTypeDisplay, DeliveryMethodDisplay } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows, Layout } from '../../utils/spacing';
import { ImageGallery, UserAvatar, Button } from '../../components';

type Props = HomeScreenProps<'ListingDetail'>;
const { width: SCREEN_WIDTH } = Dimensions.get('window');

const ListingDetailScreen: React.FC<Props> = ({ navigation, route }) => {
  const { listingId } = route.params;
  const colors = useColors();
  const [listing, setListing] = useState<ListingWithUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  useEffect(() => {
    const load = async () => {
      try {
        const [data, userId] = await Promise.all([
          getListing(listingId),
          getCurrentUserId(),
        ]);
        setListing(data);
        setCurrentUserId(userId);
      } catch (error) {
        console.error('Failed to load listing:', error);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [listingId]);

  const images = listing?.photos?.length
    ? listing.photos
    : listing?.photo
    ? [listing.photo]
    : [];

  const isOwnListing = currentUserId && listing?.user_id === currentUserId;
  const isSeek = listing?.intent === 'seek';

  const formatPrice = (): string => {
    if (!listing) return '';
    if (isSeek) {
      if (listing.budget_min && listing.budget_max) {
        return `$${listing.budget_min.toFixed(0)} - $${listing.budget_max.toFixed(0)}`;
      } else if (listing.budget_max) {
        return `Up to $${listing.budget_max.toFixed(0)}`;
      }
    }
    if (listing.price !== null && listing.price !== undefined) {
      return `$${listing.price.toFixed(2)}`;
    }
    return 'Make an offer';
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const handleShare = useCallback(async () => {
    if (!listing) return;
    
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    
    try {
      await Share.share({
        message: `Check out ${listing.title} on CampusLink! ${formatPrice()}`,
        title: listing.title,
      });
    } catch (error) {
      console.error('Share error:', error);
    }
  }, [listing]);

  const handleEdit = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    navigation.navigate('EditListing', { listingId: listing.id });
  }, [listing, navigation]);

  const handleDelete = useCallback(() => {
    if (!listing) return;
    
    Alert.alert(
      'Delete Listing',
      'Are you sure you want to delete this listing? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            setIsDeleting(true);
            try {
              await deleteListing(listing.id);
              if (Platform.OS !== 'web') {
                Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
              }
              navigation.goBack();
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to delete listing');
            } finally {
              setIsDeleting(false);
            }
          },
        },
      ]
    );
  }, [listing, navigation]);

  const handleMessage = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    // Navigate to chat
    navigation.navigate('Chat', { 
      conversationId: listing.id, // This would need proper conversation handling
    });
  }, [listing, navigation]);

  const handleBuyNow = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    }
    // Handle purchase flow
    Alert.alert('Coming Soon', 'Purchase flow will be implemented');
  }, [listing]);

  const handleMakeOffer = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    // Handle offer flow
    Alert.alert('Coming Soon', 'Offer flow will be implemented');
  }, [listing]);

  const handleSellerPress = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    navigation.navigate('PublicProfile', { userId: listing.user_id });
  }, [listing, navigation]);

  // Loading state
  if (loading) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  // Error state
  if (!listing) {
    return (
      <View style={[styles.errorContainer, { backgroundColor: colors.background }]}>
        <Ionicons name="alert-circle-outline" size={64} color={colors.textTertiary} />
        <Text style={[styles.errorText, { color: colors.textSecondary }]}>
          Listing not found
        </Text>
        <Button
          title="back"
          onPress={() => navigation.goBack()}
          variant="outline"
          size="medium"
          fullWidth={false}
        />
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Image Gallery */}
        <ImageGallery
          images={images}
          showThumbnails={images.length > 1}
          aspectRatio={1}
        />

        {/* Content */}
        <View style={styles.content}>
          {/* Title and Price Section */}
          <View style={styles.titleSection}>
            <View style={styles.titleRow}>
              <Text style={[styles.title, { color: colors.textPrimary }]}>
                {listing.title}
              </Text>
              <Pressable
                onPress={handleShare}
                style={({ pressed }) => [
                  styles.shareButton,
                  { backgroundColor: colors.primaryMuted, opacity: pressed ? 0.7 : 1 },
                ]}
              >
                <Ionicons name="share-outline" size={20} color={colors.primary} />
              </Pressable>
            </View>

            <Text
              style={[
                styles.price,
                { color: isOwnListing ? colors.primary : colors.success },
              ]}
            >
              {formatPrice()}
            </Text>

            {/* Badges */}
            <View style={styles.badgeRow}>
              {/* Category */}
              <View style={[styles.badge, { backgroundColor: colors.primaryMuted }]}>
                <Text style={[styles.badgeText, { color: colors.primary }]}>
                  {listing.category}
                </Text>
              </View>

              {/* Type */}
              <View
                style={[
                  styles.badge,
                  {
                    backgroundColor:
                      listing.listing_type === 'product'
                        ? colors.infoLight
                        : colors.successLight,
                  },
                ]}
              >
                <Text
                  style={[
                    styles.badgeText,
                    {
                      color:
                        listing.listing_type === 'product'
                          ? colors.info
                          : colors.success,
                    },
                  ]}
                >
                  {ListingTypeDisplay[listing.listing_type]}
                </Text>
              </View>

              {/* WANTED badge */}
              {isSeek && (
                <View style={[styles.badge, { backgroundColor: colors.warning }]}>
                  <Text style={[styles.badgeText, { color: colors.textInverse }]}>
                    WANTED
                  </Text>
                </View>
              )}

              {/* Delivery Method */}
              {listing.delivery_method && (
                <View style={[styles.badge, { backgroundColor: colors.surfaceSecondary }]}>
                  <Text style={[styles.badgeText, { color: colors.textSecondary }]}>
                    {DeliveryMethodDisplay[listing.delivery_method]}
                  </Text>
                </View>
              )}
            </View>
          </View>

          {/* Description Section */}
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Description
            </Text>
            <Text style={[styles.description, { color: colors.textSecondary }]}>
              {listing.description}
            </Text>
          </View>

          {/* Seller Info Section */}
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              {isSeek ? 'Posted by' : 'Seller Information'}
            </Text>
            <Pressable
              style={({ pressed }) => [
                styles.sellerCard,
                { backgroundColor: colors.surfaceSecondary, opacity: pressed ? 0.8 : 1 },
              ]}
              onPress={handleSellerPress}
            >
              <UserAvatar user={listing.user} size={50} />
              <View style={styles.sellerInfo}>
                <Text style={[styles.sellerName, { color: colors.textPrimary }]}>
                  {listing.user?.name || 'Unknown'}
                </Text>
                <Text style={[styles.sellerCampus, { color: colors.textSecondary }]}>
                  {listing.user?.campus || 'Campus'}
                </Text>
                {/* TODO: Add ratings here */}
              </View>
              <Ionicons name="chevron-forward" size={20} color={colors.textTertiary} />
            </Pressable>
          </View>

          {/* Listing Details Section */}
          <View style={[styles.section, styles.detailsCard, { backgroundColor: colors.surfaceSecondary }]}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Listing Details
            </Text>
            <View style={styles.detailRow}>
              <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                Posted
              </Text>
              <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                {formatDate(listing.created_at)}
              </Text>
            </View>
            {listing.quantity_available && listing.quantity_available > 1 && (
              <View style={styles.detailRow}>
                <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                  Available
                </Text>
                <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                  {listing.quantity_available} items
                </Text>
              </View>
            )}
          </View>
        </View>
      </ScrollView>

      {/* Bottom Action Bar */}
      <SafeAreaView edges={['bottom']} style={[styles.bottomBar, { backgroundColor: colors.background, borderTopColor: colors.border }]}>
        {isOwnListing ? (
          // Owner actions
          <View style={styles.actionRow}>
            <View style={styles.actionButtonHalf}>
              <Button
                title="Edit"
                onPress={handleEdit}
                variant="primary"
                icon="create-outline"
              />
            </View>
            <View style={styles.actionButtonHalf}>
              <Button
                title="Delete"
                onPress={handleDelete}
                variant="danger"
                icon="trash-outline"
                loading={isDeleting}
              />
            </View>
          </View>
        ) : (
          // Buyer actions
          <View style={styles.actionRow}>
            <Pressable
              style={({ pressed }) => [
                styles.messageButton,
                { backgroundColor: colors.surfaceSecondary, opacity: pressed ? 0.8 : 1 },
              ]}
              onPress={handleMessage}
            >
              <Ionicons name="chatbubble-outline" size={22} color={colors.primary} />
              <Text style={[styles.messageButtonText, { color: colors.primary }]}>
                Message
              </Text>
            </Pressable>
            
            <View style={styles.buyButtonContainer}>
              {listing.accepts_offers && !isSeek && (
                <Pressable
                  style={({ pressed }) => [
                    styles.offerButton,
                    { backgroundColor: colors.primaryMuted, opacity: pressed ? 0.8 : 1 },
                  ]}
                  onPress={handleMakeOffer}
                >
                  <Ionicons name="pricetag-outline" size={18} color={colors.primary} />
                </Pressable>
              )}
              <Pressable
                style={({ pressed }) => [
                  styles.buyButton,
                  { backgroundColor: isSeek ? colors.primary : colors.success, opacity: pressed ? 0.9 : 1 },
                  Shadows.md,
                ]}
                onPress={isSeek ? handleMakeOffer : handleBuyNow}
              >
                <Text style={[styles.buyButtonText, { color: colors.textInverse }]}>
                  {isSeek ? 'Offer My Item' : 'Buy Now'}
                </Text>
              </Pressable>
            </View>
          </View>
        )}
      </SafeAreaView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.lg,
    padding: Spacing.xl,
  },
  errorText: {
    ...Typography.headline,
    textAlign: 'center',
  },
  scrollContent: {
    paddingBottom: 120,
  },
  content: {
    padding: Spacing.lg,
    gap: Spacing.xl,
  },
  titleSection: {
    gap: Spacing.sm,
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.md,
  },
  title: {
    flex: 1,
    ...Typography.title1,
  },
  shareButton: {
    width: 40,
    height: 40,
    borderRadius: BorderRadius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
  price: {
    ...Typography.priceLarge,
  },
  badgeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
    marginTop: Spacing.xs,
  },
  badge: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.md,
  },
  badgeText: {
    ...Typography.footnote,
    fontWeight: '500',
  },
  section: {
    gap: Spacing.sm,
  },
  sectionTitle: {
    ...Typography.headline,
  },
  description: {
    ...Typography.body,
    lineHeight: 24,
  },
  sellerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
    gap: Spacing.md,
  },
  sellerInfo: {
    flex: 1,
    gap: 2,
  },
  sellerName: {
    ...Typography.headline,
  },
  sellerCampus: {
    ...Typography.footnote,
  },
  detailsCard: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.xs,
  },
  detailLabel: {
    ...Typography.subheadline,
  },
  detailValue: {
    ...Typography.subheadlineBold,
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: Spacing.lg,
    borderTopWidth: 1,
  },
  actionRow: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  actionButtonHalf: {
    flex: 1,
  },
  messageButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    borderRadius: BorderRadius.lg,
    gap: Spacing.sm,
  },
  messageButtonText: {
    ...Typography.button,
  },
  buyButtonContainer: {
    flex: 1,
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  offerButton: {
    width: 48,
    height: 48,
    borderRadius: BorderRadius.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buyButton: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.lg,
  },
  buyButtonText: {
    ...Typography.button,
  },
});

export default ListingDetailScreen;
