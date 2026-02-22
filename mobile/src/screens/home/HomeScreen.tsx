// Home Screen - Modern Marketplace Feed
// Aligned with iOS CampusLink design
// Logo added to header
import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  RefreshControl,
  Image,
  Pressable,
  Platform,
  Dimensions,
  ActivityIndicator,
  Keyboard,
  TouchableWithoutFeedback,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useScrollToTop } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { HomeScreenProps } from '../../navigation/types';
import { getListings } from '../../services/listingService';
import { getCurrentUserId } from '../../services/authService';
import { ListingWithUser } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { useOrderMonitor } from '../../context/OrderMonitorContext';
import { useOfferMonitor } from '../../context/OfferMonitorContext';
import { supabase } from '../../config/supabase';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows, Layout } from '../../utils/spacing';
import {
  ListingCardModern,
  FilterChips,
  HOME_FILTER_CHIPS,
  SearchBarWithFilters,
  ActiveOrderBanner,
  ActiveOfferBanner,
  ListingGridSkeleton,
} from '../../components';
import { prefetchListingImages } from '../../hooks/useImagePrefetch';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const CARD_GAP = Spacing.md;
const CARD_WIDTH = (SCREEN_WIDTH - Spacing.lg * 2 - CARD_GAP) / 2;

type Props = HomeScreenProps<'HomeMain'>;

// Filter types matching iOS
type FilterType = 'forYou' | 'all' | 'selling' | 'wanted' | 'more';

const PAGE_SIZE = 20; // Match iOS implementation

const HomeScreen: React.FC<Props> = ({ navigation }) => {
  const colors = useColors();
  const { activeOrderCount, activeOrders } = useOrderMonitor();
  const { pendingReceivedCount, pendingSentCount } = useOfferMonitor();
  const flatListRef = useRef<FlatList>(null);
  const [listings, setListings] = useState<ListingWithUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMorePages, setHasMorePages] = useState(true);
  const [currentPage, setCurrentPage] = useState(0);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [selectedFilter, setSelectedFilter] = useState<FilterType>('forYou');
  const [searchQuery, setSearchQuery] = useState('');
  const [userCampus, setUserCampus] = useState<string | null>(null);
  const [filterTransitioning, setFilterTransitioning] = useState(false); // Optimistic filter switching
  const [isSearchFocused, setIsSearchFocused] = useState(false);
  
  // Infinite scroll looping (matching iOS)
  const [originalListings, setOriginalListings] = useState<ListingWithUser[]>([]);
  const [isLooping, setIsLooping] = useState(false);
  const [loopCount, setLoopCount] = useState(0);

  // Load listings based on filter
  const loadListings = useCallback(async (filter: FilterType = selectedFilter, page: number = 0, append: boolean = false, isFilterChange: boolean = false) => {
    try {
      let params: any = { 
        limit: PAGE_SIZE,
        offset: page * PAGE_SIZE,
        filterByCampus: true, // Server-side filtering - filters at DB level before pagination
      };
      
      switch (filter) {
        case 'selling':
          params.intent = 'offer';
          break;
        case 'wanted':
          params.intent = 'seek';
          break;
        case 'forYou':
        case 'all':
        default:
          // No filter
          break;
      }

      const data = await getListings(params);
      
      if (append) {
        setListings(prev => [...prev, ...data]);
      } else {
        setListings(data);
        // Store original listings for infinite looping (matching iOS)
        if (data.length > 0 && page === 0) {
          setOriginalListings(data);
          setIsLooping(false);
        }
      }
      
      // Check if we have more pages
      setHasMorePages(data.length === PAGE_SIZE);
      
      // PERFORMANCE: Prefetch images for faster rendering
      if (data.length > 0) {
        prefetchListingImages(data);
      }
    } catch (error) {
      console.error('Failed to load listings:', error);
    } finally {
      setLoading(false);
      setLoadingMore(false);
      setFilterTransitioning(false);
    }
  }, [selectedFilter]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    setCurrentPage(0);
    setHasMorePages(true);
    await loadListings(selectedFilter, 0, false);
    setRefreshing(false);
  }, [loadListings, selectedFilter]);

  // Shuffle array utility (matching iOS)
  const shuffleArray = <T,>(array: T[]): T[] => {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  };

  // Load more listings (infinite scroll with looping)
  const loadMore = useCallback(async () => {
    if (loadingMore || loading) return;
    
    // If we've reached the end and have original listings, loop them (matching iOS)
    if (!hasMorePages && originalListings.length > 0) {
      setLoadingMore(true);
      
      // Small delay to simulate loading for smooth UX (matching iOS 0.2s delay)
      await new Promise(resolve => setTimeout(resolve, 200));
      
      // Append a shuffled version of original listings to add variety
      const shuffledOriginals = shuffleArray(originalListings);
      // Create unique listings with loop suffix to avoid key conflicts
      const uniqueLoopedListings = shuffledOriginals.map((listing, idx) => ({
        ...listing,
        _loopId: `${listing.id}_loop${loopCount}_${idx}`,
      }));
      setListings(prev => [...prev, ...uniqueLoopedListings]);
      setIsLooping(true);
      setLoopCount(prev => prev + 1);
      setLoadingMore(false);
      
      console.log('🔄 Infinite Scroll: Looping listings (shuffled for variety)');
      return;
    }
    
    // Normal pagination if still have pages
    if (!hasMorePages) return;
    
    setLoadingMore(true);
    const nextPage = currentPage + 1;
    setCurrentPage(nextPage);
    await loadListings(selectedFilter, nextPage, true);
  }, [loadingMore, hasMorePages, loading, currentPage, selectedFilter, originalListings, loadListings, loopCount]);

  const handleFilterChange = useCallback((filterId: string) => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    
    if (filterId === 'more') {
      // Navigate to category browser
      navigation.navigate('CategoryBrowse');
      return;
    }
    
    // Optimistic filter switch - keep current listings visible during transition
    setSelectedFilter(filterId as FilterType);
    setFilterTransitioning(true);
    setCurrentPage(0);
    setHasMorePages(true);
    loadListings(filterId as FilterType, 0, false, true);
  }, [loadListings, navigation]);

  const handleSearch = useCallback(() => {
    if (searchQuery.trim()) {
      navigation.navigate('Search', { query: searchQuery });
    }
  }, [navigation, searchQuery]);

  const handleDismissSearch = useCallback(() => {
    Keyboard.dismiss();
    setIsSearchFocused(false);
  }, []);

  const handleActiveOrderPress = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    
    // If there's exactly one active order, navigate directly to it
    // Otherwise, navigate to the orders list
    if (activeOrders.length === 1) {
      navigation.navigate('Wallet', { 
        screen: 'OrderDetail', 
        params: { orderId: activeOrders[0].id }
      });
    } else {
      navigation.navigate('Wallet', { screen: 'OrdersList' });
    }
  }, [navigation, activeOrders]);

  const handleActiveOfferPress = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    // Navigate to the My Offers screen in Profile stack
    navigation.navigate('Profile', { screen: 'MyOffers' });
  }, [navigation]);

  const handleSellNow = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    // Navigate to Post tab (which contains CreateListingScreen)
    navigation.navigate('Post' as any);
  }, [navigation]);

  const handleHelpPress = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    navigation.navigate('TransactionGuide');
  }, [navigation]);

  // Get campus abbreviation (matching iOS)
  const getCampusAbbreviation = (campus: string): string => {
    switch (campus) {
      case 'Indiana University Bloomington':
        return 'IU';
      case 'Purdue University':
        return 'Purdue';
      case 'UIUC':
        return 'UIUC';
      default:
        return campus;
    }
  };

  // Load user's campus for display (with retry for new users)
  const loadUserCampus = useCallback(async (retryCount = 0): Promise<string | null> => {
    const MAX_RETRIES = 3;
    const RETRY_DELAY_MS = 1000;
    
    const userId = await getCurrentUserId();
    if (!userId) {
      console.log('🔍 No user ID found, cannot load campus');
      return null;
    }
    
    try {
      const { data: user, error } = await supabase
        .from('users')
        .select('campus')
        .eq('id', userId)
        .single();
      
      if (error) {
        console.error('❌ Error loading user campus:', error);
        // Retry for new users whose profile might not be created yet
        if (retryCount < MAX_RETRIES) {
          console.log(`🔄 Retrying campus load (attempt ${retryCount + 1}/${MAX_RETRIES})...`);
          await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS));
          return loadUserCampus(retryCount + 1);
        }
        return null;
      }
      
      if (user?.campus) {
        console.log(`✅ Loaded user campus: ${user.campus}`);
        setUserCampus(user.campus);
        return user.campus;
      } else {
        console.log('⚠️ User has no campus set');
        // Retry in case profile is being created
        if (retryCount < MAX_RETRIES) {
          console.log(`🔄 Campus not set, retrying (attempt ${retryCount + 1}/${MAX_RETRIES})...`);
          await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS));
          return loadUserCampus(retryCount + 1);
        }
        setUserCampus(null);
        return null;
      }
    } catch (err) {
      console.error('❌ Error fetching user campus:', err);
      return null;
    }
  }, []);

  useEffect(() => {
    const init = async () => {
      console.log('🏠 HomeScreen initializing...');
      const userId = await getCurrentUserId();
      setCurrentUserId(userId);
      console.log('🏠 Current user ID:', userId);
      
      // Load campus first, THEN load listings (so listings are filtered correctly)
      const campus = await loadUserCampus();
      console.log('🏠 Campus loaded for filtering:', campus);
      
      // Now load listings - they will be filtered by campus in listingService
      await loadListings();
      console.log('🏠 Listings loaded');
      
      // TODO: Load active order count
    };
    init();
  }, []);
  
  // Reload listings if userCampus changes (e.g., after new user signup)
  useEffect(() => {
    if (userCampus !== null && !loading) {
      console.log('🏠 Campus changed, reloading listings for:', userCampus);
      loadListings(selectedFilter, 0, false);
    }
  }, [userCampus]);

  // Scroll to top when tab is pressed (React Navigation built-in hook)
  useScrollToTop(flatListRef);

  // Filtered listings for display
  const displayListings = useMemo(() => {
    if (!searchQuery.trim()) return listings;
    
    const query = searchQuery.toLowerCase();
    return listings.filter(
      (item) =>
        item.title.toLowerCase().includes(query) ||
        item.description?.toLowerCase().includes(query)
    );
  }, [listings, searchQuery]);

  // Render sticky header with search and filters
  const renderStickyHeader = () => (
    <View style={[styles.stickyHeaderContainer, { backgroundColor: colors.background }]}>
      {/* Header with Logo and Search */}
      <View style={[styles.headerContainer, { backgroundColor: colors.backgroundSecondary }]}>
        {/* Top Row: Brand + Actions */}
        <View style={styles.headerTopRow}>
          <View style={styles.brandIconContainer}>
            <Image
              source={require('../../../assets/brand-icon.png')}
              style={styles.brandIcon}
              resizeMode="contain"
            />
          </View>
          
          <View style={styles.headerActions}>
            {/* Help Button */}
            <Pressable
              style={({ pressed }) => [
                styles.headerButton,
                { backgroundColor: colors.primaryMuted, opacity: pressed ? 0.7 : 1 },
              ]}
              onPress={handleHelpPress}
            >
              <Ionicons name="help-circle" size={18} color={colors.primary} />
            </Pressable>
            
            {/* Sell Now Button */}
            <Pressable
              style={({ pressed }) => [
                styles.sellButton,
                { backgroundColor: colors.primaryMuted, opacity: pressed ? 0.7 : 1 },
              ]}
              onPress={handleSellNow}
            >
              <Ionicons name="add-circle" size={18} color={colors.primary} />
              <Text style={[styles.sellButtonText, { color: colors.primary }]}>
                Sell now
              </Text>
            </Pressable>
          </View>
        </View>
        
        {/* Search Bar */}
        <SearchBarWithFilters
          value={searchQuery}
          onChangeText={setSearchQuery}
          onSubmit={handleSearch}
          onFilterPress={() => navigation.navigate('Search')}
          placeholder="Search listings..."
          showFilterButton={false}
          onFocusChange={setIsSearchFocused}
        />
      </View>

      {/* Filter Chips */}
      <FilterChips
        chips={HOME_FILTER_CHIPS}
        selectedId={selectedFilter}
        onSelect={handleFilterChange}
      />
    </View>
  );

  // Render content after sticky header
  const renderListHeader = () => (
    <View>
      {/* Active Order Banner */}
      {activeOrderCount > 0 && (
        <ActiveOrderBanner
          orderCount={activeOrderCount}
          onPress={handleActiveOrderPress}
        />
      )}
      
      {/* Active Offer Banner - shows when there are pending offers */}
      {(pendingReceivedCount > 0 || pendingSentCount > 0) && (
        <ActiveOfferBanner
          receivedCount={pendingReceivedCount}
          sentCount={pendingSentCount}
          onPress={handleActiveOfferPress}
        />
      )}
      
      {/* Section Header - Always visible with campus badge (matching iOS) */}
      <View style={styles.sectionHeader}>
        <View style={styles.sectionTitleRow}>
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            {selectedFilter === 'wanted' ? 'Wanted items' : selectedFilter === 'selling' ? 'For sale' : "Today's picks"}
          </Text>
          {filterTransitioning && (
            <ActivityIndicator size="small" color={colors.primary} style={styles.filterLoader} />
          )}
        </View>
        {/* Campus Badge - on same line as section title like iOS */}
        {userCampus && (
          <View style={styles.campusBadge}>
            <Text style={[styles.campusText, { color: colors.primary }]}>
              {getCampusAbbreviation(userCampus)}
            </Text>
            <Ionicons name="location" size={14} color={colors.primary} />
          </View>
        )}
      </View>
    </View>
  );

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

  // Loading footer for infinite scroll
  const renderFooter = () => {
    if (!loadingMore) return null;
    
    return (
      <View style={styles.footerLoader}>
        <ActivityIndicator size="small" color={colors.primary} />
      </View>
    );
  };

  // Empty state
  const renderEmptyState = () => (
    <View style={styles.emptyContainer}>
      <Ionicons
        name={selectedFilter === 'wanted' ? 'search' : 'basket-outline'}
        size={64}
        color={colors.textTertiary}
      />
      <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}>
        {selectedFilter === 'all'
          ? 'No listings yet'
          : selectedFilter === 'selling'
          ? 'No items for sale yet'
          : selectedFilter === 'wanted'
          ? 'No wanted posts yet'
          : 'No listings found'}
      </Text>
      <Text style={[styles.emptySubtitle, { color: colors.textSecondary }]}>
        {selectedFilter === 'all'
          ? 'Be the first to post something!'
          : selectedFilter === 'selling'
          ? 'Be the first to post something for sale!'
          : selectedFilter === 'wanted'
          ? 'Be the first to post what you\'re looking for!'
          : 'Try adjusting your filters'}
      </Text>
    </View>
  );

  // Loading state
  if (loading) {
    return (
      <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
        <View style={[styles.stickyHeaderContainer, { backgroundColor: colors.background }]}>
          {renderStickyHeader()}
        </View>
        <ListingGridSkeleton count={6} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      {/* Sticky Header (Logo, Search, Filters) */}
      <View style={[styles.stickyHeaderContainer, { backgroundColor: colors.background }]}>
        {renderStickyHeader()}
      </View>
      
      {/* Scrollable Content - OPTIMIZED FOR PERFORMANCE */}
      <FlatList
        ref={flatListRef}
        data={displayListings}
        renderItem={renderListingCard}
        keyExtractor={(item: any) => item._loopId || item.id}
        numColumns={2}
        ListHeaderComponent={renderListHeader()}
        ListEmptyComponent={renderEmptyState}
        ListFooterComponent={renderFooter}
        contentContainerStyle={styles.listContent}
        columnWrapperStyle={styles.columnWrapper}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            tintColor={colors.primary}
            colors={[colors.primary]}
          />
        }
        onEndReached={loadMore}
        onEndReachedThreshold={0.5}
        // PERFORMANCE OPTIMIZATIONS (tuned to prevent white space)
        removeClippedSubviews={Platform.OS === 'ios'}
        maxToRenderPerBatch={12}
        updateCellsBatchingPeriod={50}
        initialNumToRender={12}
        windowSize={10}
      />

      {/* Backdrop overlay when search is focused */}
      {isSearchFocused && (
        <TouchableWithoutFeedback onPress={handleDismissSearch}>
          <View style={styles.backdrop} />
        </TouchableWithoutFeedback>
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  stickyHeaderContainer: {
    // Container for sticky header (search bar + filter chips)
  },
  headerContainer: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.sm,
    paddingBottom: Spacing.md,
    borderBottomLeftRadius: BorderRadius.lg,
    borderBottomRightRadius: BorderRadius.lg,
    gap: Spacing.md,
  },
  headerTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  brandIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  brandIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    tintColor: undefined,
  },
  headerActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  headerButton: {
    width: 36,
    height: 36,
    borderRadius: BorderRadius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sellButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    gap: Spacing.xs,
  },
  sellButtonText: {
    ...Typography.subheadlineBold,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
  },
  sectionTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  sectionTitle: {
    ...Typography.title2,
  },
  filterLoader: {
    marginLeft: Spacing.xs,
  },
  campusBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  campusText: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  listContent: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Layout.tabBarHeight + Spacing.lg,
    paddingTop: 0, // Remove top padding since header is now inside the list
  },
  columnWrapper: {
    gap: CARD_GAP,
    marginBottom: CARD_GAP,
  },
  cardWrapper: {
    flex: 1,
  },
  cardLeft: {
    marginRight: CARD_GAP / 2,
  },
  cardRight: {
    marginLeft: CARD_GAP / 2,
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing['5xl'],
    gap: Spacing.md,
  },
  emptyTitle: {
    ...Typography.title3,
  },
  emptySubtitle: {
    ...Typography.body,
    textAlign: 'center',
    paddingHorizontal: Spacing['2xl'],
  },
  footerLoader: {
    paddingVertical: 20,
    alignItems: 'center',
  },
  backdrop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    zIndex: 999,
  },
});

export default HomeScreen;
