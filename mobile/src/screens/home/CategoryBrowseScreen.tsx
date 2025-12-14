// Category Browse Screen
import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, SafeAreaView, ScrollView, TouchableOpacity, Platform, FlatList, RefreshControl, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { HomeScreenProps } from '../../navigation/types';
import Colors from '../../utils/colors';
import { getListings } from '../../services/listingService';
import { ListingWithUser } from '../../types';
import { ListingCardModern } from '../../components';
import { getCurrentUserId } from '../../services/authService';

type Props = HomeScreenProps<'CategoryBrowse'>;

interface Category {
  name: string;
  icon: keyof typeof Ionicons.glyphMap;
  type: 'product' | 'service';
}

// Product categories matching iOS
const PRODUCT_CATEGORIES: Category[] = [
  { name: 'Electronics', icon: 'laptop-outline', type: 'product' },
  { name: 'Books', icon: 'book-outline', type: 'product' },
  { name: 'Furniture', icon: 'bed-outline', type: 'product' },
  { name: 'Clothing', icon: 'shirt-outline', type: 'product' },
  { name: 'Sports', icon: 'basketball-outline', type: 'product' },
  { name: 'Tickets', icon: 'ticket-outline', type: 'product' },
  { name: 'Other', icon: 'grid-outline', type: 'product' },
];

// Service categories matching iOS
const SERVICE_CATEGORIES: Category[] = [
  { name: 'Tutoring', icon: 'school-outline', type: 'service' },
  { name: 'Moving', icon: 'cube-outline', type: 'service' },
  { name: 'Cleaning', icon: 'sparkles-outline', type: 'service' },
  { name: 'Other', icon: 'construct-outline', type: 'service' }, // Match database schema
];

const PAGE_SIZE = 20; // Match iOS implementation

const CategoryBrowseScreen: React.FC<Props> = ({ route, navigation }) => {
  const category = route.params?.category;
  
  // State for listings view
  const [listings, setListings] = useState<ListingWithUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMorePages, setHasMorePages] = useState(true);
  const [currentPage, setCurrentPage] = useState(0);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  const handleCategoryPress = (selectedCategory: Category) => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    
    navigation.push('CategoryBrowse', { category: selectedCategory.name });
  };

  // Load listings for the selected category
  const loadListings = useCallback(async (page: number = 0, append: boolean = false) => {
    if (!category) return;
    
    if (!append) {
      setLoading(true);
    }
    
    try {
      const offset = page * PAGE_SIZE;
      
      // Determine listing type based on category
      const categoryInfo = [...PRODUCT_CATEGORIES, ...SERVICE_CATEGORIES].find(c => c.name === category);
      const listingType = categoryInfo?.type;
      
      const data = await getListings({
        limit: PAGE_SIZE,
        offset,
        category: category, // Keep original casing - database stores 'Electronics', not 'electronics'
        listingType: listingType, // Filter by product or service
        filterByCampus: true, // Server-side filtering - filters at DB level before pagination
      });
      
      if (append) {
        setListings(prev => [...prev, ...data]);
      } else {
        setListings(data);
      }
      
      // Check if we have more pages
      setHasMorePages(data.length === PAGE_SIZE);
    } catch (error) {
      console.error('Failed to load category listings:', error);
    } finally {
      setLoading(false);
      setLoadingMore(false);
      setRefreshing(false);
    }
  }, [category]);

  // Load more listings (standard pagination only - no infinite looping)
  const loadMore = useCallback(async () => {
    if (loadingMore || loading || !hasMorePages) return;
    
    setLoadingMore(true);
    const nextPage = currentPage + 1;
    setCurrentPage(nextPage);
    await loadListings(nextPage, true);
  }, [loadingMore, loading, hasMorePages, currentPage, loadListings]);

  // Refresh listings
  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    setCurrentPage(0);
    setHasMorePages(true);
    await loadListings(0, false);
  }, [loadListings]);

  // Initialize
  useEffect(() => {
    const init = async () => {
      const userId = await getCurrentUserId();
      setCurrentUserId(userId);
      
      if (category) {
        setLoading(true);
        setCurrentPage(0);
        setHasMorePages(true);
        await loadListings(0, false);
      }
    };
    init();
  }, [category]);

  // Render listing card
  const renderListingCard = useCallback(({ item, index }: { item: ListingWithUser; index: number }) => {
    const isOwnListing = currentUserId && item.user_id === currentUserId;
    const isLeftColumn = index % 2 === 0;

    return (
      <View style={[styles.cardWrapper, isLeftColumn ? styles.cardLeft : styles.cardRight]}>
        <ListingCardModern
          listing={item}
          isOwnListing={!!isOwnListing}
          onPress={() => navigation.navigate('ListingDetail', { listingId: item.id })}
        />
      </View>
    );
  }, [currentUserId, navigation]);

  // Loading footer
  const renderFooter = () => {
    if (!loadingMore) return null;
    
    return (
      <View style={styles.footerLoader}>
        <ActivityIndicator size="small" color={Colors.primary} />
      </View>
    );
  };

  // Empty state
  const renderEmptyState = () => {
    if (loading) return null;
    
    return (
      <View style={styles.emptyContainer}>
        <Ionicons name="search-outline" size={50} color={Colors.textSecondary} />
        <Text style={styles.emptyTitle}>No {category} listings yet</Text>
        <Text style={styles.emptySubtitle}>Be the first to post in this category!</Text>
      </View>
    );
  };

  // If a specific category is selected, show listings with infinite scroll
  if (category) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity 
            onPress={() => navigation.goBack()}
            style={styles.backButton}
          >
            <Text style={styles.backButtonText}>back</Text>
          </TouchableOpacity>
          <Text style={styles.headerTitle}>{category}</Text>
          <View style={styles.headerSpacer} />
        </View>
        
        {loading && listings.length === 0 ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color={Colors.primary} />
          </View>
        ) : (
          <FlatList
            data={listings}
            renderItem={renderListingCard}
            keyExtractor={(item) => item.id}
            numColumns={2}
            ListEmptyComponent={renderEmptyState}
            ListFooterComponent={renderFooter}
            contentContainerStyle={styles.listContent}
            columnWrapperStyle={styles.columnWrapper}
            showsVerticalScrollIndicator={false}
            refreshControl={
              <RefreshControl
                refreshing={refreshing}
                onRefresh={onRefresh}
                tintColor={Colors.primary}
                colors={[Colors.primary]}
              />
            }
            onEndReached={loadMore}
            onEndReachedThreshold={0.5}
          />
        )}
      </SafeAreaView>
    );
  }

  // Show category browser
  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Products Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Products</Text>
          <View style={styles.grid}>
            {PRODUCT_CATEGORIES.map((cat) => (
              <TouchableOpacity
                key={cat.name}
                style={styles.categoryCard}
                onPress={() => handleCategoryPress(cat)}
                activeOpacity={0.7}
              >
                <View style={styles.iconContainer}>
                  <Ionicons name={cat.icon} size={28} color={Colors.primary} />
                </View>
                <Text style={styles.categoryName}>{cat.name}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Services Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Services</Text>
          <View style={styles.grid}>
            {SERVICE_CATEGORIES.map((cat) => (
              <TouchableOpacity
                key={cat.name}
                style={styles.categoryCard}
                onPress={() => handleCategoryPress(cat)}
                activeOpacity={0.7}
              >
                <View style={styles.iconContainer}>
                  <Ionicons name={cat.icon} size={28} color={Colors.primary} />
                </View>
                <Text style={styles.categoryName}>{cat.name}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  scrollContent: {
    padding: 16,
  },
  section: {
    marginBottom: 32,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginBottom: 16,
    marginLeft: 4,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    justifyContent: 'space-between',
  },
  categoryCard: {
    width: '48%',
    backgroundColor: Colors.cardBackground,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 120,
  },
  iconContainer: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: Colors.primaryMuted,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  categoryName: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textPrimary,
    textAlign: 'center',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginTop: 16,
    marginBottom: 8,
  },
  emptySubtitle: {
    fontSize: 16,
    color: Colors.textSecondary,
    textAlign: 'center',
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
  backButton: {
    padding: 8,
  },
  backButtonText: {
    fontSize: 17,
    color: Colors.primary,
    fontWeight: '400',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  headerSpacer: {
    width: 40, // Same as back button width for centering
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 24,
  },
  columnWrapper: {
    gap: 12,
    marginBottom: 12,
  },
  cardWrapper: {
    flex: 1,
  },
  cardLeft: {
    marginRight: 6,
  },
  cardRight: {
    marginLeft: 6,
  },
  footerLoader: {
    paddingVertical: 20,
    alignItems: 'center',
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
    paddingHorizontal: 24,
  },
});

export default CategoryBrowseScreen;

