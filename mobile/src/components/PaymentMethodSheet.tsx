// Payment Method Selection Sheet - Card/Apple Pay/Google Pay only (wallet removed for payments)
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  Pressable,
  ScrollView,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius, Shadows } from '../utils/spacing';
import { ListingWithUser } from '../types';

type PaymentMethod = 'card' | 'apple_pay' | 'google_pay';

interface PaymentMethodSheetProps {
  visible: boolean;
  listing: ListingWithUser;
  onClose: () => void;
  onPaymentMethodSelected: (method: PaymentMethod) => void;
  // Server-calculated fees passed from parent (from create_payment_intent response)
  // These take precedence over client-side calculations for accuracy
  serverBuyerPriceCents?: number;
  serverSellerPriceCents?: number;
  serverStripeFeeCents?: number;
}

const PaymentMethodSheet: React.FC<PaymentMethodSheetProps> = ({
  visible,
  listing,
  onClose,
  onPaymentMethodSelected,
  serverBuyerPriceCents,
  serverSellerPriceCents,
  serverStripeFeeCents,
}) => {
  const colors = useColors();
  const [selectedMethod, setSelectedMethod] = useState<PaymentMethod | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  // Use server-calculated fees when available, fallback to client-side estimate
  // Server fees are accurate; client-side is only for initial display before payment intent created
  const sellerPriceCents = serverSellerPriceCents ?? Math.round((listing.price ?? 0) * 100);
  const stripeFeeCents = serverStripeFeeCents ?? Math.round(sellerPriceCents * 0.029 + 30);
  const buyerPriceCents = serverBuyerPriceCents ?? (sellerPriceCents + stripeFeeCents);

  const formatCurrency = (cents: number): string => {
    return `$${(cents / 100).toFixed(2)}`;
  };

  const handleSelectMethod = (method: PaymentMethod) => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    setSelectedMethod(method);
  };

  const handleContinue = () => {
    if (!selectedMethod) return;

    setIsProcessing(true);
    
    // Small delay for UX
    setTimeout(() => {
      setIsProcessing(false);
      
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }
      
      onPaymentMethodSelected(selectedMethod);
    }, 300);
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
        {/* Header */}
        <View style={[styles.header, { borderBottomColor: colors.border }]}>
          <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>
            Choose Payment Method
          </Text>
          <Text style={[styles.headerSubtitle, { color: colors.textSecondary }]}>
            Select how you'd like to pay for this item
          </Text>
        </View>

        <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
          {/* Price Breakdown */}
          <View style={[styles.priceCard, { backgroundColor: colors.primaryMuted }]}>
            <View style={styles.priceRow}>
              <Text style={[styles.priceLabel, { color: colors.textSecondary }]}>
                Offer Amount
              </Text>
              <Text style={[styles.priceValue, { color: colors.textPrimary }]}>
                {formatCurrency(sellerPriceCents)}
              </Text>
            </View>

            <View style={styles.priceRow}>
              <Text style={[styles.priceLabel, { color: colors.textSecondary }]}>
                Stripe Processing Fee
              </Text>
              <Text style={[styles.priceValue, { color: colors.warning }]}>
                {formatCurrency(stripeFeeCents)}
              </Text>
            </View>

            <View style={[styles.divider, { backgroundColor: colors.border }]} />

            <View style={styles.priceRow}>
              <Text style={[styles.totalLabel, { color: colors.textPrimary }]}>
                Total:
              </Text>
              <Text style={[styles.totalValue, { color: colors.primary }]}>
                {formatCurrency(buyerPriceCents)}
              </Text>
            </View>

            <View style={styles.infoNote}>
              <Ionicons name="information-circle" size={14} color={colors.info} />
              <Text style={[styles.infoText, { color: colors.textSecondary }]}>
                Processing fee covers secure payment handling
              </Text>
            </View>
          </View>

          {/* Payment Methods */}
          <View style={styles.methodsContainer}>
            {/* Apple Pay Option (iOS only) */}
            {Platform.OS === 'ios' && (
              <PaymentMethodOption
                title="Apple Pay"
                subtitle="Fast and secure with Touch ID or Face ID"
                icon="logo-apple"
                iconColor="#000000"
                isEnabled={true}
                isSelected={selectedMethod === 'apple_pay'}
                onPress={() => handleSelectMethod('apple_pay')}
                colors={colors}
              />
            )}

            {/* Google Pay Option (Android only) */}
            {Platform.OS === 'android' && (
              <PaymentMethodOption
                title="Google Pay"
                subtitle="Fast and secure with Google Pay"
                icon="logo-google"
                iconColor="#4285F4"
                isEnabled={true}
                isSelected={selectedMethod === 'google_pay'}
                onPress={() => handleSelectMethod('google_pay')}
                colors={colors}
              />
            )}

            {/* Card Payment Option */}
            <PaymentMethodOption
              title="Credit/Debit Card"
              subtitle="All major credit and debit cards accepted"
              icon="card"
              iconColor={colors.info}
              isEnabled={true}
              isSelected={selectedMethod === 'card'}
              onPress={() => handleSelectMethod('card')}
              colors={colors}
            />

            {/* Escrow Protection Info */}
            <View style={[styles.escrowCard, { backgroundColor: colors.successLight }]}>
              <View style={styles.escrowHeader}>
                <Ionicons name="shield-checkmark" size={24} color={colors.success} />
                <Text style={[styles.escrowTitle, { color: colors.textPrimary }]}>
                  Escrow Protection
                </Text>
              </View>

              <Text style={[styles.escrowDescription, { color: colors.textSecondary }]}>
                Your payment is held securely until you confirm receipt. This protects both buyers and sellers.
              </Text>

              <View style={styles.escrowFeatures}>
                <EscrowFeature
                  icon="time-outline"
                  title="Secure Holding"
                  description="Funds held until delivery"
                  colors={colors}
                />
                <EscrowFeature
                  icon="shield-checkmark-outline"
                  title="Buyer Protection"
                  description="Get refund if item not as described"
                  colors={colors}
                />
                <EscrowFeature
                  icon="swap-horizontal-outline"
                  title="Seller Protection"
                  description="Payment guaranteed on delivery"
                  colors={colors}
                />
              </View>
            </View>
          </View>
        </ScrollView>

        {/* Bottom Actions */}
        <View style={[styles.bottomActions, { backgroundColor: colors.background, borderTopColor: colors.border }]}>
          <Pressable
            style={({ pressed }) => [
              styles.continueButton,
              {
                backgroundColor: selectedMethod && !isProcessing ? colors.primary : colors.border,
                opacity: pressed ? 0.8 : 1,
              },
            ]}
            onPress={handleContinue}
            disabled={!selectedMethod || isProcessing}
          >
            {isProcessing ? (
              <ActivityIndicator color={colors.textInverse} />
            ) : (
              <Text style={[styles.continueButtonText, { color: colors.textInverse }]}>
                Continue with {
                  selectedMethod === 'apple_pay' ? 'Apple Pay' : 
                  selectedMethod === 'google_pay' ? 'Google Pay' :
                  selectedMethod === 'card' ? 'Card' : 
                  'Payment Method'
                }
              </Text>
            )}
          </Pressable>

          <Pressable
            style={({ pressed }) => [styles.cancelButton, { opacity: pressed ? 0.5 : 1 }]}
            onPress={onClose}
          >
            <Text style={[styles.cancelButtonText, { color: colors.textSecondary }]}>
              Cancel
            </Text>
          </Pressable>
        </View>
      </SafeAreaView>
    </Modal>
  );
};

// Payment Method Option Component
interface PaymentMethodOptionProps {
  title: string;
  subtitle: string;
  icon: string;
  iconColor: string;
  isEnabled: boolean;
  isSelected: boolean;
  onPress: () => void;
  colors: any;
}

const PaymentMethodOption: React.FC<PaymentMethodOptionProps> = ({
  title,
  subtitle,
  icon,
  iconColor,
  isEnabled,
  isSelected,
  onPress,
  colors,
}) => {
  return (
    <Pressable
      style={({ pressed }) => [
        styles.methodOption,
        {
          backgroundColor: isSelected ? colors.primaryMuted : colors.surfaceSecondary,
          borderColor: isSelected ? colors.primary : 'transparent',
          opacity: !isEnabled ? 0.5 : pressed ? 0.8 : 1,
        },
      ]}
      onPress={onPress}
      disabled={!isEnabled}
    >
      <Ionicons name={icon as any} size={28} color={iconColor} />
      
      <View style={styles.methodInfo}>
        <Text style={[styles.methodTitle, { color: colors.textPrimary }]}>
          {title}
        </Text>
        <Text style={[styles.methodSubtitle, { color: colors.textSecondary }]}>
          {subtitle}
        </Text>
      </View>

      {isSelected ? (
        <Ionicons name="checkmark-circle" size={28} color={colors.primary} />
      ) : (
        <Ionicons name="ellipse-outline" size={28} color={colors.textTertiary} />
      )}
    </Pressable>
  );
};

// Escrow Feature Component
interface EscrowFeatureProps {
  icon: string;
  title: string;
  description: string;
  colors: any;
}

const EscrowFeature: React.FC<EscrowFeatureProps> = ({ icon, title, description, colors }) => {
  return (
    <View style={styles.escrowFeature}>
      <Ionicons name={icon as any} size={24} color={colors.success} />
      <Text style={[styles.featureTitle, { color: colors.textPrimary }]}>
        {title}
      </Text>
      <Text style={[styles.featureDescription, { color: colors.textSecondary }]}>
        {description}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.lg,
    borderBottomWidth: 1,
    alignItems: 'center',
  },
  headerTitle: {
    ...Typography.title2,
    marginBottom: Spacing.xs,
  },
  headerSubtitle: {
    ...Typography.subheadline,
    textAlign: 'center',
  },
  scrollView: {
    flex: 1,
  },
  priceCard: {
    margin: Spacing.lg,
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
  },
  priceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  priceLabel: {
    ...Typography.subheadline,
  },
  priceValue: {
    ...Typography.subheadline,
    fontWeight: '600',
  },
  divider: {
    height: 1,
    marginVertical: Spacing.md,
  },
  totalLabel: {
    ...Typography.title3,
    fontWeight: '600',
  },
  totalValue: {
    ...Typography.title1,
    fontWeight: 'bold',
  },
  infoNote: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    marginTop: Spacing.md,
  },
  infoText: {
    ...Typography.caption1,
    flex: 1,
  },
  methodsContainer: {
    padding: Spacing.lg,
    gap: Spacing.md,
  },
  methodOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
    borderWidth: 2,
    gap: Spacing.md,
    ...Shadows.sm,
  },
  methodInfo: {
    flex: 1,
  },
  methodTitle: {
    ...Typography.headline,
    marginBottom: 4,
  },
  methodSubtitle: {
    ...Typography.subheadline,
  },
  escrowCard: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.xl,
    marginTop: Spacing.md,
  },
  escrowHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    marginBottom: Spacing.md,
  },
  escrowTitle: {
    ...Typography.headline,
  },
  escrowDescription: {
    ...Typography.subheadline,
    lineHeight: 20,
    marginBottom: Spacing.lg,
  },
  escrowFeatures: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  escrowFeature: {
    flex: 1,
    alignItems: 'center',
    gap: Spacing.xs,
  },
  featureTitle: {
    ...Typography.caption1,
    fontWeight: '600',
    textAlign: 'center',
  },
  featureDescription: {
    ...Typography.caption2,
    textAlign: 'center',
    lineHeight: 14,
  },
  bottomActions: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderTopWidth: 1,
    gap: Spacing.sm,
  },
  continueButton: {
    paddingVertical: Spacing.md + 2,
    borderRadius: BorderRadius.lg,
    alignItems: 'center',
    justifyContent: 'center',
    ...Shadows.md,
  },
  continueButtonText: {
    ...Typography.button,
    fontSize: 17,
    fontWeight: '600',
  },
  cancelButton: {
    paddingVertical: Spacing.sm,
    alignItems: 'center',
  },
  cancelButtonText: {
    ...Typography.subheadline,
  },
});

export default PaymentMethodSheet;
