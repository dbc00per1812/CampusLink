// OfferDetailScreen - View and respond to offers
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  Alert,
  TextInput,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as Haptics from 'expo-haptics';
import {
  Button,
  UserAvatar,
  LoadingSpinner,
  UnifiedHeader,
} from '../../components';
import {
  getOffer,
  acceptOffer,
  declineOffer,
  counterOffer,
  withdrawOffer,
  updateOfferWithOrder,
} from '../../services/offerService';
import { createOrder, updateOrderPaymentStatus, deletePendingOrder } from '../../services/orderService';
import {
  configurePaymentSheetForOrder,
  presentStripePaymentSheet,
} from '../../services/stripeService';
import { supabase } from '../../config/supabase';
import { Offer } from '../../types';
import Colors from '../../utils/colors';

type RouteParams = {
  OfferDetail: { offerId: string };
};

const OfferDetailScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const route = useRoute<RouteProp<RouteParams, 'OfferDetail'>>();
  const { offerId } = route.params;

  const [offer, setOffer] = useState<Offer | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isProcessing, setIsProcessing] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [showCounterInput, setShowCounterInput] = useState(false);
  const [counterAmount, setCounterAmount] = useState('');
  const [counterMessage, setCounterMessage] = useState('');
  const [showSuccessOverlay, setShowSuccessOverlay] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

  useEffect(() => {
    loadUserId();
    loadOffer();

    // Set up realtime subscription for offer updates
    const channel = supabase
      .channel(`offer:${offerId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'offers',
          filter: `id=eq.${offerId}`,
        },
        (payload) => {
          console.log('📡 Offer updated via realtime:', payload.new);
          setOffer((prev) =>
            prev
              ? {
                  ...prev,
                  ...payload.new,
                }
              : null
          );
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [offerId]);

  const loadUserId = async () => {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    setCurrentUserId(session?.user.id ?? null);
  };

  const loadOffer = async () => {
    try {
      const data = await getOffer(offerId);
      setOffer(data);
    } catch (error) {
      console.error('Error loading offer:', error);
      Alert.alert('Error', 'Failed to load offer details');
      navigation.goBack();
    } finally {
      setIsLoading(false);
    }
  };

  const isBuyer = currentUserId === offer?.buyer_id;
  const isSeller = currentUserId === offer?.seller_id;

  const showSuccess = (message: string) => {
    setSuccessMessage(message);
    setShowSuccessOverlay(true);
  };

  const handleAccept = async () => {
    if (!offer) return;

    Alert.alert(
      'Accept Offer',
      `Accept this offer of $${(offer.offer_amount / 100).toFixed(2)}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Accept',
          onPress: async () => {
            if (Platform.OS !== 'web') {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
            }
            setIsProcessing(true);
            try {
              await acceptOffer(offer.id);
              await loadOffer();
              showSuccess(
                'Offer accepted! The buyer has been notified and can now complete the purchase.'
              );
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to accept offer');
            } finally {
              setIsProcessing(false);
            }
          },
        },
      ]
    );
  };

  const handleDecline = async () => {
    if (!offer) return;

    Alert.alert('Decline Offer', 'Are you sure you want to decline this offer?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Decline',
        style: 'destructive',
        onPress: async () => {
          if (Platform.OS !== 'web') {
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
          }
          setIsProcessing(true);
          try {
            await declineOffer(offer.id);
            await loadOffer();
            showSuccess('Offer declined. The buyer has been notified.');
          } catch (error: any) {
            Alert.alert('Error', error.message || 'Failed to decline offer');
          } finally {
            setIsProcessing(false);
          }
        },
      },
    ]);
  };

  const handleCounter = async () => {
    if (!offer) return;

    const amount = parseFloat(counterAmount);
    if (isNaN(amount) || amount <= 0) {
      Alert.alert('Invalid Amount', 'Please enter a valid counter offer amount.');
      return;
    }

    const amountCents = Math.round(amount * 100);

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }

    setIsProcessing(true);
    try {
      await counterOffer(offer.id, amountCents, counterMessage || undefined);
      await loadOffer();
      setShowCounterInput(false);
      setCounterAmount('');
      setCounterMessage('');
      showSuccess('Counter offer sent! The buyer has been notified.');
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to send counter offer');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleWithdraw = async () => {
    if (!offer) return;

    Alert.alert('Withdraw Offer', 'Are you sure you want to withdraw your offer?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Withdraw',
        style: 'destructive',
        onPress: async () => {
          if (Platform.OS !== 'web') {
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
          }
          setIsProcessing(true);
          try {
            await withdrawOffer(offer.id);
            showSuccess('Offer withdrawn successfully.');
            setTimeout(() => navigation.goBack(), 1500);
          } catch (error: any) {
            Alert.alert('Error', error.message || 'Failed to withdraw offer');
          } finally {
            setIsProcessing(false);
          }
        },
      },
    ]);
  };

  const handlePayNow = useCallback(async () => {
    if (!offer || !currentUserId || !offer.listing) return;

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    }

    setIsProcessing(true);
    let pendingOrderId: string | null = null;

    try {
      // Calculate prices - offer_amount is already in cents
      const sellerPriceCents = offer.offer_amount;
      const stripeFeeCents = Math.round(sellerPriceCents * 0.029 + 30);
      const buyerPriceCents = sellerPriceCents + stripeFeeCents;

      console.log('💳 Creating order from accepted offer:', offer.id);
      console.log(`   Offer amount: $${sellerPriceCents / 100}`);
      console.log(`   Buyer pays: $${buyerPriceCents / 100}`);

      // Create order
      const pendingOrder = await createOrder({
        listing_id: offer.listing_id,
        buyer_id: currentUserId,
        seller_id: offer.seller_id,
        price_cents: sellerPriceCents,
        seller_price_cents: sellerPriceCents,
        buyer_price_cents: buyerPriceCents,
        payment_method: 'card',
        payment_status: 'pending',
        quantity: 1,
      });
      pendingOrderId = pendingOrder.id;
      console.log('✅ Pending order created:', pendingOrderId);

      // Configure Stripe PaymentSheet
      console.log('💳 Configuring payment sheet for order:', pendingOrderId);
      const paymentIntentData = await configurePaymentSheetForOrder(pendingOrderId);

      // Present PaymentSheet
      const paymentResult = await presentStripePaymentSheet();

      if (!paymentResult.success) {
        if (paymentResult.error === 'Payment cancelled') {
          console.log('ℹ️ User cancelled payment - cleaning up pending order');
        } else {
          console.log('❌ Payment failed - cleaning up pending order');
        }

        await deletePendingOrder(pendingOrderId);
        pendingOrderId = null;

        if (paymentResult.error !== 'Payment cancelled') {
          throw new Error(paymentResult.error || 'Payment failed');
        }
        return;
      }

      // Payment succeeded - update order
      console.log('✅ Payment succeeded, updating order...');
      await updateOrderPaymentStatus(pendingOrderId, paymentIntentData.payment_intent_id);

      // Link offer to order
      await updateOfferWithOrder(offer.id, pendingOrderId);

      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }

      showSuccess('Payment successful! Your order has been placed.');

      // Navigate to order after short delay
      setTimeout(() => {
        navigation.navigate('Wallet', {
          screen: 'OrderDetail',
          params: { orderId: pendingOrderId },
        });
      }, 2000);
    } catch (error: any) {
      console.error('❌ Payment error:', error);

      if (pendingOrderId) {
        try {
          await deletePendingOrder(pendingOrderId);
        } catch (cleanupError) {
          console.error('❌ Failed to cleanup pending order:', cleanupError);
        }
      }

      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }

      Alert.alert('Payment Failed', error.message || 'Unable to complete payment. Please try again.');
    } finally {
      setIsProcessing(false);
    }
  }, [offer, currentUserId, navigation]);

  const formatDate = (dateStr: string): string => {
    return new Date(dateStr).toLocaleDateString(undefined, {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getStatusColor = (status: string): string => {
    switch (status) {
      case 'pending':
        return Colors.warning;
      case 'accepted':
        return Colors.success;
      case 'declined':
      case 'expired':
      case 'withdrawn':
        return Colors.error;
      case 'countered':
        return Colors.primary;
      default:
        return Colors.textSecondary;
    }
  };

  const getStatusText = (status: string): string => {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'countered':
        return 'Countered';
      case 'withdrawn':
        return 'Withdrawn';
      case 'expired':
        return 'Expired';
      default:
        return status.charAt(0).toUpperCase() + status.slice(1);
    }
  };

  // Render seller actions (accept/decline/counter)
  const renderSellerActions = () => {
    if (!offer || !isSeller || offer.status !== 'pending') return null;

    if (showCounterInput) {
      return (
        <View style={styles.counterSection}>
          <Text style={styles.counterTitle}>Send Counter Offer</Text>
          <View style={styles.counterInputContainer}>
            <Text style={styles.currencySymbol}>$</Text>
            <TextInput
              style={styles.counterInput}
              value={counterAmount}
              onChangeText={setCounterAmount}
              placeholder="0.00"
              placeholderTextColor={Colors.textTertiary}
              keyboardType="decimal-pad"
              autoFocus
            />
          </View>
          <TextInput
            style={styles.counterMessageInput}
            value={counterMessage}
            onChangeText={setCounterMessage}
            placeholder="Add a message (optional)"
            placeholderTextColor={Colors.textTertiary}
            multiline
            numberOfLines={2}
          />
          <View style={styles.counterActions}>
            <Button
              title="Cancel"
              onPress={() => {
                setShowCounterInput(false);
                setCounterAmount('');
                setCounterMessage('');
              }}
              variant="outline"
              fullWidth={false}
              style={{ flex: 1 }}
            />
            <Button
              title="Send Counter"
              onPress={handleCounter}
              loading={isProcessing}
              fullWidth={false}
              style={{ flex: 1 }}
            />
          </View>
        </View>
      );
    }

    return (
      <View style={styles.actionsContainer}>
        <Button
          title="Accept Offer"
          onPress={handleAccept}
          icon="checkmark-circle"
          loading={isProcessing}
          variant="success"
        />
        <View style={styles.secondaryActions}>
          <Button
            title="Counter"
            onPress={() => setShowCounterInput(true)}
            variant="outline"
            icon="swap-horizontal"
            fullWidth={false}
            style={{ flex: 1 }}
          />
          <Button
            title="Decline"
            onPress={handleDecline}
            variant="danger"
            icon="close-circle"
            fullWidth={false}
            style={{ flex: 1 }}
          />
        </View>
      </View>
    );
  };

  // Render buyer actions (withdraw/pay)
  const renderBuyerActions = () => {
    if (!offer || !isBuyer) return null;

    if (offer.status === 'pending') {
      return (
        <View style={styles.actionsContainer}>
          <Button
            title="Withdraw Offer"
            onPress={handleWithdraw}
            variant="danger"
            icon="close-circle"
            loading={isProcessing}
          />
        </View>
      );
    }

    if (offer.status === 'accepted') {
      return (
        <View style={styles.actionsContainer}>
          <View style={styles.acceptedBanner}>
            <Ionicons name="checkmark-circle" size={24} color={Colors.success} />
            <View style={styles.acceptedBannerContent}>
              <Text style={styles.acceptedBannerTitle}>Offer Accepted!</Text>
              <Text style={styles.acceptedBannerMessage}>
                Complete your purchase to confirm the order.
              </Text>
            </View>
          </View>
          <Button
            title="Pay Now"
            onPress={handlePayNow}
            icon="card"
            loading={isProcessing}
          />
        </View>
      );
    }

    if (offer.status === 'countered') {
      const counterAmountDisplay = offer.counter_amount
        ? `$${(offer.counter_amount / 100).toFixed(2)}`
        : 'N/A';

      return (
        <View style={styles.actionsContainer}>
          <View style={styles.counterBanner}>
            <Ionicons name="swap-horizontal" size={24} color={Colors.primary} />
            <View style={styles.counterBannerContent}>
              <Text style={styles.counterBannerTitle}>Counter Offer Received</Text>
              <Text style={styles.counterBannerAmount}>{counterAmountDisplay}</Text>
              {offer.counter_message && (
                <Text style={styles.counterBannerMessage}>"{offer.counter_message}"</Text>
              )}
            </View>
          </View>
          <Text style={styles.counterHint}>
            You can make a new offer on the listing if you'd like to continue negotiating.
          </Text>
        </View>
      );
    }

    return null;
  };

  // Render success overlay
  const renderSuccessOverlay = () => {
    if (!showSuccessOverlay) return null;

    return (
      <View style={styles.successOverlay}>
        <View style={styles.successCard}>
          <View style={styles.successIconContainer}>
            <Ionicons name="checkmark-circle" size={80} color="#22C55E" />
          </View>
          <Text style={styles.successTitle}>Success!</Text>
          <Text style={styles.successMessage}>{successMessage}</Text>
          <TouchableOpacity
            style={styles.successButton}
            onPress={() => {
              setShowSuccessOverlay(false);
              if (offer?.status === 'withdrawn') {
                navigation.goBack();
              }
            }}
          >
            <Text style={styles.successButtonText}>Done</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading offer..." />;
  }

  if (!offer) {
    return (
      <SafeAreaView style={styles.container}>
        <UnifiedHeader title="Offer Details" />
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle-outline" size={64} color={Colors.textTertiary} />
          <Text style={styles.errorText}>Offer not found</Text>
        </View>
      </SafeAreaView>
    );
  }

  const otherUser = isBuyer ? offer.seller : offer.buyer;
  const statusColor = getStatusColor(offer.status);

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <UnifiedHeader title="Offer Details" />

      {renderSuccessOverlay()}

      <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
        {/* Status Badge */}
        <View style={styles.statusSection}>
          <View style={[styles.statusBadge, { backgroundColor: statusColor + '20' }]}>
            <Text style={[styles.statusText, { color: statusColor }]}>
              {getStatusText(offer.status)}
            </Text>
          </View>
          <Text style={styles.dateText}>{formatDate(offer.created_at)}</Text>
        </View>

        {/* Listing Info */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Item</Text>
          <TouchableOpacity
            style={styles.listingCard}
            onPress={() => {
              if (offer.listing_id) {
                navigation.navigate('Home', {
                  screen: 'ListingDetail',
                  params: { listingId: offer.listing_id },
                });
              }
            }}
          >
            {(offer.listing?.photos?.[0] || offer.listing?.photo) && (
              <Image
                source={{ uri: offer.listing?.photos?.[0] || offer.listing?.photo || undefined }}
                style={styles.listingImage}
              />
            )}
            <View style={styles.listingInfo}>
              <Text style={styles.listingTitle}>{offer.listing?.title || 'Unknown Item'}</Text>
              <Text style={styles.listingCategory}>{offer.listing?.category}</Text>
              {offer.listing?.price && (
                <Text style={styles.listingPrice}>
                  Listed at ${offer.listing.price.toFixed(2)}
                </Text>
              )}
            </View>
            <Ionicons name="chevron-forward" size={20} color={Colors.textTertiary} />
          </TouchableOpacity>
        </View>

        {/* Offer Amount */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Offer Details</Text>
          <View style={styles.offerCard}>
            <View style={styles.offerRow}>
              <Text style={styles.offerLabel}>Offer Amount</Text>
              <Text style={styles.offerAmount}>
                ${(offer.offer_amount / 100).toFixed(2)}
              </Text>
            </View>
            {offer.message && (
              <View style={styles.messageContainer}>
                <Text style={styles.messageLabel}>Message</Text>
                <Text style={styles.messageText}>"{offer.message}"</Text>
              </View>
            )}
          </View>
        </View>

        {/* Other Party */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{isBuyer ? 'Seller' : 'Buyer'}</Text>
          <View style={styles.partyCard}>
            <UserAvatar user={otherUser ?? null} size={48} />
            <View style={styles.partyInfo}>
              <Text style={styles.partyName}>{otherUser?.name || 'Unknown'}</Text>
              <Text style={styles.partyCampus}>{otherUser?.campus || ''}</Text>
            </View>
          </View>
        </View>

        {/* Actions */}
        {renderSellerActions()}
        {renderBuyerActions()}

        {/* Completed/Declined Status Info */}
        {(offer.status === 'declined' || offer.status === 'expired' || offer.status === 'withdrawn') && (
          <View style={styles.closedSection}>
            <Ionicons
              name={offer.status === 'declined' ? 'close-circle' : 'time-outline'}
              size={48}
              color={Colors.textTertiary}
            />
            <Text style={styles.closedText}>
              {offer.status === 'declined'
                ? 'This offer was declined by the seller.'
                : offer.status === 'withdrawn'
                ? 'You withdrew this offer.'
                : 'This offer has expired.'}
            </Text>
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
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 40,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 16,
  },
  errorText: {
    fontSize: 18,
    color: Colors.textSecondary,
  },
  statusSection: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  statusText: {
    fontSize: 14,
    fontWeight: '600',
  },
  dateText: {
    fontSize: 13,
    color: Colors.textSecondary,
  },
  section: {
    padding: 16,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginBottom: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  listingCard: {
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
  listingImage: {
    width: 70,
    height: 70,
    borderRadius: 8,
  },
  listingInfo: {
    flex: 1,
    marginLeft: 12,
  },
  listingTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  listingCategory: {
    fontSize: 14,
    color: Colors.textSecondary,
    marginBottom: 2,
  },
  listingPrice: {
    fontSize: 13,
    color: Colors.textTertiary,
  },
  offerCard: {
    backgroundColor: Colors.surface,
    borderRadius: 12,
    padding: 16,
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  offerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  offerLabel: {
    fontSize: 15,
    color: Colors.textSecondary,
  },
  offerAmount: {
    fontSize: 24,
    fontWeight: '700',
    color: Colors.primary,
  },
  messageContainer: {
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
  },
  messageLabel: {
    fontSize: 13,
    color: Colors.textSecondary,
    marginBottom: 6,
  },
  messageText: {
    fontSize: 15,
    color: Colors.textPrimary,
    fontStyle: 'italic',
    lineHeight: 22,
  },
  partyCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRadius: 12,
    padding: 12,
  },
  partyInfo: {
    flex: 1,
    marginLeft: 12,
  },
  partyName: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 2,
  },
  partyCampus: {
    fontSize: 14,
    color: Colors.textSecondary,
  },
  actionsContainer: {
    padding: 16,
    gap: 12,
  },
  secondaryActions: {
    flexDirection: 'row',
    gap: 12,
  },
  counterSection: {
    margin: 16,
    padding: 16,
    backgroundColor: Colors.surface,
    borderRadius: 12,
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  counterTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 16,
  },
  counterInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    paddingHorizontal: 16,
    marginBottom: 12,
  },
  currencySymbol: {
    fontSize: 24,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginRight: 8,
  },
  counterInput: {
    flex: 1,
    fontSize: 24,
    fontWeight: '600',
    color: Colors.textPrimary,
    paddingVertical: 14,
  },
  counterMessageInput: {
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    padding: 14,
    fontSize: 15,
    color: Colors.textPrimary,
    marginBottom: 16,
    minHeight: 60,
    textAlignVertical: 'top',
  },
  counterActions: {
    flexDirection: 'row',
    gap: 12,
  },
  acceptedBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#DCFCE7',
    borderRadius: 12,
    padding: 16,
    gap: 12,
    borderWidth: 1,
    borderColor: '#86EFAC',
  },
  acceptedBannerContent: {
    flex: 1,
  },
  acceptedBannerTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#166534',
    marginBottom: 4,
  },
  acceptedBannerMessage: {
    fontSize: 14,
    color: '#15803D',
    lineHeight: 18,
  },
  counterBanner: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: Colors.primary + '15',
    borderRadius: 12,
    padding: 16,
    gap: 12,
    borderWidth: 1,
    borderColor: Colors.primary + '40',
  },
  counterBannerContent: {
    flex: 1,
  },
  counterBannerTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.primary,
    marginBottom: 6,
  },
  counterBannerAmount: {
    fontSize: 22,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginBottom: 4,
  },
  counterBannerMessage: {
    fontSize: 14,
    color: Colors.textSecondary,
    fontStyle: 'italic',
    marginTop: 4,
  },
  counterHint: {
    fontSize: 13,
    color: Colors.textSecondary,
    textAlign: 'center',
    marginTop: 8,
    paddingHorizontal: 8,
  },
  closedSection: {
    alignItems: 'center',
    padding: 32,
    gap: 12,
  },
  closedText: {
    fontSize: 15,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  successOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.65)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
  },
  successCard: {
    backgroundColor: Colors.surface,
    borderRadius: 20,
    padding: 32,
    marginHorizontal: 32,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.25,
    shadowRadius: 20,
    elevation: 20,
  },
  successIconContainer: {
    marginBottom: 16,
  },
  successTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginBottom: 12,
  },
  successMessage: {
    fontSize: 16,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 24,
  },
  successButton: {
    backgroundColor: '#22C55E',
    paddingVertical: 16,
    paddingHorizontal: 48,
    borderRadius: 12,
    alignItems: 'center',
    width: '100%',
  },
  successButtonText: {
    fontSize: 17,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});

export default OfferDetailScreen;
