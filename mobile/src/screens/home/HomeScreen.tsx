// Home Screen - Main Marketplace Feed
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  SafeAreaView,
  Image,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { HomeScreenProps } from '../../navigation/types';
import { getListings } from '../../services/listingService';
import { getCurrentUserId } from '../../services/authService';
import { ListingWithUser } from '../../types';
import Colors from '../../utils/colors';

type Props = HomeScreenProps<'HomeMain'>;

const HomeScreen: React.FC<Props> = ({ navigation }) => {
  const [listings, setListings] = useState<ListingWithUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  const loadListings = async () => {
    try {
      const data = await getListings({ limit: 20 });
      setListings(data);
    } catch (error) {
      console.error('Failed to load listings:', error);
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadListings();
    setRefreshing(false);
  }, []);

  useEffect(() => {
    const init = async () => {
      const userId = await getCurrentUserId();
      setCurrentUserId(userId);
      await loadListings();
    };
    init();
  }, []);

  const renderListingCard = ({ item }: { item: ListingWithUser }) => {
    const isOwnListing = currentUserId && item.user_id === currentUserId;
    
    return (
      <TouchableOpacity
        style={styles.card}
        onPress={() => navigation.navigate('ListingDetail', { listingId: item.id })}
      >
        {/* Image */}
        <View style={styles.imageContainer}>
          {item.photos?.[0] || item.photo ? (
            <Image
              source={{ uri: item.photos?.[0] || item.photo || '' }}
              style={styles.image}
              resizeMode="cover"
            />
          ) : (
            <View style={styles.imagePlaceholder}>
              <Ionicons name="image-outline" size={32} color={Colors.textTertiary} />
            </View>
          )}
          {item.intent === 'seek' && (
            <View style={styles.seekBadge}>
              <Text style={styles.seekBadgeText}>WANTED</Text>
            </View>
          )}
        </View>

        {/* Info */}
        <View style={styles.cardContent}>
          <Text style={styles.title} numberOfLines={2}>
            {item.title}
          </Text>
          <Text style={[styles.price, isOwnListing ? styles.priceOwn : styles.priceOther]}>
            {item.price !== null ? `$${item.price.toFixed(2)}` : 'Make an offer'}
          </Text>
          <Text style={styles.seller} numberOfLines={1}>
            {item.user?.name || 'Unknown'}
          </Text>
        </View>
      </TouchableOpacity>
    );
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={Colors.primary} />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>CampusLink</Text>
        <TouchableOpacity
          style={styles.searchButton}
          onPress={() => navigation.navigate('Search')}
        >
          <Ionicons name="search" size={24} color={Colors.textPrimary} />
        </TouchableOpacity>
      </View>

      {/* Listings Grid */}
      <FlatList
        data={listings}
        renderItem={renderListingCard}
        keyExtractor={(item) => item.id}
        numColumns={2}
        contentContainerStyle={styles.listContent}
        columnWrapperStyle={styles.row}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>No listings yet</Text>
            <Text style={styles.emptySubtext}>Be the first to post!</Text>
          </View>
        }
      />
    </SafeAreaView>
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  searchButton: {
    padding: 8,
  },
  listContent: {
    padding: 8,
  },
  row: {
    justifyContent: 'space-between',
  },
  card: {
    width: '48%',
    backgroundColor: Colors.surface,
    borderRadius: 12,
    marginBottom: 12,
    overflow: 'hidden',
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  imageContainer: {
    aspectRatio: 1,
    backgroundColor: Colors.surfaceSecondary,
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
  seekBadge: {
    position: 'absolute',
    top: 8,
    left: 8,
    backgroundColor: Colors.warning,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  seekBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    color: Colors.textInverse,
  },
  cardContent: {
    padding: 10,
  },
  title: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  price: {
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 4,
  },
  priceOwn: {
    color: Colors.primary, // Blue for your own posts
  },
  priceOther: {
    color: '#34C759', // Green for other people's posts
  },
  seller: {
    fontSize: 12,
    color: Colors.textSecondary,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 100,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  emptySubtext: {
    fontSize: 14,
    color: Colors.textSecondary,
  },
});

export default HomeScreen;

