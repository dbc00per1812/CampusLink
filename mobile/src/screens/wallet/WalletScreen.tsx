// WalletScreen - Modern balance and transaction history
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  RefreshControl,
  Alert,
  Linking,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { LoadingSpinner } from '../../components';
import { 
  getWalletBalance, 
  getTransactionHistory, 
} from '../../services/walletService';
import { supabase } from '../../config/supabase';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows, Layout } from '../../utils/spacing';
import { Order, OrderStatus } from '../../types/order';

interface WalletBalance {
  available: number;
  pending: number;
  pendingOnboarding: number; // Funds waiting for Stripe setup
}

interface OrderTransaction {
  id: string;
  type: 'sale' | 'purchase';
  amount: number;
  listingTitle: string;
  status: OrderStatus;
  created_at: string;
}

const WalletScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const colors = useColors();
  const [balance, setBalance] = useState<WalletBalance>({ available: 0, pending: 0, pendingOnboarding: 0 });
  const [transactions, setTransactions] = useState<OrderTransaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [hasStripeAccount, setHasStripeAccount] = useState(false);
  const [stripeAccountEnabled, setStripeAccountEnabled] = useState(false);

  useFocusEffect(
    useCallback(() => {
      loadWalletData();
    }, [])
  );

  const loadWalletData = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;

      const userId = session.user.id;

      // Get user data for Stripe account status
      const { data: userData } = await supabase
        .from('users')
        .select('stripe_connect_id, stripe_payouts_enabled')
        .eq('id', userId)
        .single();
      
      setHasStripeAccount(!!userData?.stripe_connect_id);
      // Don't overwrite enabled with false from a stale read (e.g. after "already set up" response)
      setStripeAccountEnabled(prev => (userData?.stripe_payouts_enabled === true ? true : prev));

      // Get wallet balance
      const walletData = await getWalletBalance();
      setBalance(walletData);

      // Fetch buyer and seller orders separately to avoid duplicates
      // (prevents issues when user is both buyer and seller on same order)
      const orderSelectFields = `
        id,
        buyer_id,
        seller_id,
        price_cents,
        buyer_price_cents,
        seller_price_cents,
        order_status,
        payment_status,
        created_at,
        listing:listings(title)
      `;

      const [buyerResult, sellerResult] = await Promise.all([
        supabase
          .from('orders')
          .select(orderSelectFields)
          .eq('buyer_id', userId)
          .neq('seller_id', userId) // Exclude if user is also seller
          .order('created_at', { ascending: false })
          .limit(10),
        supabase
          .from('orders')
          .select(orderSelectFields)
          .eq('seller_id', userId)
          .neq('buyer_id', userId) // Exclude if user is also buyer
          .order('created_at', { ascending: false })
          .limit(10),
      ]);

      if (buyerResult.error || sellerResult.error) {
        console.error('Error fetching orders:', buyerResult.error || sellerResult.error);
        setTransactions([]);
      } else {
        // Transform purchases (buyer orders)
        const purchases: OrderTransaction[] = (buyerResult.data || []).map((order: any) => ({
          id: order.id,
          type: 'purchase' as const,
          amount: (order.buyer_price_cents || order.price_cents) / 100,
          listingTitle: order.listing?.title || 'Unknown Item',
          status: order.order_status,
          created_at: order.created_at,
        }));

        // Transform sales (seller orders)
        const sales: OrderTransaction[] = (sellerResult.data || []).map((order: any) => ({
          id: order.id,
          type: 'sale' as const,
          amount: (order.seller_price_cents || order.price_cents) / 100,
          listingTitle: order.listing?.title || 'Unknown Item',
          status: order.order_status,
          created_at: order.created_at,
        }));

        // Merge, dedupe by ID (in case same order appears in both), sort by date, take top 10
        const allTransactions = [...purchases, ...sales];
        const uniqueTransactions = Array.from(
          new Map(allTransactions.map(tx => [tx.id, tx])).values()
        );
        const sortedTransactions = uniqueTransactions
          .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
          .slice(0, 10);

        setTransactions(sortedTransactions);
      }
    } catch (error) {
      console.error('Error loading wallet data:', error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadWalletData();
  };

  const handleSetupStripe = async () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    
    try {
      // Use HTTPS redirect URLs that Stripe accepts, then redirect to app deep link
      // This matches the Swift implementation
      const { data, error } = await supabase.functions.invoke('connect_onboarding', {
        body: { 
          return_url: 'https://stripe-redirect.netlify.app/stripe-return.html', 
          refresh_url: 'https://stripe-redirect.netlify.app/stripe-refresh.html' 
        }
      });

      if (error) throw error;

      if (data?.onboarding_url) {
        Linking.openURL(data.onboarding_url);
      } else if (data?.onboarding_complete) {
        // Onboarding is complete - update local state immediately so UI shows Request Payout
        // The edge function syncs the DB; refetch may still return stale false, so we set state first
        setHasStripeAccount(true);
        setStripeAccountEnabled(true);
        // Refresh balance/transactions; stripe status is already correct above
        loadWalletData();
        Alert.alert('Success', 'Your payout account is already set up!');
      }
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to start Stripe setup');
    }
  };

  const handleRequestPayout = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    
    if (balance.available < 1) {
      Alert.alert('Insufficient Balance', 'You need at least $1.00 to request a payout.');
      return;
    }
    navigation.navigate('PayoutRequest');
  };

  const formatCurrency = (amount: number): string => {
    return `$${amount.toFixed(2)}`;
  };

  const formatDate = (dateStr: string): string => {
    const date = new Date(dateStr);
    return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  };

  const getTransactionIcon = (status: OrderStatus): keyof typeof Ionicons.glyphMap => {
    switch (status) {
      case 'completed': return 'checkmark-circle';
      case 'placed': 
      case 'seller_confirmed':
      case 'in_progress': return 'time';
      case 'cancelled':
      case 'refunded': return 'close-circle';
      case 'disputed': return 'warning';
      default: return 'cash-outline';
    }
  };

  const getTransactionColor = (status: OrderStatus): string => {
    switch (status) {
      case 'completed': return colors.success; // green
      case 'placed':
      case 'seller_confirmed':
      case 'in_progress': return colors.primary; // blue
      case 'disputed': return colors.warning; // orange
      case 'cancelled':
      case 'refunded': return colors.error; // red
      default: return colors.textSecondary;
    }
  };

  const getOrderStatusText = (status: OrderStatus): string => {
    const statusMap: Record<OrderStatus, string> = {
      'placed': 'Placed',
      'seller_confirmed': 'Confirmed',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'disputed': 'Disputed',
      'cancelled': 'Cancelled',
      'refunded': 'Refunded',
    };
    return statusMap[status] || status;
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading wallet..." />;
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      <ScrollView 
        style={styles.scrollView}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor={colors.primary}
          />
        }
      >
        {/* Header */}
        <View style={styles.header}>
          <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>Wallet</Text>
        </View>

        {/* Balance Card */}
        <View style={[styles.balanceCard, Shadows.lg]}>
          <LinearGradient
            colors={[colors.primary, colors.primaryDark]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.balanceGradient}
          >
            <View style={styles.balanceHeader}>
              <Text style={styles.balanceLabel}>Available Balance</Text>
              <View style={styles.walletIconWrapper}>
                <Ionicons name="wallet" size={24} color="#FFFFFF" />
              </View>
            </View>
            <Text style={styles.balanceAmount}>{formatCurrency(balance.available)}</Text>
            
            <View style={styles.balanceStats}>
              <View style={styles.balanceStat}>
                <View style={styles.balanceStatIcon}>
                  <Ionicons name="time-outline" size={16} color="#FFFFFF" />
                </View>
                <View>
                  <Text style={styles.balanceStatLabel}>Pending</Text>
                  <Text style={styles.balanceStatValue}>{formatCurrency(balance.pending + balance.pendingOnboarding)}</Text>
                </View>
              </View>
              <View style={styles.balanceStatDivider} />
              <View style={styles.balanceStat}>
                <View style={styles.balanceStatIcon}>
                  <Ionicons name="calculator-outline" size={16} color="#FFFFFF" />
                </View>
                <View>
                  <Text style={styles.balanceStatLabel}>Total</Text>
                  <Text style={styles.balanceStatValue}>
                    {formatCurrency(balance.available + balance.pending + balance.pendingOnboarding)}
                  </Text>
                </View>
              </View>
            </View>
          </LinearGradient>
        </View>

        {/* Quick Actions */}
        <View style={styles.actionsRow}>
          {hasStripeAccount && stripeAccountEnabled ? (
            <>
              <Pressable
                style={({ pressed }) => [
                  styles.actionButton,
                  { backgroundColor: colors.success, opacity: pressed ? 0.9 : 1 },
                  Shadows.sm,
                ]}
                onPress={handleRequestPayout}
                disabled={balance.available < 1}
              >
                <Ionicons name="arrow-up-circle" size={22} color="#FFFFFF" />
                <Text style={styles.actionButtonTextLight}>Request Payout</Text>
              </Pressable>
              <Pressable
                style={({ pressed }) => [
                  styles.actionButton,
                  { backgroundColor: colors.surface, opacity: pressed ? 0.9 : 1 },
                  Shadows.sm,
                ]}
                onPress={() => navigation.navigate('PayoutHistory')}
              >
                <Ionicons name="time-outline" size={22} color={colors.primary} />
                <Text style={[styles.actionButtonText, { color: colors.primary }]}>History</Text>
              </Pressable>
            </>
          ) : (
            <Pressable
              style={({ pressed }) => [
                styles.actionButton,
                styles.actionButtonFull,
                { backgroundColor: colors.primary, opacity: pressed ? 0.9 : 1 },
                Shadows.sm,
              ]}
              onPress={handleSetupStripe}
            >
              <Ionicons name="link" size={22} color="#FFFFFF" />
              <Text style={styles.actionButtonTextLight}>Complete Payout Setup</Text>
            </Pressable>
          )}
        </View>

        {/* Pending Onboarding Banner - Funds waiting for Stripe setup */}
        {balance.pendingOnboarding > 0 && !stripeAccountEnabled && (
          <View style={[styles.setupBanner, { backgroundColor: colors.warningLight, borderColor: colors.warning }]}>
            <Ionicons name="cash" size={22} color={colors.warning} />
            <Text style={[styles.setupBannerText, { color: colors.textSecondary }]}>
              You have {formatCurrency(balance.pendingOnboarding)} waiting! Complete payout setup to receive your earnings. Funds may take up to 7 days to become available after setup.
            </Text>
          </View>
        )}

        {/* Pending Balance Banner - Funds clearing through Stripe */}
        {balance.pending > 0 && (
          <View style={[styles.setupBanner, { backgroundColor: colors.successLight, borderColor: colors.success }]}>
            <Ionicons name="time" size={22} color={colors.success} />
            <Text style={[styles.setupBannerText, { color: colors.textSecondary }]}>
              {formatCurrency(balance.pending)} is on the way! Funds typically become available in 2-7 business days.
            </Text>
          </View>
        )}

        {/* Setup Banner */}
        {!hasStripeAccount && (
          <View style={[styles.setupBanner, { backgroundColor: colors.infoLight, borderColor: colors.primary }]}>
            <Ionicons name="information-circle" size={22} color={colors.primary} />
            <Text style={[styles.setupBannerText, { color: colors.textSecondary }]}>
              Connect your bank account to receive payments from sales
            </Text>
          </View>
        )}

        {hasStripeAccount && !stripeAccountEnabled && (
          <View style={[styles.setupBanner, { backgroundColor: colors.warningLight, borderColor: colors.warning }]}>
            <Ionicons name="time-outline" size={22} color={colors.warning} />
            <Text style={[styles.setupBannerText, { color: colors.textSecondary }]}>
              Your Stripe account is pending verification
            </Text>
          </View>
        )}

        {/* Transaction History */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Recent Transactions
            </Text>
            {transactions.length > 5 && (
              <Pressable
                onPress={() => navigation.navigate('OrdersList')}
                style={({ pressed }) => [{ opacity: pressed ? 0.5 : 1 }]}
              >
                <Text style={[styles.seeAll, { color: colors.primary }]}>See All</Text>
              </Pressable>
            )}
          </View>

          {transactions.length === 0 ? (
            <View style={[styles.emptyTransactions, { backgroundColor: colors.surfaceSecondary }]}>
              <Ionicons name="receipt-outline" size={48} color={colors.textTertiary} />
              <Text style={[styles.emptyText, { color: colors.textTertiary }]}>
                No transactions yet
              </Text>
              <Text style={[styles.emptySubtext, { color: colors.textTertiary }]}>
                Your transaction history will appear here
              </Text>
            </View>
          ) : (
            <View style={[styles.transactionsList, { backgroundColor: colors.surface }, Shadows.sm]}>
              {transactions.slice(0, 5).map((tx: OrderTransaction, index: number) => (
                <Pressable
                  key={tx.id}
                  style={({ pressed }) => [
                    styles.transactionItem,
                    index < Math.min(transactions.length, 5) - 1 && {
                      borderBottomWidth: 1,
                      borderBottomColor: colors.border,
                    },
                    { opacity: pressed ? 0.6 : 1 },
                  ]}
                  onPress={() => {
                    if (Platform.OS !== 'web') {
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                    }
                    navigation.navigate('OrderDetail', { orderId: tx.id });
                  }}
                >
                  <View
                    style={[
                      styles.transactionIcon,
                      { backgroundColor: `${getTransactionColor(tx.status)}20` },
                    ]}
                  >
                    <Ionicons 
                      name={getTransactionIcon(tx.status)} 
                      size={24} 
                      color={getTransactionColor(tx.status)} 
                    />
                  </View>
                  <View style={styles.transactionInfo}>
                    <Text
                      style={[styles.transactionDescription, { color: colors.textPrimary }]}
                      numberOfLines={1}
                    >
                      {tx.listingTitle}
                    </Text>
                    <Text style={[styles.transactionDate, { color: colors.textTertiary }]}>
                      {getOrderStatusText(tx.status)} • {formatDate(tx.created_at)}
                    </Text>
                  </View>
                  <Text
                    style={[
                      styles.transactionAmount,
                      {
                        color: tx.type === 'sale'
                          ? colors.success
                          : colors.textPrimary,
                      },
                    ]}
                  >
                    {tx.type === 'sale' ? '+' : ''}
                    {formatCurrency(tx.amount)}
                  </Text>
                  <Ionicons 
                    name="chevron-forward" 
                    size={20} 
                    color={colors.textTertiary}
                    style={styles.transactionChevron}
                  />
                </Pressable>
              ))}
            </View>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  header: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  headerTitle: {
    ...Typography.largeTitle,
  },
  balanceCard: {
    marginHorizontal: Spacing.lg,
    borderRadius: BorderRadius.xl,
    overflow: 'hidden',
  },
  balanceGradient: {
    padding: Spacing.xl,
  },
  balanceHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  balanceLabel: {
    ...Typography.subheadline,
    color: 'rgba(255, 255, 255, 0.8)',
  },
  walletIconWrapper: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  balanceAmount: {
    fontSize: 42,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: Spacing.lg,
  },
  balanceStats: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    borderRadius: BorderRadius.lg,
    padding: Spacing.md,
  },
  balanceStat: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  balanceStatIcon: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  balanceStatLabel: {
    ...Typography.caption2,
    color: 'rgba(255, 255, 255, 0.7)',
  },
  balanceStatValue: {
    ...Typography.subheadlineBold,
    color: '#FFFFFF',
  },
  balanceStatDivider: {
    width: 1,
    height: 32,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    marginHorizontal: Spacing.md,
  },
  actionsRow: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginHorizontal: Spacing.lg,
    marginTop: Spacing.lg,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    borderRadius: BorderRadius.lg,
    gap: Spacing.sm,
  },
  actionButtonFull: {
    flex: 1,
  },
  actionButtonTextLight: {
    ...Typography.button,
    color: '#FFFFFF',
  },
  actionButtonText: {
    ...Typography.button,
  },
  setupBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    marginHorizontal: Spacing.lg,
    marginTop: Spacing.md,
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
    borderLeftWidth: 4,
  },
  setupBannerText: {
    flex: 1,
    ...Typography.footnote,
    lineHeight: 18,
  },
  section: {
    padding: Spacing.lg,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  sectionTitle: {
    ...Typography.title3,
  },
  seeAll: {
    ...Typography.subheadlineBold,
  },
  emptyTransactions: {
    alignItems: 'center',
    paddingVertical: Spacing['3xl'],
    borderRadius: BorderRadius.lg,
    gap: Spacing.sm,
  },
  emptyText: {
    ...Typography.headline,
  },
  emptySubtext: {
    ...Typography.footnote,
  },
  transactionsList: {
    borderRadius: BorderRadius.lg,
    overflow: 'hidden',
  },
  transactionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
  },
  transactionIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  transactionInfo: {
    flex: 1,
    marginLeft: Spacing.md,
  },
  transactionDescription: {
    ...Typography.subheadlineBold,
    marginBottom: 2,
  },
  transactionDate: {
    ...Typography.caption1,
  },
  transactionAmount: {
    ...Typography.headline,
  },
  transactionChevron: {
    marginLeft: Spacing.xs,
  },
});

export default WalletScreen;
