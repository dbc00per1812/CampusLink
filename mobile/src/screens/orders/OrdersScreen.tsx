// OrdersScreen - List of purchases and sales with tabs
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
import { OrderStatusBadge, LoadingSpinner, EmptyState } from '../../components';
import { getMyOrders } from '../../services/orderService';
import { supabase } from '../../config/supabase';
import { Order, OrderStatus } from '../../types';
import Colors from '../../utils/colors';

type Tab = 'purchases' | 'sales';

const OrdersScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const [activeTab, setActiveTab] = useState<Tab>('purchases');
  const [purchases, setPurchases] = useState<Order[]>([]);
  const [sales, setSales] = useState<Order[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  useEffect(() => {
    loadUserId();
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadOrders();
    }, [])
  );

  const loadUserId = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    setCurrentUserId(session?.user.id ?? null);
  };

  const loadOrders = async () => {
    try {
      const data = await getMyOrders();
      
      const { data: { session } } = await supabase.auth.getSession();
      const userId = session?.user.id;
      
      if (userId) {
        setPurchases(data.filter(o => o.buyer_id === userId));
        setSales(data.filter(o => o.seller_id === userId));
      }
    } catch (error) {
      console.error('Error loading orders:', error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadOrders();
  };

  const currentOrders = activeTab === 'purchases' ? purchases : sales;

  // Count orders requiring action
  const purchasesNeedingAction = purchases.filter(
    o => o.status === 'seller_confirmed'
  ).length;
  const salesNeedingAction = sales.filter(
    o => o.status === 'placed' || o.status === 'in_progress'
  ).length;

  const formatDate = (dateStr: string): string => {
    const date = new Date(dateStr);
    return date.toLocaleDateString(undefined, { 
      month: 'short', 
      day: 'numeric',
      year: 'numeric'
    });
  };

  const renderOrder = ({ item }: { item: Order }) => (
    <TouchableOpacity
      style={styles.orderCard}
      onPress={() => navigation.navigate('OrderDetail', { orderId: item.id })}
    >
      {/* Listing Image */}
      <View style={styles.orderImageContainer}>
        {item.listing?.photo ? (
          <Image source={{ uri: item.listing.photo }} style={styles.orderImage} />
        ) : (
          <View style={styles.imagePlaceholder}>
            <Ionicons name="cube-outline" size={24} color={Colors.textTertiary} />
          </View>
        )}
      </View>

      {/* Order Info */}
      <View style={styles.orderInfo}>
        <Text style={styles.orderTitle} numberOfLines={1}>
          {item.listing?.title || 'Unknown Item'}
        </Text>
        <Text style={styles.orderPrice}>${((item.price_cents || 0) / 100).toFixed(2)}</Text>
        <Text style={styles.orderDate}>{formatDate(item.created_at)}</Text>
      </View>

      {/* Status Badge */}
      <View style={styles.statusContainer}>
        <OrderStatusBadge status={item.status} size="small" />
        <Ionicons name="chevron-forward" size={20} color={Colors.textTertiary} />
      </View>
    </TouchableOpacity>
  );

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading orders..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>My Orders</Text>
      </View>

      {/* Tabs */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'purchases' && styles.tabActive]}
          onPress={() => setActiveTab('purchases')}
        >
          <Text style={[styles.tabText, activeTab === 'purchases' && styles.tabTextActive]}>
            Purchases
          </Text>
          {purchasesNeedingAction > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{purchasesNeedingAction}</Text>
            </View>
          )}
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'sales' && styles.tabActive]}
          onPress={() => setActiveTab('sales')}
        >
          <Text style={[styles.tabText, activeTab === 'sales' && styles.tabTextActive]}>
            Sales
          </Text>
          {salesNeedingAction > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{salesNeedingAction}</Text>
            </View>
          )}
        </TouchableOpacity>
      </View>

      {/* Orders List */}
      {currentOrders.length === 0 ? (
        <EmptyState
          icon={activeTab === 'purchases' ? 'cart-outline' : 'storefront-outline'}
          title={activeTab === 'purchases' ? 'No Purchases Yet' : 'No Sales Yet'}
          message={
            activeTab === 'purchases'
              ? 'When you buy items, they\'ll appear here'
              : 'When you sell items, they\'ll appear here'
          }
        />
      ) : (
        <FlatList
          data={currentOrders}
          renderItem={renderOrder}
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
  orderCard: {
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
  orderImageContainer: {
    width: 60,
    height: 60,
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: Colors.surfaceSecondary,
  },
  orderImage: {
    width: '100%',
    height: '100%',
  },
  imagePlaceholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  orderInfo: {
    flex: 1,
    marginLeft: 12,
  },
  orderTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  orderPrice: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.primary,
    marginBottom: 2,
  },
  orderDate: {
    fontSize: 12,
    color: Colors.textTertiary,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
});

export default OrdersScreen;
