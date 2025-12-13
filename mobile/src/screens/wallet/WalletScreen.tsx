// WalletScreen - Balance and transaction history
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  Alert,
  Linking,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Button, LoadingSpinner, EmptyState } from '../../components';
import { 
  getWalletBalance, 
  getTransactionHistory, 
  getPayoutHistory 
} from '../../services/walletService';
import { supabase } from '../../config/supabase';
import Colors from '../../utils/colors';

interface WalletBalance {
  available: number;
  pending: number;
  escrow: number;
}

interface WalletTx {
  id: string;
  type: 'sale' | 'purchase' | 'payout' | 'refund';
  amount: number;
  description: string;
  status: string;
  created_at: string;
}

const WalletScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const [balance, setBalance] = useState<WalletBalance>({ available: 0, pending: 0, escrow: 0 });
  const [transactions, setTransactions] = useState<WalletTx[]>([]);
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
      // Get user's Stripe account status
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        const { data: userData } = await supabase
          .from('users')
          .select('stripe_connect_id, stripe_payouts_enabled')
          .eq('id', session.user.id)
          .single();
        
        setHasStripeAccount(!!userData?.stripe_connect_id);
        setStripeAccountEnabled(userData?.stripe_payouts_enabled ?? false);
      }

      // Get wallet balance
      const walletData = await getWalletBalance();
      setBalance(walletData);

      // Get transaction history
      const txHistory = await getTransactionHistory();
      // Map to our simplified type
      setTransactions(txHistory.map((tx: any) => ({
        id: tx.id,
        type: tx.transaction_type || 'sale',
        amount: tx.amount_cents / 100,
        description: tx.description || 'Transaction',
        status: tx.status || 'completed',
        created_at: tx.created_at,
      })));
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
    try {
      // Call edge function to get Stripe Connect onboarding URL
      const { data, error } = await supabase.functions.invoke('create-connect-account-link', {
        body: { refreshUrl: 'campuslink://wallet', returnUrl: 'campuslink://wallet' }
      });

      if (error) throw error;

      if (data?.url) {
        Linking.openURL(data.url);
      }
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to start Stripe setup');
    }
  };

  const handleRequestPayout = () => {
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
    return date.toLocaleDateString(undefined, { 
      month: 'short', 
      day: 'numeric' 
    });
  };

  const getTransactionIcon = (type: string): keyof typeof Ionicons.glyphMap => {
    switch (type) {
      case 'sale':
        return 'arrow-down-circle';
      case 'purchase':
        return 'arrow-up-circle';
      case 'payout':
        return 'wallet-outline';
      case 'refund':
        return 'refresh-circle';
      default:
        return 'cash-outline';
    }
  };

  const getTransactionColor = (type: string): string => {
    switch (type) {
      case 'sale':
        return Colors.success;
      case 'purchase':
        return Colors.error;
      case 'payout':
        return Colors.primary;
      case 'refund':
        return Colors.warning;
      default:
        return Colors.textSecondary;
    }
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading wallet..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView 
        style={styles.scrollView}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor={Colors.primary}
          />
        }
      >
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>Wallet</Text>
        </View>

        {/* Balance Card */}
        <View style={styles.balanceCard}>
          <View style={styles.balanceHeader}>
            <Text style={styles.balanceLabel}>Available Balance</Text>
            <Ionicons name="wallet" size={24} color={Colors.primary} />
          </View>
          <Text style={styles.balanceAmount}>{formatCurrency(balance.available)}</Text>
          
          <View style={styles.balanceRow}>
            <View style={styles.balanceItem}>
              <Text style={styles.balanceItemLabel}>In Escrow</Text>
              <Text style={styles.balanceItemValue}>{formatCurrency(balance.escrow)}</Text>
            </View>
          </View>

          <View style={styles.totalBalanceFooter}>
            <Text style={styles.totalBalanceLabel}>Total Balance</Text>
            <Text style={styles.totalBalanceAmount}>
              {formatCurrency(balance.available + balance.escrow)}
            </Text>
          </View>
        </View>

        {/* Quick Action Buttons */}
        <View style={styles.actionButtonsRow}>
          {hasStripeAccount && stripeAccountEnabled ? (
            <>
              <TouchableOpacity 
                style={[styles.actionButton, styles.actionButtonPrimary]}
                onPress={handleRequestPayout}
                disabled={balance.available < 1}
              >
                <Ionicons name="arrow-up-circle" size={20} color="#fff" />
                <Text style={styles.actionButtonTextPrimary}>Request Payout</Text>
              </TouchableOpacity>
              <TouchableOpacity 
                style={[styles.actionButton, styles.actionButtonSecondary]}
                onPress={() => navigation.navigate('PayoutHistory')}
              >
                <Ionicons name="time-outline" size={20} color={Colors.primary} />
                <Text style={styles.actionButtonTextSecondary}>History</Text>
              </TouchableOpacity>
            </>
          ) : (
            <TouchableOpacity 
              style={[styles.actionButton, styles.actionButtonPrimary, { flex: 1 }]}
              onPress={handleSetupStripe}
            >
              <Ionicons name="link" size={20} color="#fff" />
              <Text style={styles.actionButtonTextPrimary}>Complete Payout Setup</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Stripe Setup Prompt - Compact version */}
        {!hasStripeAccount && (
          <View style={styles.setupBanner}>
            <Ionicons name="information-circle" size={20} color={Colors.primary} />
            <Text style={styles.setupBannerText}>
              Connect your bank account to receive payments
            </Text>
          </View>
        )}

        {hasStripeAccount && !stripeAccountEnabled && (
          <View style={styles.setupBanner}>
            <Ionicons name="time-outline" size={20} color={Colors.warning} />
            <Text style={styles.setupBannerText}>
              Your Stripe account is pending verification
            </Text>
          </View>
        )}

        {/* Transaction History */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Recent Transactions</Text>
            {transactions.length > 5 && (
              <TouchableOpacity onPress={() => navigation.navigate('OrdersList')}>
                <Text style={styles.seeAll}>See All</Text>
              </TouchableOpacity>
            )}
          </View>

          {transactions.length === 0 ? (
            <View style={styles.emptyTransactions}>
              <Ionicons name="receipt-outline" size={40} color={Colors.textTertiary} />
              <Text style={styles.emptyText}>No transactions yet</Text>
            </View>
          ) : (
            <View style={styles.transactionsList}>
              {transactions.slice(0, 5).map((tx: WalletTx) => (
                <View key={tx.id} style={styles.transactionItem}>
                  <View style={[
                    styles.transactionIcon,
                    { backgroundColor: getTransactionColor(tx.type) + '20' }
                  ]}>
                    <Ionicons 
                      name={getTransactionIcon(tx.type)} 
                      size={24} 
                      color={getTransactionColor(tx.type)} 
                    />
                  </View>
                  <View style={styles.transactionInfo}>
                    <Text style={styles.transactionDescription} numberOfLines={1}>
                      {tx.description}
                    </Text>
                    <Text style={styles.transactionDate}>{formatDate(tx.created_at)}</Text>
                  </View>
                  <Text style={[
                    styles.transactionAmount,
                    { color: tx.type === 'sale' || tx.type === 'refund' 
                      ? Colors.success 
                      : Colors.textPrimary 
                    }
                  ]}>
                    {tx.type === 'sale' || tx.type === 'refund' ? '+' : '-'}
                    {formatCurrency(Math.abs(tx.amount))}
                  </Text>
                </View>
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
    backgroundColor: Colors.background,
  },
  scrollView: {
    flex: 1,
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
  balanceCard: {
    margin: 16,
    padding: 20,
    backgroundColor: Colors.surface,
    borderRadius: 16,
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 8,
    elevation: 4,
  },
  balanceHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  balanceLabel: {
    fontSize: 14,
    color: Colors.textSecondary,
  },
  balanceAmount: {
    fontSize: 36,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginBottom: 16,
  },
  balanceRow: {
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    paddingTop: 12,
    paddingBottom: 12,
  },
  balanceItem: {
    flex: 1,
  },
  balanceItemLabel: {
    fontSize: 12,
    color: Colors.textTertiary,
    marginBottom: 4,
  },
  balanceItemValue: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.warning,
  },
  totalBalanceFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    backgroundColor: Colors.surfaceSecondary,
    marginHorizontal: -20,
    marginBottom: -20,
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderBottomLeftRadius: 16,
    borderBottomRightRadius: 16,
  },
  totalBalanceLabel: {
    fontSize: 12,
    color: Colors.textSecondary,
  },
  totalBalanceAmount: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  actionButtonsRow: {
    flexDirection: 'row',
    gap: 12,
    marginHorizontal: 16,
    marginBottom: 8,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderRadius: 12,
    gap: 8,
  },
  actionButtonPrimary: {
    backgroundColor: Colors.primary,
  },
  actionButtonSecondary: {
    backgroundColor: Colors.surface,
  },
  actionButtonTextPrimary: {
    fontSize: 15,
    fontWeight: '600',
    color: '#fff',
  },
  actionButtonTextSecondary: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.primary,
  },
  setupBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginHorizontal: 16,
    marginBottom: 8,
    padding: 12,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 8,
    borderLeftWidth: 3,
    borderLeftColor: Colors.primary,
  },
  setupBannerText: {
    flex: 1,
    fontSize: 13,
    color: Colors.textSecondary,
    lineHeight: 18,
  },
  section: {
    padding: 16,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  seeAll: {
    fontSize: 14,
    color: Colors.primary,
    fontWeight: '500',
  },
  emptyTransactions: {
    alignItems: 'center',
    paddingVertical: 32,
  },
  emptyText: {
    fontSize: 14,
    color: Colors.textTertiary,
    marginTop: 8,
  },
  transactionsList: {
    backgroundColor: Colors.surface,
    borderRadius: 12,
    overflow: 'hidden',
  },
  transactionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  transactionIcon: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  transactionInfo: {
    flex: 1,
    marginLeft: 12,
  },
  transactionDescription: {
    fontSize: 15,
    fontWeight: '500',
    color: Colors.textPrimary,
    marginBottom: 2,
  },
  transactionDate: {
    fontSize: 12,
    color: Colors.textTertiary,
  },
  transactionAmount: {
    fontSize: 16,
    fontWeight: '600',
  },
});

export default WalletScreen;
