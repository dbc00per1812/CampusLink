// PayoutRequestScreen - Request withdrawal
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { Button, LoadingSpinner, UnifiedHeader } from '../../components';
import { getWalletBalance, requestPayout } from '../../services/walletService';
import Colors from '../../utils/colors';

const PayoutRequestScreen: React.FC = () => {
  const navigation = useNavigation();
  const [availableBalance, setAvailableBalance] = useState(0);
  const [amount, setAmount] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    loadBalance();
  }, []);

  const loadBalance = async () => {
    try {
      const data = await getWalletBalance();
      setAvailableBalance(data.available);
    } catch (error) {
      console.error('Error loading balance:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleRequestPayout = async () => {
    const payoutAmount = parseFloat(amount);
    
    if (isNaN(payoutAmount) || payoutAmount < 1) {
      Alert.alert('Invalid Amount', 'Minimum payout amount is $1.00');
      return;
    }
    
    if (payoutAmount > availableBalance) {
      Alert.alert('Insufficient Balance', 'Payout amount exceeds available balance.');
      return;
    }

    setIsSubmitting(true);
    try {
      // Convert dollars to cents for the API
      await requestPayout(Math.round(payoutAmount * 100));
      Alert.alert(
        'Payout Requested',
        'Your payout request has been submitted. It will be processed within 2-3 business days.',
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to request payout');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleMaxAmount = () => {
    setAmount(availableBalance.toFixed(2));
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <UnifiedHeader title="Request Payout" />
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.flex}
      >
        <View style={styles.content}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.headerTitle}>Request Payout</Text>
          </View>

          {/* Balance Info */}
          <View style={styles.balanceCard}>
            <Text style={styles.balanceLabel}>Available Balance</Text>
            <Text style={styles.balanceAmount}>${availableBalance.toFixed(2)}</Text>
          </View>

          {/* Amount Input */}
          <View style={styles.inputSection}>
            <Text style={styles.inputLabel}>Payout Amount</Text>
            <View style={styles.inputContainer}>
              <Text style={styles.currencySymbol}>$</Text>
              <TextInput
                style={styles.amountInput}
                value={amount}
                onChangeText={setAmount}
                placeholder="0.00"
                placeholderTextColor={Colors.textTertiary}
                keyboardType="decimal-pad"
              />
              <Button
                title="Max"
                onPress={handleMaxAmount}
                variant="secondary"
                size="small"
                fullWidth={false}
              />
            </View>
            <Text style={styles.minNote}>Minimum payout: $1.00</Text>
          </View>

          {/* Info Box */}
          <View style={styles.infoBox}>
            <Ionicons name="information-circle" size={24} color={Colors.primary} />
            <Text style={styles.infoText}>
              Payouts are processed within 2-3 business days and deposited to your connected bank account.
            </Text>
          </View>

          {/* Submit Button */}
          <View style={styles.buttonContainer}>
            <Button
              title="Request Payout"
              onPress={handleRequestPayout}
              loading={isSubmitting}
              disabled={!amount || parseFloat(amount) < 1}
              icon="arrow-up-circle"
            />
          </View>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  flex: {
    flex: 1,
  },
  content: {
    flex: 1,
    padding: 16,
  },
  header: {
    marginBottom: 24,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  balanceCard: {
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
    marginBottom: 24,
  },
  balanceLabel: {
    fontSize: 14,
    color: Colors.textSecondary,
    marginBottom: 4,
  },
  balanceAmount: {
    fontSize: 32,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  inputSection: {
    marginBottom: 24,
  },
  inputLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 8,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    paddingHorizontal: 16,
    gap: 8,
  },
  currencySymbol: {
    fontSize: 24,
    fontWeight: '600',
    color: Colors.textSecondary,
  },
  amountInput: {
    flex: 1,
    fontSize: 24,
    fontWeight: '600',
    color: Colors.textPrimary,
    paddingVertical: 16,
  },
  minNote: {
    fontSize: 12,
    color: Colors.textTertiary,
    marginTop: 8,
  },
  infoBox: {
    flexDirection: 'row',
    backgroundColor: Colors.primary + '10',
    borderRadius: 12,
    padding: 16,
    gap: 12,
    alignItems: 'flex-start',
  },
  infoText: {
    flex: 1,
    fontSize: 14,
    color: Colors.textSecondary,
    lineHeight: 20,
  },
  buttonContainer: {
    marginTop: 'auto',
    paddingTop: 24,
  },
});

export default PayoutRequestScreen;

