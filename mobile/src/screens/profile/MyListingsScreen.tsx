import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
  RefreshControl,
} from 'react-native';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Ionicons } from '@expo/vector-icons';
import { Listing } from '../../types';
import { getMyListings, updateListing, archiveListing } from '../../services/listingService';
import ListingCard from '../../components/ListingCard';
import LoadingSpinner from '../../components/LoadingSpinner';
import Colors from '../../utils/colors';

const MyListingsScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const [listings, setListings] = useState<Listing[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [filter, setFilter] = useState<'all' | 'active' | 'sold'>('all');

  useFocusEffect(
    useCallback(() => {
      loadListings();
    }, [])
  );

  const loadListings = async () => {
    try {
      const data = await getMyListings({ includeArchived: false, includeSold: true });
      setListings(data);
    } catch (error) {
      console.error('Error loading listings:', error);
      Alert.alert('Error', 'Failed to load your listings');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadListings();
  };

  const handleArchiveListing = (listingId: string) => {
    Alert.alert(
      'Archive Listing',
      'Are you sure you want to archive this listing?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Archive',
          style: 'destructive',
          onPress: async () => {
            try {
              await archiveListing(listingId);
              setListings(prev => prev.filter(l => l.id !== listingId));
              Alert.alert('Success', 'Listing archived');
            } catch (error) {
              Alert.alert('Error', 'Failed to archive listing');
            }
          },
        },
      ]
    );
  };

  const handleToggleSold = async (listing: Listing) => {
    try {
      await updateListing(listing.id, { is_sold: !listing.is_sold });
      setListings(prev =>
        prev.map(l => (l.id === listing.id ? { ...l, is_sold: !l.is_sold } : l))
      );
      Alert.alert('Success', listing.is_sold ? 'Marked as available' : 'Marked as sold');
    } catch (error) {
      Alert.alert('Error', 'Failed to update listing');
    }
  };

  const filteredListings = listings.filter(listing => {
    if (filter === 'active') return !listing.is_sold && !listing.archived;
    if (filter === 'sold') return listing.is_sold;
    return !listing.archived;
  });

  const activeCount = listings.filter(l => !l.is_sold && !l.archived).length;
  const soldCount = listings.filter(l => l.is_sold).length;

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading your listings..." />;
  }

  return (
    <View style={styles.container}>
      {/* Filter Tabs */}
      <View style={styles.filterContainer}>
        <TouchableOpacity
          style={[styles.filterTab, filter === 'all' && styles.filterTabActive]}
          onPress={() => setFilter('all')}
        >
          <Text style={[styles.filterText, filter === 'all' && styles.filterTextActive]}>
            All ({listings.length})
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.filterTab, filter === 'active' && styles.filterTabActive]}
          onPress={() => setFilter('active')}
        >
          <Text style={[styles.filterText, filter === 'active' && styles.filterTextActive]}>
            Active ({activeCount})
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.filterTab, filter === 'sold' && styles.filterTabActive]}
          onPress={() => setFilter('sold')}
        >
          <Text style={[styles.filterText, filter === 'sold' && styles.filterTextActive]}>
            Sold ({soldCount})
          </Text>
        </TouchableOpacity>
      </View>

      {/* Listings List */}
      <FlatList
        data={filteredListings}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={styles.listingContainer}>
            <ListingCard
              listing={item}
              onPress={() => navigation.navigate('Home', {
                screen: 'ListingDetail',
                params: { listingId: item.id }
              })}
            />
            {/* Action Buttons */}
            <View style={styles.actionsContainer}>
              <TouchableOpacity
                style={[styles.actionButton, styles.soldButton]}
                onPress={() => handleToggleSold(item)}
              >
                <Ionicons
                  name={item.is_sold ? 'checkmark-circle' : 'checkmark-circle-outline'}
                  size={18}
                  color={item.is_sold ? Colors.success : Colors.textSecondary}
                />
                <Text style={styles.actionText}>
                  {item.is_sold ? 'Mark Available' : 'Mark Sold'}
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.actionButton, styles.archiveButton]}
                onPress={() => handleArchiveListing(item.id)}
              >
                <Ionicons name="archive-outline" size={18} color={Colors.error} />
                <Text style={[styles.actionText, { color: Colors.error }]}>Archive</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor={Colors.primary}
          />
        }
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="grid-outline" size={64} color={Colors.textSecondary} />
            <Text style={styles.emptyTitle}>No listings yet</Text>
            <Text style={styles.emptySubtitle}>
              {filter === 'active'
                ? "You don't have any active listings"
                : filter === 'sold'
                ? "You haven't sold anything yet"
                : 'Start selling by creating your first listing'}
            </Text>
            {filter === 'all' && (
              <TouchableOpacity
                style={styles.createButton}
                onPress={() => navigation.navigate('Post')}
              >
                <Text style={styles.createButtonText}>Create Listing</Text>
              </TouchableOpacity>
            )}
          </View>
        }
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  filterContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: Colors.background,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  filterTab: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 12,
    marginHorizontal: 4,
    borderRadius: 8,
    alignItems: 'center',
    backgroundColor: Colors.surface,
  },
  filterTabActive: {
    backgroundColor: Colors.primary,
  },
  filterText: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textSecondary,
  },
  filterTextActive: {
    color: '#FFFFFF',
  },
  listContent: {
    padding: 16,
    flexGrow: 1,
  },
  listingContainer: {
    marginBottom: 16,
  },
  actionsContainer: {
    flexDirection: 'row',
    marginTop: 8,
    gap: 8,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    backgroundColor: Colors.surface,
    gap: 6,
  },
  soldButton: {
    borderWidth: 1,
    borderColor: Colors.border,
  },
  archiveButton: {
    borderWidth: 1,
    borderColor: Colors.error + '40',
  },
  actionText: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textSecondary,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 60,
    paddingHorizontal: 32,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginTop: 16,
    marginBottom: 8,
  },
  emptySubtitle: {
    fontSize: 14,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  createButton: {
    marginTop: 24,
    paddingVertical: 12,
    paddingHorizontal: 32,
    backgroundColor: Colors.primary,
    borderRadius: 8,
  },
  createButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});

export default MyListingsScreen;

