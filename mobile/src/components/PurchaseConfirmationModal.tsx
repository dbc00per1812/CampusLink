// PurchaseConfirmationModal - Matches iOS PurchaseConfirmationView
import React, { useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  ScrollView,
  TouchableOpacity,
  Animated,
  Dimensions,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Clipboard } from 'react-native';
import { useColors } from '../context/ThemeContext';
import { ListingWithUser, Order } from '../types';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface Props {
  visible: boolean;
  listing: ListingWithUser;
  order: Order;
  paymentMethod: 'wallet' | 'card';
  onClose: () => void;
  onViewOrder: () => void;
  onContactSeller: () => void;
}

export const PurchaseConfirmationModal: React.FC<Props> = ({
  visible,
  listing,
  order,
  paymentMethod,
  onClose,
  onViewOrder,
  onContactSeller,
}) => {
  const colors = useColors();
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(50)).current;
  const scaleAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (visible) {
      // Trigger haptic feedback
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }

      // Animate in
      Animated.parallel([
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: 600,
          useNativeDriver: true,
        }),
        Animated.timing(slideAnim, {
          toValue: 0,
          duration: 600,
          useNativeDriver: true,
        }),
        Animated.spring(scaleAnim, {
          toValue: 1,
          tension: 50,
          friction: 8,
          useNativeDriver: true,
        }),
      ]).start();
    } else {
      // Reset animations
      fadeAnim.setValue(0);
      slideAnim.setValue(50);
      scaleAnim.setValue(0);
    }
  }, [visible]);

  const handleCopyOrderId = () => {
    if (order) {
      Clipboard.setString(order.id);
      if (Platform.OS !== 'web') {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }
    }
  };

  const formatPrice = (cents: number): string => {
    return `$${(cents / 100).toFixed(2)}`;
  };

  const shortOrderId = order?.id.substring(0, 8) || 'Processing...';

  const paymentMethodInfo = {
    wallet: {
      icon: 'wallet' as const,
      name: 'CampusLink Wallet',
      color: '#22C55E',
    },
    card: {
      icon: 'card' as const,
      name: 'Credit/Debit Card',
      color: '#3B82F6',
    },
  };

  const pmInfo = paymentMethodInfo[paymentMethod];

  return (
    <Modal
      visible={visible}
      animationType="fade"
      transparent={false}
      presentationStyle="pageSheet"
    >
      <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
        {/* Header */}
        <View style={[styles.header, { borderBottomColor: colors.border }]}>
          <View style={styles.headerPlaceholder} />
          <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>Order Confirmation</Text>
          <TouchableOpacity onPress={onClose} style={styles.closeButton}>
            <Text style={[styles.closeButtonText, { color: colors.primary }]}>Close</Text>
          </TouchableOpacity>
        </View>

        <ScrollView 
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Success Icon */}
          <Animated.View 
            style={[
              styles.successIconContainer,
              {
                opacity: fadeAnim,
                transform: [{ scale: scaleAnim }],
              }
            ]}
          >
            <View style={[styles.successIconCircle, { backgroundColor: '#22C55E' }]}>
              <Ionicons name="checkmark" size={56} color="#FFFFFF" />
            </View>
          </Animated.View>

          {/* Title */}
          <Animated.View
            style={{
              opacity: fadeAnim,
              transform: [{ translateY: slideAnim }],
            }}
          >
            <Text style={[styles.title, { color: colors.textPrimary }]}>
              Order Confirmed!
            </Text>
            <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
              Your order for "{listing.title}" has been successfully created and is now protected by our escrow system.
            </Text>
          </Animated.View>

          {/* Order Details Section */}
          <Animated.View
            style={[
              styles.section,
              {
                opacity: fadeAnim,
                transform: [{ translateY: slideAnim }],
              }
            ]}
          >
            {/* Order ID Card */}
            <View style={[styles.card, { backgroundColor: colors.primaryMuted }]}>
              <View style={styles.cardHeader}>
                <View style={styles.cardIconRow}>
                  <Ionicons name="receipt-outline" size={22} color={colors.primary} />
                  <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>Order ID</Text>
                </View>
                <TouchableOpacity onPress={handleCopyOrderId}>
                  <Text style={[styles.copyButton, { color: colors.primary }]}>Copy</Text>
                </TouchableOpacity>
              </View>
              <View style={[styles.orderIdContainer, { backgroundColor: colors.surfaceSecondary }]}>
                <Text style={[styles.orderId, { color: colors.textSecondary }]}>{order?.id || 'Processing...'}</Text>
              </View>
            </View>

            {/* Payment Method Card */}
            <View style={[styles.card, { backgroundColor: `${pmInfo.color}10` }]}>
              <View style={styles.cardIconRow}>
                <Ionicons name={pmInfo.icon} size={22} color={pmInfo.color} />
                <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>Payment Method</Text>
              </View>
              <View style={[styles.valueContainer, { backgroundColor: colors.surfaceSecondary }]}>
                <Text style={[styles.cardValue, { color: colors.textSecondary }]}>{pmInfo.name}</Text>
              </View>
            </View>

            {/* Total Amount Card */}
            <View style={[styles.card, { backgroundColor: '#22C55E10' }]}>
              <View style={styles.cardIconRow}>
                <Ionicons name="cash-outline" size={22} color="#22C55E" />
                <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>Total Amount Paid</Text>
              </View>
              <View style={[styles.valueContainer, { backgroundColor: '#22C55E20' }]}>
                <Text style={[styles.priceValue, { color: '#22C55E' }]}>
                  {formatPrice(order?.buyer_price_cents || order?.price_cents || 0)}
                </Text>
              </View>
            </View>
          </Animated.View>

          {/* What Happens Next Section */}
          <Animated.View
            style={[
              styles.section,
              {
                opacity: fadeAnim,
                transform: [{ translateY: slideAnim }],
              }
            ]}
          >
            <View style={[styles.stepsCard, { backgroundColor: colors.surfaceSecondary }]}>
              <View style={styles.cardIconRow}>
                <Ionicons name="list-outline" size={22} color={colors.primary} />
                <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>What Happens Next</Text>
              </View>
              <Text style={[styles.stepsIntro, { color: colors.textSecondary }]}>
                Follow these steps to complete your transaction safely:
              </Text>

              {listing.listing_type === 'service' ? (
                <>
                  {/* Service Flow - PIN Confirmation */}
                  {/* Step 1 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>1</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="calendar-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>Schedule the Service</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        Contact the seller to arrange a time and place for the service
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>Coordinate via messages</Text>
                      </View>
                    </View>
                  </View>

                  <View style={[styles.stepDivider, { backgroundColor: colors.border }]} />

                  {/* Step 2 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>2</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="construct-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>Service Completion</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        The seller completes the service as agreed
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>At scheduled time</Text>
                      </View>
                    </View>
                  </View>

                  <View style={[styles.stepDivider, { backgroundColor: colors.border }]} />

                  {/* Step 3 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>3</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="key-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>Share Your PIN</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        Once satisfied with the service, share your 4-digit confirmation PIN with the seller
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>After service completion</Text>
                      </View>
                    </View>
                  </View>

                  <View style={[styles.stepDivider, { backgroundColor: colors.border }]} />

                  {/* Step 4 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>4</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="shield-checkmark-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>Payment Released</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        Seller enters your PIN to confirm completion and receive payment
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>Automatic</Text>
                      </View>
                    </View>
                  </View>

                  {/* Seller PIN Requirement Warning */}
                  <View style={[styles.protectionNotice, { backgroundColor: '#F5920015' }]}>
                    <Ionicons name="warning" size={20} color="#F59200" />
                    <View style={styles.protectionTextContainer}>
                      <Text style={[styles.protectionTitle, { color: colors.textPrimary, fontWeight: '700' }]}>Important for Sellers</Text>
                      <Text style={[styles.protectionText, { color: colors.textSecondary }]}>
                        <Text style={{ fontWeight: '700' }}>We cannot guarantee payment unless the PIN is received.</Text> The seller must obtain your confirmation PIN to complete the transaction and receive payment.
                      </Text>
                    </View>
                  </View>
                </>
              ) : (
                <>
                  {/* Product Flow - Delivery Confirmation */}
                  {/* Step 1 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>1</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="cube-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>Seller Prepares Item</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        The seller will prepare and arrange delivery of your item
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>Within 24-48 hours</Text>
                      </View>
                    </View>
                  </View>

                  <View style={[styles.stepDivider, { backgroundColor: colors.border }]} />

                  {/* Step 2 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>2</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="camera-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>Delivery & Photo Upload</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        Seller uploads a delivery photo and marks the order as delivered
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>When delivered</Text>
                      </View>
                    </View>
                  </View>

                  <View style={[styles.stepDivider, { backgroundColor: colors.border }]} />

                  {/* Step 3 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>3</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="notifications-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>You'll Be Notified</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        You'll receive a notification to confirm receipt of the item
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>Immediately</Text>
                      </View>
                    </View>
                  </View>

                  <View style={[styles.stepDivider, { backgroundColor: colors.border }]} />

                  {/* Step 4 */}
                  <View style={styles.stepRow}>
                    <View style={[styles.stepNumber, { backgroundColor: colors.primary }]}>
                      <Text style={styles.stepNumberText}>4</Text>
                    </View>
                    <View style={styles.stepContent}>
                      <View style={styles.stepTitleRow}>
                        <Ionicons name="shield-checkmark-outline" size={16} color={colors.primary} />
                        <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>Confirm Receipt</Text>
                      </View>
                      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>
                        Verify the item matches the description and confirm to release payment
                      </Text>
                      <View style={styles.stepTimeRow}>
                        <Ionicons name="time-outline" size={12} color={colors.textTertiary} />
                        <Text style={[styles.stepTime, { color: colors.textTertiary }]}>After inspection</Text>
                      </View>
                    </View>
                  </View>

                  {/* Protection Notice */}
                  <View style={[styles.protectionNotice, { backgroundColor: '#3B82F615' }]}>
                    <Ionicons name="information-circle" size={20} color="#3B82F6" />
                    <View style={styles.protectionTextContainer}>
                      <Text style={[styles.protectionTitle, { color: colors.textPrimary }]}>Your Protection</Text>
                      <Text style={[styles.protectionText, { color: colors.textSecondary }]}>
                        Payment is held securely in escrow until you confirm receipt. Only confirm after verifying the item is as described.
                      </Text>
                    </View>
                  </View>
                </>
              )}
            </View>
          </Animated.View>

          {/* Escrow Protection Section */}
          <Animated.View
            style={[
              styles.section,
              {
                opacity: fadeAnim,
                transform: [{ translateY: slideAnim }],
              }
            ]}
          >
            <View style={[styles.escrowCard, { backgroundColor: '#22C55E15' }]}>
              <View style={styles.escrowHeader}>
                <Ionicons name="shield-checkmark" size={28} color="#22C55E" />
                <View style={styles.escrowHeaderText}>
                  <Text style={[styles.escrowTitle, { color: colors.textPrimary }]}>Escrow Protection</Text>
                  <Text style={[styles.escrowSubtitle, { color: colors.textSecondary }]}>
                    Your payment is held securely until you're satisfied
                  </Text>
                </View>
              </View>

              {/* Escrow Timeline */}
              <View style={styles.escrowTimeline}>
                {listing.listing_type === 'service' ? (
                  <>
                    <View style={styles.escrowStep}>
                      <Ionicons name="time" size={20} color="#22C55E" />
                      <View style={styles.escrowStepContent}>
                        <Text style={[styles.escrowStepTitle, { color: colors.textPrimary }]}>Order Processing</Text>
                        <Text style={[styles.escrowStepDesc, { color: colors.textSecondary }]}>Scheduling your service</Text>
                      </View>
                      <Ionicons name="checkmark-circle" size={20} color="#22C55E" />
                    </View>

                    <View style={styles.escrowStep}>
                      <Ionicons name="construct" size={20} color={colors.textTertiary} />
                      <View style={styles.escrowStepContent}>
                        <Text style={[styles.escrowStepTitle, { color: colors.textPrimary }]}>Service Completion</Text>
                        <Text style={[styles.escrowStepDesc, { color: colors.textSecondary }]}>Seller completes the service</Text>
                      </View>
                      <Ionicons name="ellipse-outline" size={20} color={colors.textTertiary} />
                    </View>

                    <View style={styles.escrowStep}>
                      <Ionicons name="key" size={20} color={colors.textTertiary} />
                      <View style={styles.escrowStepContent}>
                        <Text style={[styles.escrowStepTitle, { color: colors.textPrimary }]}>PIN Confirmation</Text>
                        <Text style={[styles.escrowStepDesc, { color: colors.textSecondary }]}>Share PIN to release payment</Text>
                      </View>
                      <Ionicons name="ellipse-outline" size={20} color={colors.textTertiary} />
                    </View>
                  </>
                ) : (
                  <>
                    <View style={styles.escrowStep}>
                      <Ionicons name="time" size={20} color="#22C55E" />
                      <View style={styles.escrowStepContent}>
                        <Text style={[styles.escrowStepTitle, { color: colors.textPrimary }]}>Order Processing</Text>
                        <Text style={[styles.escrowStepDesc, { color: colors.textSecondary }]}>Seller preparing your item</Text>
                      </View>
                      <Ionicons name="checkmark-circle" size={20} color="#22C55E" />
                    </View>

                    <View style={styles.escrowStep}>
                      <Ionicons name="car" size={20} color={colors.textTertiary} />
                      <View style={styles.escrowStepContent}>
                        <Text style={[styles.escrowStepTitle, { color: colors.textPrimary }]}>Delivery</Text>
                        <Text style={[styles.escrowStepDesc, { color: colors.textSecondary }]}>Item on its way to you</Text>
                      </View>
                      <Ionicons name="ellipse-outline" size={20} color={colors.textTertiary} />
                    </View>

                    <View style={styles.escrowStep}>
                      <Ionicons name="shield-checkmark" size={20} color={colors.textTertiary} />
                      <View style={styles.escrowStepContent}>
                        <Text style={[styles.escrowStepTitle, { color: colors.textPrimary }]}>Confirm Receipt</Text>
                        <Text style={[styles.escrowStepDesc, { color: colors.textSecondary }]}>Release payment to seller</Text>
                      </View>
                      <Ionicons name="ellipse-outline" size={20} color={colors.textTertiary} />
                    </View>
                  </>
                )}
              </View>
            </View>
          </Animated.View>

          {/* Action Buttons */}
          <Animated.View
            style={[
              styles.actionsSection,
              {
                opacity: fadeAnim,
                transform: [{ translateY: slideAnim }],
              }
            ]}
          >
            {/* View Order Details */}
            <TouchableOpacity
              style={[styles.primaryButton, { backgroundColor: colors.primary }]}
              onPress={onViewOrder}
              activeOpacity={0.8}
            >
              <Ionicons name="document-text-outline" size={20} color="#FFFFFF" />
              <Text style={styles.primaryButtonText}>View Order Details</Text>
            </TouchableOpacity>

            {/* Contact Seller */}
            <TouchableOpacity
              style={[styles.secondaryButton, { borderColor: colors.primary }]}
              onPress={onContactSeller}
              activeOpacity={0.8}
            >
              <Ionicons name="chatbubble-outline" size={20} color={colors.primary} />
              <Text style={[styles.secondaryButtonText, { color: colors.primary }]}>Contact Seller</Text>
            </TouchableOpacity>

            {/* Continue Shopping */}
            <TouchableOpacity
              style={[styles.tertiaryButton, { backgroundColor: colors.surfaceSecondary }]}
              onPress={onClose}
              activeOpacity={0.8}
            >
              <Text style={[styles.tertiaryButtonText, { color: colors.textSecondary }]}>Continue Shopping</Text>
            </TouchableOpacity>
          </Animated.View>
        </ScrollView>
      </SafeAreaView>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
  },
  headerPlaceholder: {
    width: 50,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
  },
  closeButton: {
    padding: 4,
  },
  closeButtonText: {
    fontSize: 17,
    fontWeight: '500',
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingVertical: 30,
    paddingHorizontal: 20,
  },
  successIconContainer: {
    alignItems: 'center',
    marginBottom: 24,
  },
  successIconCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: 12,
  },
  subtitle: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
    paddingHorizontal: 20,
    marginBottom: 30,
  },
  section: {
    marginBottom: 24,
  },
  card: {
    padding: 16,
    borderRadius: 14,
    marginBottom: 12,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  cardIconRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 12,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  copyButton: {
    fontSize: 14,
    fontWeight: '500',
  },
  orderIdContainer: {
    padding: 12,
    borderRadius: 10,
  },
  orderId: {
    fontSize: 13,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
  valueContainer: {
    padding: 12,
    borderRadius: 10,
  },
  cardValue: {
    fontSize: 15,
  },
  priceValue: {
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
  },
  stepsCard: {
    padding: 20,
    borderRadius: 16,
  },
  stepsIntro: {
    fontSize: 14,
    marginBottom: 20,
    lineHeight: 20,
  },
  stepRow: {
    flexDirection: 'row',
    gap: 12,
    paddingVertical: 8,
  },
  stepNumber: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepNumberText: {
    fontSize: 14,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  stepContent: {
    flex: 1,
  },
  stepTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 4,
  },
  stepTitle: {
    fontSize: 15,
    fontWeight: '600',
  },
  stepDescription: {
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 4,
  },
  stepTimeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  stepTime: {
    fontSize: 12,
  },
  stepDivider: {
    height: 1,
    marginVertical: 12,
  },
  protectionNotice: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    padding: 14,
    borderRadius: 12,
    marginTop: 16,
    gap: 12,
  },
  protectionTextContainer: {
    flex: 1,
  },
  protectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 4,
  },
  protectionText: {
    fontSize: 12,
    lineHeight: 18,
  },
  escrowCard: {
    padding: 20,
    borderRadius: 16,
  },
  escrowHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
    marginBottom: 16,
  },
  escrowHeaderText: {
    flex: 1,
  },
  escrowTitle: {
    fontSize: 17,
    fontWeight: '600',
    marginBottom: 4,
  },
  escrowSubtitle: {
    fontSize: 14,
    lineHeight: 20,
  },
  escrowTimeline: {
    gap: 12,
  },
  escrowStep: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    gap: 12,
  },
  escrowStepContent: {
    flex: 1,
  },
  escrowStepTitle: {
    fontSize: 14,
    fontWeight: '500',
  },
  escrowStepDesc: {
    fontSize: 13,
  },
  actionsSection: {
    gap: 14,
    marginTop: 10,
  },
  primaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 12,
    gap: 10,
  },
  primaryButtonText: {
    fontSize: 17,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  secondaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 12,
    borderWidth: 2,
    gap: 10,
  },
  secondaryButtonText: {
    fontSize: 17,
    fontWeight: '600',
  },
  tertiaryButton: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 12,
  },
  tertiaryButtonText: {
    fontSize: 17,
    fontWeight: '500',
  },
});

export default PurchaseConfirmationModal;

