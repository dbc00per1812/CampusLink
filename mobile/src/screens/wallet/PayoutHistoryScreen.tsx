// PayoutHistoryScreen - View past payouts
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  RefreshControl,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LoadingSpinner, UnifiedHeader } from '../../components';
import { getPayoutHistory } from '../../services/walletService';
import Colors from '../../utils/colors';

interface Payout {
  id: string;
  amount?: number;
  amount_cents?: number;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  created_at: string;
  completed_at?: string;
}

const PayoutHistoryScreen: React.FC = () => {
  const [payouts, setPayouts] = useState<Payout[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    loadPayouts();
  }, []);

  const loadPayouts = async () => {
    try {
      const data = await getPayoutHistory();
      // Map the data to ensure proper format
      const mappedPayouts = (data || []).map((payout: any) => ({
        id: payout.id,
        amount: payout.amount_cents ? payout.amount_cents / 100 : (payout.amount || 0),
        status: payout.status || 'pending',
        created_at: payout.created_at,
        completed_at: payout.completed_at,
      }));
      setPayouts(mappedPayouts);
    } catch (error) {
      console.error('Error loading payout history:', error);
      setPayouts([]);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadPayouts();
  };

  const formatCurrency = (amount?: number): string => {
    if (amount === undefined || amount === null) {
      return '$0.00';
    }
    return `$${amount.toFixed(2)}`;
  };

  const formatDate = (dateStr: string): string => {
    const date = new Date(dateStr);
    return date.toLocaleDateString(undefined, { 
      month: 'short', 
      day: 'numeric',
      year: 'numeric'
    });
  };

  const getStatusColor = (status: string): string => {
    switch (status) {
      case 'completed':
        return Colors.success;
      case 'processing':
      case 'pending':
        return Colors.warning;
      case 'failed':
        return Colors.error;
      default:
        return Colors.textSecondary;
    }
  };

  const getStatusIcon = (status: string): keyof typeof Ionicons.glyphMap => {
    switch (status) {
      case 'completed':
        return 'checkmark-circle';
      case 'processing':
        return 'time';
      case 'pending':
        return 'hourglass-outline';
      case 'failed':
        return 'close-circle';
      default:
        return 'help-circle';
    }
  };

  const getStatusText = (status: string): string => {
    return status.charAt(0).toUpperCase() + status.slice(1);
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading payouts..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <UnifiedHeader title="Payout History" />

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
        {payouts.length === 0 ? (
          <View style={styles.emptyState}>
            <Ionicons name="wallet-outline" size={64} color={Colors.textTertiary} />
            <Text style={styles.emptyTitle}>No Payouts Yet</Text>
            <Text style={styles.emptyText}>
              Your payout history will appear here once you request your first payout.
            </Text>
          </View>
        ) : (
          <View style={styles.payoutsList}>
            {payouts.map((payout) => (
              <View key={payout.id} style={styles.payoutItem}>
                <View style={[
                  styles.statusIcon,
                  { backgroundColor: getStatusColor(payout.status) + '20' }
                ]}>
                  <Ionicons
                    name={getStatusIcon(payout.status)}
                    size={24}
                    color={getStatusColor(payout.status)}
                  />
                </View>
                
                <View style={styles.payoutInfo}>
                  <Text style={styles.payoutAmount}>
                    {formatCurrency(payout.amount)}
                  </Text>
                  <Text style={styles.payoutDate}>
                    Requested {formatDate(payout.created_at)}
                  </Text>
                  {payout.completed_at && (
                    <Text style={styles.payoutCompletedDate}>
                      Completed {formatDate(payout.completed_at)}
                    </Text>
                  )}
                </View>

                <View style={[
                  styles.statusBadge,
                  { backgroundColor: getStatusColor(payout.status) + '20' }
                ]}>
                  <Text style={[
                    styles.statusText,
                    { color: getStatusColor(payout.status) }
                  ]}>
                    {getStatusText(payout.status)}
                  </Text>
                </View>
              </View>
            ))}
          </View>
        )}
      </ScrollView>
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
  scrollView: {
    flex: 1,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
    paddingHorizontal: 32,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginTop: 16,
    marginBottom: 8,
  },
  emptyText: {
    fontSize: 14,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  payoutsList: {
    padding: 16,
    gap: 12,
  },
  payoutItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRadius: 12,
    padding: 16,
    gap: 12,
  },
  statusIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  payoutInfo: {
    flex: 1,
  },
  payoutAmount: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  payoutDate: {
    fontSize: 13,
    color: Colors.textSecondary,
  },
  payoutCompletedDate: {
    fontSize: 12,
    color: Colors.success,
    marginTop: 2,
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
  },
});

export default PayoutHistoryScreen;

