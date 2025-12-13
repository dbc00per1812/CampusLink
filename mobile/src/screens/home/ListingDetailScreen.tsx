// Listing Detail Screen
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Image,
  TouchableOpacity,
  ActivityIndicator,
  Dimensions,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { HomeScreenProps } from '../../navigation/types';
import { getListing, deleteListing } from '../../services/listingService';
import { getCurrentUserId } from '../../services/authService';
import { ListingWithUser, ListingTypeDisplay, DeliveryMethodDisplay } from '../../types';
import Colors from '../../utils/colors';

type Props = HomeScreenProps<'ListingDetail'>;
const { width } = Dimensions.get('window');

const ListingDetailScreen: React.FC<Props> = ({ navigation, route }) => {
  const { listingId } = route.params;
  const [listing, setListing] = useState<ListingWithUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeImageIndex, setActiveImageIndex] = useState(0);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

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

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </View>
    );
  }

  if (!listing) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>Listing not found</Text>
      </View>
    );
  }

  const images = listing.photos?.length ? listing.photos : listing.photo ? [listing.photo] : [];
  const isOwnListing = currentUserId && listing.user_id === currentUserId;

  const handleEdit = () => {
    navigation.navigate('EditListing', { listingId: listing.id });
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete Listing',
      'Are you sure you want to delete this listing? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await deleteListing(listing.id);
              Alert.alert('Success', 'Listing deleted successfully', [
                { text: 'OK', onPress: () => navigation.goBack() }
              ]);
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to delete listing');
            }
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Image Carousel */}
        <View style={styles.imageContainer}>
          {images.length > 0 ? (
            <ScrollView
              horizontal
              pagingEnabled
              showsHorizontalScrollIndicator={false}
              onMomentumScrollEnd={(e) => {
                const index = Math.round(e.nativeEvent.contentOffset.x / width);
                setActiveImageIndex(index);
              }}
            >
              {images.map((uri, index) => (
                <Image key={index} source={{ uri }} style={styles.image} resizeMode="cover" />
              ))}
            </ScrollView>
          ) : (
            <View style={styles.imagePlaceholder}>
              <Ionicons name="image-outline" size={64} color={Colors.textTertiary} />
            </View>
          )}
          {images.length > 1 && (
            <View style={styles.imageIndicators}>
              {images.map((_, index) => (
                <View
                  key={index}
                  style={[
                    styles.indicator,
                    index === activeImageIndex && styles.indicatorActive,
                  ]}
                />
              ))}
            </View>
          )}
        </View>

        {/* Content */}
        <View style={styles.content}>
          {/* Title & Price */}
          <Text style={styles.title}>{listing.title}</Text>
          <Text style={[styles.price, isOwnListing ? styles.priceOwn : styles.priceOther]}>
            {listing.price !== null ? `$${listing.price.toFixed(2)}` : 'Make an offer'}
          </Text>

          {/* Badges */}
          <View style={styles.badgeRow}>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{ListingTypeDisplay[listing.listing_type]}</Text>
            </View>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{listing.category}</Text>
            </View>
            {listing.delivery_method && (
              <View style={styles.badge}>
                <Text style={styles.badgeText}>
                  {DeliveryMethodDisplay[listing.delivery_method]}
                </Text>
              </View>
            )}
          </View>

          {/* Description */}
          <Text style={styles.sectionTitle}>Description</Text>
          <Text style={styles.description}>{listing.description}</Text>

          {/* Seller Info */}
          <TouchableOpacity
            style={styles.sellerCard}
            onPress={() => navigation.navigate('PublicProfile', { userId: listing.user_id })}
          >
            <View style={styles.sellerAvatar}>
              {listing.user?.profile_pic ? (
                <Image source={{ uri: listing.user.profile_pic }} style={styles.avatarImage} />
              ) : (
                <Ionicons name="person-circle" size={48} color={Colors.textTertiary} />
              )}
            </View>
            <View style={styles.sellerInfo}>
              <Text style={styles.sellerName}>{listing.user?.name || 'Unknown'}</Text>
              <Text style={styles.sellerCampus}>{listing.user?.campus || 'Campus'}</Text>
            </View>
            <Ionicons name="chevron-forward" size={20} color={Colors.textTertiary} />
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* Bottom Action */}
      <View style={styles.bottomBar}>
        {isOwnListing ? (
          <>
            <TouchableOpacity style={styles.editButton} onPress={handleEdit}>
              <Ionicons name="create-outline" size={20} color={Colors.textInverse} />
              <Text style={styles.editButtonText}>Edit</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.deleteButton} onPress={handleDelete}>
              <Ionicons name="trash-outline" size={20} color={Colors.textInverse} />
              <Text style={styles.deleteButtonText}>Delete</Text>
            </TouchableOpacity>
          </>
        ) : (
          <>
            <TouchableOpacity style={styles.messageButton}>
              <Ionicons name="chatbubble-outline" size={20} color={Colors.primary} />
              <Text style={styles.messageButtonText}>Message</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.buyButton}>
              <Text style={styles.buyButtonText}>
                {listing.intent === 'seek' ? 'Make Offer' : 'Buy Now'}
              </Text>
            </TouchableOpacity>
          </>
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
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
  },
  errorText: {
    fontSize: 16,
    color: Colors.textSecondary,
  },
  scrollContent: {
    paddingBottom: 100,
  },
  imageContainer: {
    width: width,
    height: width,
    backgroundColor: Colors.surfaceSecondary,
  },
  image: {
    width: width,
    height: width,
  },
  imagePlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  imageIndicators: {
    position: 'absolute',
    bottom: 16,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
  },
  indicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: 'rgba(255,255,255,0.5)',
  },
  indicatorActive: {
    backgroundColor: Colors.textInverse,
  },
  content: {
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginBottom: 8,
  },
  price: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 16,
  },
  priceOwn: {
    color: Colors.primary, // Blue for your own posts
  },
  priceOther: {
    color: '#34C759', // Green for other people's posts
  },
  badgeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 24,
  },
  badge: {
    backgroundColor: Colors.surfaceSecondary,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  badgeText: {
    fontSize: 13,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 8,
  },
  description: {
    fontSize: 15,
    color: Colors.textSecondary,
    lineHeight: 22,
    marginBottom: 24,
  },
  sellerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surfaceSecondary,
    padding: 12,
    borderRadius: 12,
  },
  sellerAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    overflow: 'hidden',
  },
  avatarImage: {
    width: 48,
    height: 48,
  },
  sellerInfo: {
    flex: 1,
    marginLeft: 12,
  },
  sellerName: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  sellerCampus: {
    fontSize: 14,
    color: Colors.textSecondary,
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    padding: 16,
    paddingBottom: 32,
    backgroundColor: Colors.background,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    gap: 12,
  },
  messageButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSecondary,
    paddingVertical: 14,
    borderRadius: 12,
    gap: 8,
  },
  messageButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.primary,
  },
  buyButton: {
    flex: 2,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.primary,
    paddingVertical: 14,
    borderRadius: 12,
  },
  buyButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textInverse,
  },
  editButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.primary,
    paddingVertical: 14,
    borderRadius: 12,
    gap: 8,
  },
  editButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textInverse,
  },
  deleteButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FF3B30',
    paddingVertical: 14,
    borderRadius: 12,
    gap: 8,
  },
  deleteButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textInverse,
  },
});

export default ListingDetailScreen;

