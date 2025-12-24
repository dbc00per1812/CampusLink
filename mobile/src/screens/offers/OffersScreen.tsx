// OffersScreen - List of sent and received offers
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { LoadingSpinner, EmptyState, UnifiedHeader } from '../../components';
import { supabase } from '../../config/supabase';
import { Offer } from '../../types';
import Colors from '../../utils/colors';

type Tab = 'received' | 'sent';

const OffersScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const [activeTab, setActiveTab] = useState<Tab>('received');
  const [receivedOffers, setReceivedOffers] = useState<Offer[]>([]);
  const [sentOffers, setSentOffers] = useState<Offer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  useEffect(() => {
    loadUserId();
  }, []);

  useFocusEffect(
    useCallback(() => {
      if (currentUserId) {
        loadOffers();
      }
    }, [currentUserId])
  );

  const loadUserId = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    setCurrentUserId(session?.user.id ?? null);
  };

  const loadOffers = async () => {
    if (!currentUserId) return;
    
    try {
      // Load received offers (where I'm the seller)
      const { data: received } = await supabase
        .from('offers')
        .select('*, listing:listings(*), buyer:users!buyer_id(*)')
        .eq('seller_id', currentUserId)
        .order('created_at', { ascending: false });
      
      // Load sent offers (where I'm the buyer)
      const { data: sent } = await supabase
        .from('offers')
        .select('*, listing:listings(*), seller:users!seller_id(*)')
        .eq('buyer_id', currentUserId)
        .order('created_at', { ascending: false });

      setReceivedOffers(received ?? []);
      setSentOffers(sent ?? []);
    } catch (error) {
      console.error('Error loading offers:', error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadOffers();
  };

  const currentOffers = activeTab === 'received' ? receivedOffers : sentOffers;

  const pendingReceived = receivedOffers.filter(o => o.status === 'pending').length;
  const pendingSent = sentOffers.filter(o => o.status === 'pending').length;

  const getStatusColor = (status: string): string => {
    switch (status) {
      case 'pending':
        return Colors.warning;
      case 'accepted':
        return Colors.success;
      case 'declined':
      case 'expired':
        return Colors.error;
      case 'countered':
        return Colors.primary;
      default:
        return Colors.textSecondary;
    }
  };

  const formatDate = (dateStr: string): string => {
    const date = new Date(dateStr);
    return date.toLocaleDateString(undefined, { 
      month: 'short', 
      day: 'numeric',
      year: 'numeric'
    });
  };

  const renderOffer = ({ item }: { item: Offer }) => {
    const otherUser = activeTab === 'received' ? item.buyer : item.seller;
    
    return (
      <TouchableOpacity
        style={styles.offerCard}
        onPress={() => navigation.navigate('OfferDetail', { offerId: item.id })}
      >
        {/* Listing Image */}
        <View style={styles.offerImageContainer}>
          {item.listing?.photo ? (
            <Image source={{ uri: item.listing.photo }} style={styles.offerImage} />
          ) : (
            <View style={styles.imagePlaceholder}>
              <Ionicons name="pricetag-outline" size={24} color={Colors.textTertiary} />
            </View>
          )}
        </View>

        {/* Offer Info */}
        <View style={styles.offerInfo}>
          <Text style={styles.listingTitle} numberOfLines={1}>
            {item.listing?.title || 'Unknown Item'}
          </Text>
          <Text style={styles.offerAmount}>
            ${item.offer_amount.toFixed(2)}
            {item.listing?.price && (
              <Text style={styles.originalPrice}> (was ${item.listing.price.toFixed(2)})</Text>
            )}
          </Text>
          <View style={styles.offerMeta}>
            <Text style={styles.userName}>
              {activeTab === 'received' ? 'From: ' : 'To: '}
              {otherUser?.name || 'Unknown'}
            </Text>
            <Text style={styles.offerDate}>{formatDate(item.created_at)}</Text>
          </View>
        </View>

        {/* Status Badge */}
        <View style={styles.statusContainer}>
          <View style={[
            styles.statusBadge,
            { backgroundColor: getStatusColor(item.status) + '20' }
          ]}>
            <Text style={[styles.statusText, { color: getStatusColor(item.status) }]}>
              {item.status.charAt(0).toUpperCase() + item.status.slice(1)}
            </Text>
          </View>
          <Ionicons name="chevron-forward" size={20} color={Colors.textTertiary} />
        </View>
      </TouchableOpacity>
    );
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading offers..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <UnifiedHeader title="My Offers" />

      {/* Tabs */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'received' && styles.tabActive]}
          onPress={() => setActiveTab('received')}
        >
          <Text style={[styles.tabText, activeTab === 'received' && styles.tabTextActive]}>
            Received
          </Text>
          {pendingReceived > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{pendingReceived}</Text>
            </View>
          )}
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'sent' && styles.tabActive]}
          onPress={() => setActiveTab('sent')}
        >
          <Text style={[styles.tabText, activeTab === 'sent' && styles.tabTextActive]}>
            Sent
          </Text>
          {pendingSent > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{pendingSent}</Text>
            </View>
          )}
        </TouchableOpacity>
      </View>

      {/* Offers List */}
      {currentOffers.length === 0 ? (
        <EmptyState
          icon="pricetag-outline"
          title={activeTab === 'received' ? 'No Offers Received' : 'No Offers Sent'}
          message={
            activeTab === 'received'
              ? 'When buyers make offers on your listings, they\'ll appear here'
              : 'When you make offers on listings, they\'ll appear here'
          }
        />
      ) : (
        <FlatList
          data={currentOffers}
          renderItem={renderOffer}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          refreshControl={
            <RefreshControl
              refreshing={isRefreshing}
              onRefresh={handleRefresh}
              tintColor={Colors.primary}
            />
          }
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  tabContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    marginBottom: 8,
    gap: 8,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    gap: 6,
  },
  tabActive: {
    backgroundColor: Colors.primary,
  },
  tabText: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.textSecondary,
  },
  tabTextActive: {
    color: Colors.textInverse,
  },
  badge: {
    minWidth: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: Colors.error,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  badgeText: {
    fontSize: 12,
    fontWeight: '700',
    color: Colors.textInverse,
  },
  listContent: {
    padding: 16,
    gap: 12,
  },
  offerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRadius: 12,
    padding: 12,
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  offerImageContainer: {
    width: 60,
    height: 60,
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: Colors.surfaceSecondary,
  },
  offerImage: {
    width: '100%',
    height: '100%',
  },
  imagePlaceholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  offerInfo: {
    flex: 1,
    marginLeft: 12,
  },
  listingTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  offerAmount: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.primary,
    marginBottom: 4,
  },
  originalPrice: {
    fontSize: 13,
    fontWeight: '400',
    color: Colors.textTertiary,
  },
  offerMeta: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  userName: {
    fontSize: 12,
    color: Colors.textSecondary,
  },
  offerDate: {
    fontSize: 12,
    color: Colors.textTertiary,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
  },
});

export default OffersScreen;

