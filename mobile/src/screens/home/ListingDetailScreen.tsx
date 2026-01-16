// Listing Detail Screen - Modern iOS-aligned design
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  ActivityIndicator,
  Dimensions,
  Alert,
  Platform,
  Modal,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { HomeScreenProps } from '../../navigation/types';
import { getListing, deleteListing } from '../../services/listingService';
import { getCurrentUserId } from '../../services/authService';
import { ListingWithUser, ListingTypeDisplay, DeliveryMethodDisplay, ServiceLocationDisplay } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { useOrderMonitor } from '../../context/OrderMonitorContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows, Layout } from '../../utils/spacing';
import { ImageGallery, UserAvatar, Button, SellerRatingSummary, ReportUserModal, TicketGuaranteeInfo, ProductVerificationInfo, ServiceVerificationInfo, PaymentMethodSheet, MakeOfferSheet, PurchaseConfirmationModal, ShareListingSheet } from '../../components';
import { configurePaymentSheet, configurePaymentSheetForOrder, presentStripePaymentSheet } from '../../services/stripeService';
import { createOrder, deletePendingOrder, updateOrderPaymentStatus } from '../../services/orderService';
import { createOffer } from '../../services/offerService';
import { blockUser } from '../../services/userService';
import { getOrCreateConversation } from '../../services/messagingService';
import type { Order } from '../../types';

type Props = HomeScreenProps<'ListingDetail'>;
const { width: SCREEN_WIDTH } = Dimensions.get('window');

const ListingDetailScreen: React.FC<Props> = ({ navigation, route }) => {
  const { listingId, returnTo, returnParams } = route.params;
  const colors = useColors();
  const { refreshActiveOrders } = useOrderMonitor();
  const [listing, setListing] = useState<ListingWithUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showMenuModal, setShowMenuModal] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);
  const [showPaymentMethodSheet, setShowPaymentMethodSheet] = useState(false);
  const [showMakeOfferSheet, setShowMakeOfferSheet] = useState(false);
  const [createdOrder, setCreatedOrder] = useState<Order | null>(null);
  const [showPurchaseConfirmation, setShowPurchaseConfirmation] = useState(false);
  const [showShareSheet, setShowShareSheet] = useState(false);
  const [isProcessingPayment, setIsProcessingPayment] = useState(false);

  const handleBack = useCallback(() => {
    if (returnTo === 'Chat' && returnParams?.conversationId) {
      // Navigate back to the chat screen
      navigation.navigate('Messages', {
        screen: 'Chat',
        params: { conversationId: returnParams.conversationId }
      });
    } else {
      // Default back behavior
      navigation.goBack();
    }
  }, [returnTo, returnParams, navigation]);

  useEffect(() => {
    const load = async () => {
      try {
        const [data, userId] = await Promise.all([
          getListing(listingId),
          getCurrentUserId(),
        ]);
        setListing(data);
        setCurrentUserId(userId);
      } catch (error) {
        console.error('Failed to load listing:', error);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [listingId]);

  const images = listing?.photos?.length
    ? listing.photos
    : listing?.photo
    ? [listing.photo]
    : [];

  const isOwnListing = currentUserId && listing?.user_id === currentUserId;
  const isSeek = listing?.intent === 'seek';

  const formatPrice = (): string => {
    if (!listing) return '';
    if (isSeek) {
      if (listing.budget_min && listing.budget_max) {
        return `$${listing.budget_min.toFixed(0)} - $${listing.budget_max.toFixed(0)}`;
      } else if (listing.budget_max) {
        return `Up to $${listing.budget_max.toFixed(0)}`;
      }
    }
    if (listing.price !== null && listing.price !== undefined) {
      return `$${listing.price.toFixed(2)}`;
    }
    return 'Make an offer';
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const handleShare = useCallback(() => {
    if (!listing) return;
    
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    
    // Open the new share sheet with Snapchat/Instagram options
    setShowShareSheet(true);
  }, [listing]);

  const handleEdit = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    navigation.navigate('EditListing', { listingId: listing.id });
  }, [listing, navigation]);

  const handleDelete = useCallback(() => {
    if (!listing) return;
    
    Alert.alert(
      'Delete Listing',
      'Are you sure you want to delete this listing? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            setIsDeleting(true);
            try {
              await deleteListing(listing.id);
              if (Platform.OS !== 'web') {
                Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
              }
              handleBack();
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to delete listing');
            } finally {
              setIsDeleting(false);
            }
          },
        },
      ]
    );
  }, [listing, navigation]);

  const handleMessage = useCallback(async () => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    
    try {
      // Get or create conversation for this listing
      const conversation = await getOrCreateConversation(listing.id, listing.user_id);
      
      // Navigate to Messages tab and then to Chat screen with the actual conversation ID
      navigation.navigate('Messages', { 
        screen: 'Chat', 
        params: { 
          conversationId: conversation.id,
          returnScreen: 'ListingDetail',
          returnParams: { listingId: listing.id }
        }
      });
    } catch (error: any) {
      console.error('Error creating conversation:', error);
      Alert.alert('Error', error.message || 'Failed to start conversation. Please try again.');
    }
  }, [listing, navigation]);

  const handleBuyNow = useCallback(() => {
    if (!listing || !currentUserId) return;
    
    // Validate that listing has a valid price before proceeding
    if (listing.price === null || listing.price === undefined || listing.price <= 0) {
      Alert.alert(
        'Price Not Set',
        'This listing doesn\'t have a valid price. Please contact the seller or make an offer instead.',
        [{ text: 'OK' }]
      );
      return;
    }
    
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    }

    // Show payment method selection sheet first
    setShowPaymentMethodSheet(true);
  }, [listing, currentUserId]);

  const handlePaymentMethodSelected = useCallback(async (paymentMethod: 'card' | 'apple_pay' | 'google_pay') => {
    if (!listing || !currentUserId) return;
    
    // Set processing state (doesn't affect main screen rendering)
    setIsProcessingPayment(true);
    
    // Close the payment method sheet
    setShowPaymentMethodSheet(false);
    
    try {
      // Card, Apple Pay, and Google Pay all use Stripe PaymentSheet
      // The PaymentSheet will automatically show the appropriate methods
      await handleCardPayment();
    } catch (error: any) {
      console.error('❌ Payment error:', error);
      
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      
      Alert.alert(
        'Payment Failed',
        error.message || 'Unable to complete payment. Please try again.',
        [{ text: 'OK' }]
      );
    } finally {
      setIsProcessingPayment(false);
    }
  }, [listing, currentUserId, navigation]);

  const handleCardPayment = useCallback(async () => {
    if (!listing || !currentUserId) return;

    // SAFETY CHECK: Validate price before proceeding
    // This prevents creating orders with $0 price which would fail in the edge function
    if (listing.price === null || listing.price === undefined || listing.price <= 0) {
      throw new Error('This listing doesn\'t have a valid price. Please contact the seller.');
    }

    // ORDER-FIRST FLOW: Create order before payment to avoid orphaned PaymentIntents
    let pendingOrderId: string | null = null;

    try {
      // Step 1: Calculate prices locally
      // Stripe fee: 2.9% + $0.30
      const sellerPriceCents = Math.round(listing.price * 100);
      const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30);
      const buyerPriceCents = sellerPriceCents + stripeFeeCents;

      console.log('💳 Creating pending order for listing:', listing.id);
      console.log(`   Seller price: $${sellerPriceCents / 100}`);
      console.log(`   Buyer pays: $${buyerPriceCents / 100}`);

      // Step 2: Create order with payment_status: 'pending'
      const pendingOrder = await createOrder({
        listing_id: listing.id,
        buyer_id: currentUserId,
        seller_id: listing.user_id,
        price_cents: sellerPriceCents,
        seller_price_cents: sellerPriceCents,
        buyer_price_cents: buyerPriceCents,
        payment_method: 'card',
        payment_status: 'pending',
        quantity: 1,
      });
      pendingOrderId = pendingOrder.id;
      console.log('✅ Pending order created:', pendingOrderId);

      // Step 3: Configure Stripe PaymentSheet for the order
      console.log('💳 Configuring payment sheet for order:', pendingOrderId);
      const paymentIntentData = await configurePaymentSheetForOrder(pendingOrderId);

      // Step 4: Present PaymentSheet to user
      const paymentResult = await presentStripePaymentSheet();

      if (!paymentResult.success) {
        // User cancelled or payment failed - clean up the pending order
        if (paymentResult.error === 'Payment cancelled') {
          console.log('ℹ️ User cancelled payment - cleaning up pending order');
        } else {
          console.log('❌ Payment failed - cleaning up pending order');
        }
        
        // Delete the pending order since payment was not completed
        await deletePendingOrder(pendingOrderId);
        pendingOrderId = null;
        
        if (paymentResult.error !== 'Payment cancelled') {
          throw new Error(paymentResult.error || 'Payment failed');
        }
        return;
      }

      // Step 5: Payment succeeded - Update order with payment_intent_id and status
      console.log('✅ Payment succeeded, updating order...');
      const updatedOrder = await updateOrderPaymentStatus(
        pendingOrderId,
        paymentIntentData.payment_intent_id
      );
      pendingOrderId = null; // Clear since order is now confirmed

      console.log('✅ Order updated with payment:', updatedOrder.id);

      // Refresh active orders in the context
      refreshActiveOrders();

      // Show success feedback
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }

      // Show purchase confirmation modal
      setCreatedOrder(updatedOrder);
      setShowPurchaseConfirmation(true);
    } catch (error) {
      // If an error occurred and we have a pending order, try to clean it up
      if (pendingOrderId) {
        console.log('⚠️ Error occurred - attempting to clean up pending order:', pendingOrderId);
        try {
          await deletePendingOrder(pendingOrderId);
        } catch (cleanupError) {
          console.error('❌ Failed to clean up pending order:', cleanupError);
        }
      }
      throw error;
    }
  }, [listing, currentUserId, navigation, refreshActiveOrders]);

  const handleMakeOffer = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    setShowMakeOfferSheet(true);
  }, [listing]);

  const handleSubmitOffer = useCallback(async (offerAmount: number, message: string) => {
    if (!listing || !currentUserId) return;

    // Convert to cents for the API
    const offerAmountCents = Math.round(offerAmount * 100);

    await createOffer(
      listing.id,
      listing.user_id,
      offerAmountCents,
      message || undefined
    );

    if (Platform.OS !== 'web') {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    }

    Alert.alert(
      'Offer Sent!',
      'Your offer has been sent to the seller. You\'ll be notified when they respond.',
      [{ text: 'OK' }]
    );
  }, [listing, currentUserId]);

  const handleSellerPress = useCallback(() => {
    if (!listing) return;
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    navigation.navigate('PublicProfile', { userId: listing.user_id });
  }, [listing, navigation]);

  const handleMenuPress = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setShowMenuModal(true);
  }, []);

  const handleReport = useCallback(() => {
    setShowMenuModal(false);
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    setShowReportModal(true);
  }, []);

  const handleBlockUser = useCallback(() => {
    setShowMenuModal(false);
    if (!listing || !currentUserId || !listing.user?.id) return;
    
    Alert.alert(
      'Block User',
      `Are you sure you want to block ${listing.user?.name || 'this user'}? You won't see their listings or be able to message them.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Block',
          style: 'destructive',
          onPress: async () => {
            try {
              await blockUser(currentUserId, listing.user!.id);
              if (Platform.OS !== 'web') {
                Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
              }
              Alert.alert('Success', 'User blocked successfully');
              navigation.goBack();
            } catch (error) {
              console.error('Error blocking user:', error);
              Alert.alert('Error', 'Failed to block user. Please try again.');
            }
          },
        },
      ]
    );
  }, [listing, currentUserId, navigation]);

  // Loading state
  if (loading) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  // Error state
  if (!listing) {
    return (
      <View style={[styles.errorContainer, { backgroundColor: colors.background }]}>
        <Ionicons name="alert-circle-outline" size={64} color={colors.textTertiary} />
        <Text style={[styles.errorText, { color: colors.textSecondary }]}>
          Listing not found
        </Text>
        <Button
          title="Go Back"
          onPress={handleBack}
          variant="outline"
          size="medium"
          fullWidth={false}
          icon="arrow-back"
        />
      </View>
    );
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      {/* Header */}
      <View style={[styles.header, { backgroundColor: colors.background, borderBottomColor: colors.border }]}>
        <Pressable
          onPress={handleBack}
          style={({ pressed }) => [styles.headerButton, { opacity: pressed ? 0.5 : 1 }]}
        >
          <Ionicons name="chevron-back" size={28} color={colors.primary} />
        </Pressable>
        
        <View style={styles.headerActions}>
          <Pressable
            onPress={handleShare}
            style={({ pressed }) => [styles.headerIconButton, { opacity: pressed ? 0.5 : 1 }]}
          >
            <Ionicons name="share-outline" size={24} color={colors.primary} />
          </Pressable>

          
          {!isOwnListing && (
            <Pressable
              onPress={handleMenuPress}
              style={({ pressed }) => [styles.headerIconButton, { opacity: pressed ? 0.5 : 1 }]}
            >
              <Ionicons name="ellipsis-horizontal-circle-outline" size={24} color={colors.primary} />
            </Pressable>
          )}
        </View>
      </View>

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Image Gallery */}
        <ImageGallery
          images={images}
          showThumbnails={images.length > 1}
          aspectRatio={1}
        />

        {/* Content */}
        <View style={styles.content}>
          {/* Title and Price Section */}
          <View style={styles.titleSection}>
            <Text style={[styles.title, { color: colors.textPrimary }]}>
              {listing.title}
            </Text>

            <Text
              style={[
                styles.price,
                { color: isOwnListing ? colors.primary : colors.success },
              ]}
            >
              {formatPrice()}
            </Text>

            {/* Badges */}
            <View style={styles.badgeRow}>
              {/* Category */}
              <View style={[styles.badge, { backgroundColor: colors.primaryMuted }]}>
                <Text style={[styles.badgeText, { color: colors.primary }]}>
                  {listing.category}
                </Text>
              </View>

              {/* Type */}
              <View
                style={[
                  styles.badge,
                  {
                    backgroundColor:
                      listing.listing_type === 'product'
                        ? colors.infoLight
                        : colors.successLight,
                  },
                ]}
              >
                <Text
                  style={[
                    styles.badgeText,
                    {
                      color:
                        listing.listing_type === 'product'
                          ? colors.info
                          : colors.success,
                    },
                  ]}
                >
                  {ListingTypeDisplay[listing.listing_type]}
                </Text>
              </View>

              {/* WANTED badge */}
              {isSeek && (
                <View style={[styles.badge, { backgroundColor: colors.warning }]}>
                  <Text style={[styles.badgeText, { color: colors.textInverse }]}>
                    WANTED
                  </Text>
                </View>
              )}
            </View>
          </View>

          {/* Service Details Section */}
          {listing.listing_type === 'service' && (
            <View style={[styles.section, styles.serviceCard, { backgroundColor: colors.surfaceSecondary }]}>
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                Service Details
              </Text>
              
              {listing.service_duration && (
                <View style={styles.detailRow}>
                  <View style={styles.detailIcon}>
                    <Ionicons name="time-outline" size={20} color={colors.primary} />
                  </View>
                  <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                    Duration:
                  </Text>
                  <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                    {listing.service_duration}
                  </Text>
                </View>
              )}
              
              {listing.service_location && (
                <View style={styles.detailRow}>
                  <View style={styles.detailIcon}>
                    <Ionicons name="location-outline" size={20} color={colors.primary} />
                  </View>
                  <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                    Location:
                  </Text>
                  <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                    {ServiceLocationDisplay[listing.service_location]}
                  </Text>
                </View>
              )}
              
              {listing.service_availability && (
                <View style={styles.detailRow}>
                  <View style={styles.detailIcon}>
                    <Ionicons name="calendar-outline" size={20} color={colors.primary} />
                  </View>
                  <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                    Availability:
                  </Text>
                  <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                    {listing.service_availability}
                  </Text>
                </View>
              )}

              {/* Service Verification Info for buyers */}
              {!isOwnListing && (
                <ServiceVerificationInfo isForSeller={false} />
              )}
            </View>
          )}

          {/* Description Section */}
          <View style={styles.section}>
            {listing.description && (
              <>
                <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                  Description
                </Text>
                <Text style={[styles.description, { color: colors.textSecondary }]}>
                  {listing.description}
                </Text>
              </>
            )}

            {/* Show ticket guarantee info when Tickets category is selected */}
            {listing.category === 'Tickets' && (
              <TicketGuaranteeInfo isOwnListing={isOwnListing} />
            )}

            {/* Show product verification info for products */}
            {listing.listing_type === 'product' && (
              <ProductVerificationInfo isForSeller={isOwnListing} />
            )}
          </View>

          {/* Seller Info Section */}
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              {isSeek ? 'Posted by' : 'Seller Information'}
            </Text>
            <Pressable
              style={({ pressed }) => [
                styles.sellerCard,
                { backgroundColor: colors.surfaceSecondary, opacity: pressed ? 0.8 : 1 },
              ]}
              onPress={handleSellerPress}
            >
              <UserAvatar user={listing.user} size={50} />
              <View style={styles.sellerInfo}>
                <Text style={[styles.sellerName, { color: colors.textPrimary }]}>
                  {listing.user?.name || 'Unknown'}
                </Text>
                <Text style={[styles.sellerCampus, { color: colors.textSecondary }]}>
                  {listing.user?.campus || 'Campus'}
                </Text>
                {/* Seller Ratings */}
                <SellerRatingSummary userId={listing.user_id} />
              </View>
              <Ionicons name="chevron-forward" size={20} color={colors.textTertiary} />
            </Pressable>
          </View>

          {/* Listing Details Section */}
          <View style={[styles.section, styles.detailsCard, { backgroundColor: colors.surfaceSecondary }]}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Listing Details
            </Text>
            <View style={styles.detailRow}>
              <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                Posted
              </Text>
              <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                {formatDate(listing.created_at)}
              </Text>
            </View>
            {listing.quantity_available && listing.quantity_available > 1 && (
              <View style={styles.detailRow}>
                <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                  Available
                </Text>
                <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                  {listing.quantity_available} items
                </Text>
              </View>
            )}
            {listing.delivery_method && (
              <View style={styles.detailRow}>
                <Text style={[styles.detailLabel, { color: colors.textSecondary }]}>
                  Delivery
                </Text>
                <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                  {DeliveryMethodDisplay[listing.delivery_method]}
                </Text>
              </View>
            )}
          </View>

          {/* Action Buttons - Now inside ScrollView like iOS */}
          <View style={styles.actionsSection}>
            {isOwnListing ? (
              // Owner actions
              <View style={styles.actionRow}>
                <View style={styles.actionButtonHalf}>
                  <Button
                    title="Edit"
                    onPress={handleEdit}
                    variant="primary"
                    icon="create-outline"
                  />
                </View>
                <View style={styles.actionButtonHalf}>
                  <Button
                    title="Delete"
                    onPress={handleDelete}
                    variant="danger"
                    icon="trash-outline"
                    loading={isDeleting}
                  />
                </View>
              </View>
            ) : (
              // Buyer actions - stacked vertically like iOS
              <>
                {/* Buy Now Button - First */}
                <Pressable
                  style={({ pressed }) => [
                    styles.fullWidthButton,
                    { backgroundColor: colors.success, opacity: pressed ? 0.9 : 1 },
                    Shadows.md,
                  ]}
                  onPress={isSeek ? handleMakeOffer : handleBuyNow}
                >
                  <Ionicons name="cart" size={20} color={colors.textInverse} style={{ marginRight: 8 }} />
                  <Text style={[styles.buyButtonText, { color: colors.textInverse }]}>
                    {isSeek ? 'Offer My Item' : listing.listing_type === 'service' ? 'Book Now' : 'Buy Now'}
                  </Text>
                </Pressable>

                {/* Make Offer Button - Second (if applicable) */}
                {listing.accepts_offers && !isSeek && (
                  <Pressable
                    style={({ pressed }) => [
                      styles.fullWidthButton,
                      { backgroundColor: colors.primary, opacity: pressed ? 0.9 : 1 },
                      Shadows.md,
                    ]}
                    onPress={handleMakeOffer}
                  >
                    <Ionicons name="pricetag" size={20} color={colors.textInverse} style={{ marginRight: 8 }} />
                    <Text style={[styles.buyButtonText, { color: colors.textInverse }]}>
                      Make Offer
                    </Text>
                  </Pressable>
                )}

                {/* Contact Seller Button - Third */}
                <Pressable
                  style={({ pressed }) => [
                    styles.outlineButton,
                    { borderColor: colors.primary, opacity: pressed ? 0.8 : 1 },
                  ]}
                  onPress={handleMessage}
                >
                  <Ionicons name="chatbubble" size={20} color={colors.primary} style={{ marginRight: 8 }} />
                  <Text style={[styles.outlineButtonText, { color: colors.primary }]}>
                    Contact {isSeek ? 'Seeker' : 'Seller'}
                  </Text>
                </Pressable>
              </>
            )}
          </View>
        </View>
      </ScrollView>

      {/* Dropdown Menu */}
      {showMenuModal && (
        <>
          <Pressable 
            style={styles.dropdownOverlay}
            onPress={() => setShowMenuModal(false)}
          />
          <View style={[styles.dropdownMenu, { backgroundColor: colors.surface }]}>
            <TouchableOpacity
              style={styles.menuItem}
              onPress={handleReport}
            >
              <Text style={[styles.menuItemText, { color: colors.textPrimary }]}>Report</Text>
              <Ionicons name="flag-outline" size={20} color={colors.textPrimary} />
            </TouchableOpacity>
            
            <View style={[styles.menuDivider, { backgroundColor: colors.border }]} />
            
            <TouchableOpacity
              style={styles.menuItem}
              onPress={handleBlockUser}
            >
              <Text style={[styles.menuItemText, { color: colors.error }]}>Block User</Text>
              <Ionicons name="hand-left-outline" size={20} color={colors.error} />
            </TouchableOpacity>
          </View>
        </>
      )}

      {/* Report Modal */}
      <ReportUserModal
        visible={showReportModal}
        onClose={() => setShowReportModal(false)}
        reportedUserId={listing?.user_id}
        reportedUserName={listing?.user?.name}
        reportedListingId={listing?.id}
        reportedListingTitle={listing?.title}
        onBlockUser={handleBlockUser}
      />

      {/* Payment Method Sheet */}
      {listing && (
        <PaymentMethodSheet
          visible={showPaymentMethodSheet}
          listing={listing}
          onClose={() => setShowPaymentMethodSheet(false)}
          onPaymentMethodSelected={handlePaymentMethodSelected}
        />
      )}

      {/* Payment Processing - Listing remains visible in background while payment sheet is configured */}

      {/* Make Offer Sheet */}
      <MakeOfferSheet
        visible={showMakeOfferSheet}
        listing={listing}
        onClose={() => setShowMakeOfferSheet(false)}
        onSubmit={handleSubmitOffer}
      />

      {/* Purchase Confirmation Modal */}
      {listing && createdOrder && (
        <PurchaseConfirmationModal
          visible={showPurchaseConfirmation}
          listing={listing}
          order={createdOrder}
          paymentMethod="card"
          onClose={() => {
            setShowPurchaseConfirmation(false);
            setCreatedOrder(null);
          }}
          onViewOrder={() => {
            setShowPurchaseConfirmation(false);
            setCreatedOrder(null);
            navigation.navigate('Wallet', {
              screen: 'OrderDetail',
              params: { orderId: createdOrder.id }
            });
          }}
          onContactSeller={async () => {
            setShowPurchaseConfirmation(false);
            setCreatedOrder(null);
            try {
              const conversation = await getOrCreateConversation(listing.id, listing.user_id);
              navigation.navigate('Messages', {
                screen: 'Chat',
                params: { conversationId: conversation.id }
              });
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to start conversation.');
            }
          }}
        />
      )}

      {/* Share Listing Sheet - Snapchat/Instagram/etc */}
      {listing && (
        <ShareListingSheet
          visible={showShareSheet}
          onClose={() => setShowShareSheet(false)}
          listingId={listing.id}
          listingTitle={listing.title}
          listingDescription={listing.description || ''}
          listingPrice={formatPrice()}
          listingImageUrl={listing.photos?.[0] || listing.photo}
        />
      )}
    </SafeAreaView>
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
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.xs,
    borderBottomWidth: 1,
  },
  headerButton: {
    padding: Spacing.sm,
  },
  headerButtonText: {
    ...Typography.body,
    fontSize: 17,
  },
  headerActions: {
    flexDirection: 'row',
    gap: Spacing.md,
    alignItems: 'center',
  },
  headerIconButton: {
    padding: Spacing.sm,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.lg,
    padding: Spacing.xl,
  },
  errorText: {
    ...Typography.headline,
    textAlign: 'center',
  },
  scrollContent: {
    paddingBottom: 100, // Space for tab bar
  },
  content: {
    padding: Spacing.lg,
    gap: Spacing.xl,
  },
  titleSection: {
    gap: Spacing.sm,
  },
  title: {
    ...Typography.title1,
  },
  price: {
    ...Typography.priceLarge,
  },
  badgeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
    marginTop: Spacing.xs,
  },
  badge: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.md,
  },
  badgeText: {
    ...Typography.footnote,
    fontWeight: '500',
  },
  section: {
    gap: Spacing.sm,
  },
  serviceCard: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
    gap: Spacing.md,
  },
  sectionTitle: {
    ...Typography.headline,
  },
  description: {
    ...Typography.body,
    lineHeight: 24,
  },
  sellerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
    gap: Spacing.md,
  },
  sellerInfo: {
    flex: 1,
    gap: 4,
  },
  sellerName: {
    ...Typography.headline,
  },
  sellerCampus: {
    ...Typography.footnote,
  },
  sellerDate: {
    ...Typography.caption2,
  },
  detailsCard: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.xs,
    gap: Spacing.sm,
  },
  detailIcon: {
    width: 20,
  },
  detailLabel: {
    ...Typography.subheadline,
    flex: 1,
  },
  detailValue: {
    ...Typography.subheadlineBold,
  },
  actionsSection: {
    gap: Spacing.md,
    marginTop: Spacing.lg,
  },
  actionRow: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  actionButtonHalf: {
    flex: 1,
  },
  fullWidthButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md + 2,
    paddingHorizontal: Spacing.lg,
    borderRadius: BorderRadius.lg,
  },
  outlineButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md + 2,
    paddingHorizontal: Spacing.lg,
    borderRadius: BorderRadius.lg,
    borderWidth: 2,
  },
  buyButtonText: {
    ...Typography.button,
    fontSize: 17,
    fontWeight: '600',
  },
  outlineButtonText: {
    ...Typography.button,
    fontSize: 17,
    fontWeight: '600',
  },
  dropdownOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  dropdownMenu: {
    position: 'absolute',
    top: 55,
    right: 12,
    width: 180,
    backgroundColor: '#ffffff',
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 5,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    paddingHorizontal: 16,
  },
  menuItemText: {
    fontSize: 16,
    fontWeight: '400',
  },
  menuDivider: {
    height: 1,
  },
});

export default ListingDetailScreen;
