// OrderDetailScreen - Full order details with actions
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  Alert,
  TextInput,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as ImagePicker from 'expo-image-picker';
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator';
import { decode } from 'base64-arraybuffer';
import { 
  Button, 
  OrderStatusBadge, 
  UserAvatar, 
  LoadingSpinner,
  CircularProgress,
  UnifiedHeader
} from '../../components';
import { 
  getOrder, 
  acceptOrder, 
  markDelivered, 
  confirmDelivery, 
  cancelOrder,
  verifyServicePin,
  updateOrderPaymentStatus
} from '../../services/orderService';
import { normalizeOrder } from '../../types';
import {
  configurePaymentSheetForOrder,
  presentStripePaymentSheet,
} from '../../services/stripeService';
import {
  formattedTimeRemaining,
  getDeadlineColor,
  getDeadlineProgress,
  isNearDeadline,
  isPastDeadline,
  formatDeadlineDate,
} from '../../services/activeOrderMonitor';
import { getOrCreateConversationForOrder } from '../../services/messagingService';
import { useOrderMonitor } from '../../context/OrderMonitorContext';
import { supabase } from '../../config/supabase';
import { Order, OrderStatus, OrderStatusDisplay, getEscrowStatus } from '../../types';
import Colors from '../../utils/colors';

type RouteParams = {
  OrderDetail: { orderId: string };
};

const OrderDetailScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const route = useRoute<RouteProp<RouteParams, 'OrderDetail'>>();
  const { orderId } = route.params;
  const { refreshActiveOrders } = useOrderMonitor();

  const [order, setOrder] = useState<Order | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isProcessing, setIsProcessing] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [pinCode, setPinCode] = useState('');
  const [showPinInput, setShowPinInput] = useState(false);
  const [isUploadingPhoto, setIsUploadingPhoto] = useState(false);
  const [isLoadingConversation, setIsLoadingConversation] = useState(false);
  const [showSuccessOverlay, setShowSuccessOverlay] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

  useEffect(() => {
    loadUserId();
    loadOrder();
    
    // Set up realtime subscription for order updates
    const channel = supabase
      .channel(`order:${orderId}`)
      .on(
        'postgres_changes',
        { 
          event: 'UPDATE', 
          schema: 'public', 
          table: 'orders',
          filter: `id=eq.${orderId}`
        },
        (payload) => {
          console.log('📡 Order updated via realtime:', payload.new);
          // Normalize the order data to ensure status alias is set
          const normalizedOrder = normalizeOrder(payload.new);
          // Preserve existing listing/buyer/seller relations from current order
          setOrder(prev => prev ? { 
            ...normalizedOrder, 
            listing: prev.listing,
            buyer: prev.buyer,
            seller: prev.seller,
          } : normalizedOrder);
        }
      )
      .subscribe();

    // Cleanup subscription
    return () => {
      supabase.removeChannel(channel);
    };
  }, [orderId]);

  const loadUserId = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    setCurrentUserId(session?.user.id ?? null);
  };

  const loadOrder = async () => {
    try {
      const data = await getOrder(orderId);
      setOrder(data);
    } catch (error) {
      console.error('Error loading order:', error);
      Alert.alert('Error', 'Failed to load order details');
      navigation.goBack();
    } finally {
      setIsLoading(false);
    }
  };

  const isBuyer = currentUserId === order?.buyer_id;
  const isSeller = currentUserId === order?.seller_id;
  const isService = order?.listing?.listing_type === 'service';

  const showSuccess = (message: string) => {
    setSuccessMessage(message);
    setShowSuccessOverlay(true);
    // Refresh the active order count in the context
    refreshActiveOrders();
  };

  const handleAcceptOrder = async () => {
    if (!order) return;
    setIsProcessing(true);
    try {
      await acceptOrder(order.id);
      await loadOrder();
      showSuccess('Order accepted! Please proceed with delivery.');
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to accept order');
    } finally {
      setIsProcessing(false);
    }
  };

  const pickDeliveryPhoto = async (source: 'camera' | 'library'): Promise<string | null> => {
    try {
      // Request appropriate permissions
      if (source === 'camera') {
        const { status } = await ImagePicker.requestCameraPermissionsAsync();
        if (status !== 'granted') {
          Alert.alert('Permission Required', 'Please allow access to your camera');
          return null;
        }
      } else {
        const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
        if (status !== 'granted') {
          Alert.alert('Permission Required', 'Please allow access to your photo library');
          return null;
        }
      }

      // Launch camera or image picker
      const result = source === 'camera'
        ? await ImagePicker.launchCameraAsync({
            mediaTypes: ImagePicker.MediaTypeOptions.Images,
            allowsEditing: true,
            aspect: [4, 3],
            quality: 0.8,
          })
        : await ImagePicker.launchImageLibraryAsync({
            mediaTypes: ImagePicker.MediaTypeOptions.Images,
            allowsEditing: true,
            aspect: [4, 3],
            quality: 0.8,
          });

      if (result.canceled || !result.assets[0]) {
        return null;
      }

      // Upload to Supabase storage
      setIsUploadingPhoto(true);
      const asset = result.assets[0];
      const fileName = `delivery_${order?.id}_${Date.now()}.jpg`;
      
      console.log('📸 Processing delivery photo for upload...');
      
      // Use expo-image-manipulator to resize and get base64 (same approach as imageUploadService)
      const manipResult = await manipulateAsync(
        asset.uri,
        [{ resize: { width: 1080, height: 1080 } }],
        { compress: 0.7, format: SaveFormat.JPEG, base64: true }
      );

      if (!manipResult.base64) {
        throw new Error('Failed to process image');
      }

      // Convert base64 to ArrayBuffer for upload (React Native compatible)
      const arrayBuffer = decode(manipResult.base64);

      const { data, error } = await supabase.storage
        .from('delivery-photos')
        .upload(fileName, arrayBuffer, {
          contentType: 'image/jpeg',
          upsert: false,
        });

      if (error) throw error;

      console.log('✅ Delivery photo uploaded successfully');

      // Get public URL
      const { data: urlData } = supabase.storage
        .from('delivery-photos')
        .getPublicUrl(data.path);

      return urlData.publicUrl;
    } catch (error) {
      console.error('Error uploading photo:', error);
      Alert.alert('Error', 'Failed to upload photo');
      return null;
    } finally {
      setIsUploadingPhoto(false);
    }
  };

  const handleMarkDelivered = async () => {
    if (!order) return;
    
    // Helper to complete delivery with optional photo
    const completeDelivery = async (photoUrl: string) => {
      setIsProcessing(true);
      try {
        await markDelivered(order.id, photoUrl);
        await loadOrder();
        showSuccess('Order marked as delivered! Waiting for buyer to confirm receipt.');
      } catch (error: any) {
        Alert.alert('Error', error.message || 'Failed to mark as delivered');
      } finally {
        setIsProcessing(false);
      }
    };

    // Prompt for delivery photo with camera and library options
    Alert.alert(
      'Add Delivery Photo',
      'Would you like to add a photo as proof of delivery?',
      [
        {
          text: 'Skip',
          style: 'cancel',
          onPress: () => completeDelivery(''),
        },
        {
          text: 'Take Photo',
          onPress: async () => {
            const photoUrl = await pickDeliveryPhoto('camera');
            if (photoUrl) {
              await completeDelivery(photoUrl);
            }
          },
        },
        {
          text: 'Choose from Library',
          onPress: async () => {
            const photoUrl = await pickDeliveryPhoto('library');
            if (photoUrl) {
              await completeDelivery(photoUrl);
            }
          },
        },
      ]
    );
  };

  const handleConfirmDelivery = async () => {
    if (!order) return;
    
    Alert.alert(
      'Confirm Receipt',
      'Are you sure you received the item? This will release funds to the seller.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Confirm',
          onPress: async () => {
            setIsProcessing(true);
            try {
              await confirmDelivery(order.id);
              await loadOrder();
              showSuccess('Transaction completed! Funds have been released to the seller.');
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to confirm delivery');
            } finally {
              setIsProcessing(false);
            }
          },
        },
      ]
    );
  };

  const handleVerifyPin = async () => {
    if (!order || !pinCode || pinCode.length !== 4) {
      Alert.alert('Error', 'Please enter a valid 4-digit PIN');
      return;
    }
    
    setIsProcessing(true);
    try {
      await verifyServicePin(order.id, pinCode);
      await loadOrder();
      showSuccess('Service completed successfully! Funds have been released.');
      setShowPinInput(false);
      setPinCode('');
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to verify PIN');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCancelOrder = async () => {
    if (!order) return;
    
    Alert.alert(
      'Cancel Order',
      'Are you sure you want to cancel this order?',
      [
        { text: 'No', style: 'cancel' },
        {
          text: 'Yes, Cancel',
          style: 'destructive',
          onPress: async () => {
            setIsProcessing(true);
            try {
              await cancelOrder(order.id);
              await loadOrder();
              showSuccess('Order has been cancelled. The full amount has been refunded.');
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to cancel order');
            } finally {
              setIsProcessing(false);
            }
          },
        },
      ]
    );
  };

  const handlePayNow = async () => {
    if (!order) return;
    
    setIsProcessing(true);
    try {
      // Configure PaymentSheet for this order
      console.log('💳 Configuring payment for order:', order.id);
      const paymentIntent = await configurePaymentSheetForOrder(order.id);
      
      // Present PaymentSheet
      const result = await presentStripePaymentSheet();
      
      if (result.success) {
        // Update order payment status
        await updateOrderPaymentStatus(order.id, paymentIntent.payment_intent_id);
        await loadOrder();
        
        // Show success overlay
        showSuccess('Payment completed! Your order has been confirmed. The seller will be notified.');
      } else if (result.error !== 'Payment cancelled') {
        // Show error if not cancelled by user
        Alert.alert('Payment Failed', result.error || 'An error occurred during payment');
      }
    } catch (error: any) {
      console.error('Error processing payment:', error);
      Alert.alert('Error', error.message || 'Failed to process payment');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleContactUser = async () => {
    if (!order) return;

    setIsLoadingConversation(true);
    try {
      // Get or create conversation for this order
      // Matches iOS OrderDetailView.loadConversation() logic
      const conversation = await getOrCreateConversationForOrder(
        order.id,
        order.listing_id,
        order.buyer_id,
        order.seller_id
      );

      if (!conversation) {
        throw new Error('Failed to load conversation');
      }

      // Navigate to Messages tab, then to Chat screen
      // @ts-ignore - navigating across tabs requires accessing parent navigator
      navigation.navigate('Messages', {
        screen: 'Chat',
        params: {
          conversationId: conversation.id,
          returnScreen: 'OrderDetail',
          returnParams: { orderId: order.id },
        },
      });
    } catch (error: any) {
      console.error('Error loading conversation:', error);
      Alert.alert('Error', error.message || 'Failed to open conversation');
    } finally {
      setIsLoadingConversation(false);
    }
  };

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

  const formatDateShort = (dateStr: string): string => {
    return new Date(dateStr).toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  // Check if order should show deadline indicator
  const shouldShowDeadlineIndicator = (): boolean => {
    if (!order) return false;
    const activeStatuses: OrderStatus[] = ['placed', 'seller_confirmed', 'in_progress'];
    return activeStatuses.includes(order.order_status);
  };

  // Render deadline indicator
  const renderDeadlineIndicator = () => {
    if (!order || !shouldShowDeadlineIndicator()) return null;

    const nearDeadline = isNearDeadline(order);
    const pastDeadline = isPastDeadline(order);
    const timeRemaining = formattedTimeRemaining(order);
    const deadlineDate = formatDeadlineDate(order);
    const color = getDeadlineColor(order);
    const progress = getDeadlineProgress(order);

    const iconName = pastDeadline 
      ? 'warning' 
      : nearDeadline 
      ? 'time-outline' 
      : 'time';

    const bgColor = pastDeadline 
      ? '#FEE2E2' 
      : nearDeadline 
      ? '#FED7AA' 
      : '#DBEAFE';

    return (
      <View style={[styles.deadlineContainer, { backgroundColor: bgColor }]}>
        <Ionicons name={iconName} size={24} color={color} />
        <View style={styles.deadlineTextContainer}>
          <Text style={styles.deadlineLabel}>
            {pastDeadline ? 'Deadline Expired' : 'Complete by'}
          </Text>
          {pastDeadline ? (
            <Text style={[styles.deadlineValue, { color: '#EF4444' }]}>
              Order will be auto-cancelled
            </Text>
          ) : (
            <Text style={[styles.deadlineValue, nearDeadline && { color: '#F97316' }]}>
              {deadlineDate} • {timeRemaining}
            </Text>
          )}
        </View>
        {!pastDeadline && (
          <CircularProgress
            progress={progress}
            color={color}
            size={36}
            strokeWidth={3}
          />
        )}
      </View>
    );
  };

  // Render order timeline
  const renderTimeline = () => {
    if (!order) return null;

    const steps = [
      {
        title: 'Order Placed',
        subtitle: 'Order created and payment processed',
        isCompleted: true,
        date: order.created_at,
      },
      {
        title: 'Seller Confirmed',
        subtitle: 'Seller has marked as delivered',
        isCompleted: ['seller_confirmed', 'completed'].includes(order.order_status),
        date: order.seller_confirmed_at,
      },
      {
        title: 'Buyer Confirmed',
        subtitle: 'Buyer has confirmed receipt',
        isCompleted: order.order_status === 'completed',
        date: order.completed_at,
      },
      {
        title: 'Completed',
        subtitle: 'Order delivered and funds released',
        isCompleted: order.order_status === 'completed',
        date: order.completed_at,
      },
    ];

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Order Timeline</Text>
        <View style={styles.timelineCard}>
          {steps.map((step, index) => (
            <View key={index} style={styles.timelineStep}>
              <View style={styles.timelineIndicatorContainer}>
                <View
                  style={[
                    styles.timelineIndicator,
                    step.isCompleted && styles.timelineIndicatorCompleted,
                  ]}
                />
                {index < steps.length - 1 && (
                  <View
                    style={[
                      styles.timelineLine,
                      step.isCompleted && styles.timelineLineCompleted,
                    ]}
                  />
                )}
              </View>
              <View style={styles.timelineContent}>
                <Text
                  style={[
                    styles.timelineTitle,
                    !step.isCompleted && styles.timelineTitleIncomplete,
                  ]}
                >
                  {step.title}
                </Text>
                <Text style={styles.timelineSubtitle}>{step.subtitle}</Text>
                {step.date && (
                  <Text style={styles.timelineDate}>{formatDateShort(step.date)}</Text>
                )}
              </View>
            </View>
          ))}
        </View>
      </View>
    );
  };

  // Render escrow status
  const renderEscrowStatus = () => {
    if (!order) return null;

    const escrowStatus = getEscrowStatus(order);
    const isReleased = order.order_status === 'completed';
    
    // Status badge color
    const statusColor = isReleased ? '#22C55E' : '#3B82F6';
    const statusBgColor = isReleased ? '#22C55E20' : '#3B82F620';

    return (
      <View style={styles.section}>
        <View style={styles.escrowCard}>
          {/* Header with icon and status badge */}
          <View style={styles.escrowHeader}>
            <View style={styles.escrowTitleRow}>
              <Ionicons name="shield-checkmark" size={24} color="#22C55E" />
              <Text style={styles.escrowTitle}>Escrow Protection</Text>
            </View>
            <View style={[styles.statusBadge, { backgroundColor: statusBgColor }]}>
              <Text style={[styles.statusBadgeText, { color: statusColor }]}>
                {isReleased ? 'Released' : 'Active'}
              </Text>
            </View>
          </View>

          {/* Escrow details card */}
          <View style={styles.escrowDetailsCard}>
            <View style={styles.escrowDetailRow}>
              <Text style={styles.escrowDetailLabel}>Release Status:</Text>
              <Text style={[styles.escrowDetailValue, { color: statusColor }]}>{escrowStatus}</Text>
            </View>
          </View>

          {/* Info text */}
          <Text style={styles.escrowInfoText}>
            {isReleased
              ? 'Funds have been automatically released to the seller upon order completion.'
              : 'Funds are held securely in escrow until delivery is confirmed by the buyer.'}
          </Text>
        </View>
      </View>
    );
  };

  // Render action buttons based on order status and user role
  const renderActions = () => {
    if (!order) return null;

    const actions: React.ReactNode[] = [];

    // Buyer payment required
    if (isBuyer && order.payment_status === 'pending') {
      actions.push(
        <View key="payment-banner" style={styles.paymentBanner}>
          <Ionicons name="card-outline" size={24} color={Colors.warning} />
          <View style={styles.paymentBannerContent}>
            <Text style={styles.paymentBannerTitle}>Payment Required</Text>
            <Text style={styles.paymentBannerMessage}>
              Complete your payment to confirm this order
            </Text>
          </View>
        </View>
      );
      actions.push(
        <Button
          key="pay-now"
          title="Confirm Order & Pay"
          onPress={handlePayNow}
          icon="card"
          loading={isProcessing}
        />
      );
    }

    // Seller actions
    if (isSeller) {
      if (order.status === 'placed') {
        actions.push(
          <Button
            key="accept"
            title="Accept Order"
            onPress={handleAcceptOrder}
            icon="checkmark-circle"
            loading={isProcessing}
          />
        );
      }
      
      if (order.status === 'seller_confirmed' || order.status === 'in_progress') {
        if (isService) {
          actions.push(
            <View key="pin-section" style={styles.pinSection}>
              <Text style={styles.pinLabel}>Enter buyer's 4-digit PIN to complete:</Text>
              <View style={styles.pinInputRow}>
                <TextInput
                  style={styles.pinInput}
                  value={pinCode}
                  onChangeText={setPinCode}
                  placeholder="0000"
                  placeholderTextColor={Colors.textTertiary}
                  keyboardType="number-pad"
                  maxLength={4}
                />
                <Button
                  title="Verify"
                  onPress={handleVerifyPin}
                  loading={isProcessing}
                  disabled={pinCode.length !== 4}
                  fullWidth={false}
                  style={{ flex: 1 }}
                />
              </View>
            </View>
          );
        } else {
          actions.push(
            <Button
              key="delivered"
              title="Mark as Delivered"
              onPress={handleMarkDelivered}
              icon="checkmark-done"
              loading={isProcessing}
            />
          );
        }
      }
    }

    // Buyer actions
    if (isBuyer) {
      if (order.status === 'seller_confirmed') {
        actions.push(
          <Button
            key="confirm"
            title="Confirm Received"
            onPress={handleConfirmDelivery}
            icon="checkmark-circle"
            variant="success"
            loading={isProcessing}
          />
        );
      }

      // Show PIN for services
      if (isService && order.service_pin && order.status !== 'completed') {
        actions.push(
          <View key="show-pin" style={styles.pinDisplay}>
            <Text style={styles.pinDisplayLabel}>Your PIN Code:</Text>
            <Text style={styles.pinDisplayCode}>{order.service_pin}</Text>
            <Text style={styles.pinDisplayHint}>Share this with the seller when service is complete</Text>
          </View>
        );
      }
    }

    // Cancel option (only when order is placed, not after seller confirmation)
    if (order.status === 'placed' && (isBuyer || isSeller)) {
      actions.push(
        <Button
          key="cancel"
          title="Cancel Order"
          onPress={handleCancelOrder}
          variant="danger"
          icon="close-circle"
          loading={isProcessing}
        />
      );
    }

    // Report Problem button (for active orders)
    if (order.status !== 'completed' && order.status !== 'cancelled') {
      actions.push(
        <TouchableOpacity
          key="report"
          style={styles.reportButton}
          onPress={() => {
            Alert.alert(
              'Report a Problem',
              'If you\'re experiencing issues with this order, please contact support.',
              [
                { text: 'Cancel', style: 'cancel' },
                { 
                  text: 'Contact Support', 
                  onPress: () => {
                    // Navigate to support or open email
                    Alert.alert('Support', 'Please email support@campuslink.app with your order ID.');
                  }
                },
              ]
            );
          }}
        >
          <Ionicons name="warning-outline" size={20} color={Colors.warning} />
          <Text style={styles.reportButtonText}>Report Problem</Text>
        </TouchableOpacity>
      );
    }

    return actions.length > 0 ? (
      <View style={styles.actionsContainer}>{actions}</View>
    ) : null;
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
          <View style={styles.successActions}>
            <TouchableOpacity
              style={styles.successButton}
              onPress={() => {
                setShowSuccessOverlay(false);
                navigation.goBack();
              }}
            >
              <Text style={styles.successButtonText}>Done</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.successButtonSecondary}
              onPress={() => setShowSuccessOverlay(false)}
            >
              <Text style={styles.successButtonSecondaryText}>View Order Details</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    );
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading order..." />;
  }

  if (!order) {
    return (
      <SafeAreaView style={styles.container}>
        <Text>Order not found</Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      <UnifiedHeader title="Order Details" />
      
      {/* Success Overlay */}
      {renderSuccessOverlay()}
      
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
        {/* Listing Info */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Item</Text>
            <OrderStatusBadge status={order.status} size="small" />
          </View>
          <View style={styles.listingCard}>
            {(order.listing?.photos?.[0] || order.listing?.photo) && (
              <Image 
                source={{ uri: order.listing?.photos?.[0] || order.listing?.photo }} 
                style={styles.listingImage} 
              />
            )}
            <View style={styles.listingInfo}>
              <Text style={styles.listingTitle}>{order.listing?.title || 'Unknown'}</Text>
              <Text style={styles.listingCategory}>{order.listing?.category}</Text>
              <Text style={styles.orderDate}>{formatDate(order.updated_at || order.created_at)}</Text>
            </View>
          </View>
        </View>

        {/* Deadline Indicator */}
        {renderDeadlineIndicator()}

        {/* Order Timeline */}
        {renderTimeline()}

        {/* Order Summary */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Order Summary</Text>
          <View style={styles.summaryCard}>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Quantity</Text>
              <Text style={styles.summaryValue}>{order.quantity}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Subtotal</Text>
              <Text style={styles.summaryValue}>${((order.seller_price_cents || order.price_cents || 0) / 100).toFixed(2)}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Service Fee</Text>
              <Text style={styles.summaryValue}>
                ${(((order.buyer_price_cents || order.price_cents || 0) - (order.seller_price_cents || order.price_cents || 0)) / 100).toFixed(2)}
              </Text>
            </View>
            <View style={styles.divider} />
            <View style={styles.summaryRow}>
              <Text style={styles.totalLabel}>Total</Text>
              <Text style={styles.totalValue}>${((order.buyer_price_cents || order.price_cents || 0) / 100).toFixed(2)}</Text>
            </View>
          </View>
        </View>

        {/* Escrow Status */}
        {renderEscrowStatus()}

        {/* Parties */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{isBuyer ? 'Seller' : 'Buyer'}</Text>
          <View style={styles.partyCard}>
            <UserAvatar user={(isBuyer ? order.seller : order.buyer) ?? null} size={48} />
            <View style={styles.partyInfo}>
              <Text style={styles.partyName}>
                {(isBuyer ? order.seller?.name : order.buyer?.name) || 'Unknown'}
              </Text>
              <TouchableOpacity 
                style={styles.messageButton}
                onPress={handleContactUser}
                disabled={isLoadingConversation}
              >
                {isLoadingConversation ? (
                  <ActivityIndicator size="small" color={Colors.primary} />
                ) : (
                  <>
                    <Ionicons name="chatbubble-outline" size={16} color={Colors.primary} />
                    <Text style={styles.messageButtonText}>
                      {isBuyer ? 'Contact Seller' : 'Contact Buyer'}
                    </Text>
                  </>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>

        {/* Delivery Photo */}
        {order.delivery_photo && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Delivery Photo</Text>
            <Image source={{ uri: order.delivery_photo }} style={styles.deliveryPhoto} />
          </View>
        )}

        {/* Actions */}
        {renderActions()}
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
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textSecondary,
  },
  listingCard: {
    flexDirection: 'row',
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
    width: 80,
    height: 80,
    borderRadius: 8,
  },
  listingInfo: {
    flex: 1,
    marginLeft: 12,
    justifyContent: 'center',
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
  orderDate: {
    fontSize: 12,
    color: Colors.textTertiary,
  },
  summaryCard: {
    backgroundColor: Colors.surface,
    borderRadius: 12,
    padding: 16,
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  summaryLabel: {
    fontSize: 14,
    color: Colors.textSecondary,
  },
  summaryValue: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.textPrimary,
  },
  divider: {
    height: 1,
    backgroundColor: Colors.border,
    marginVertical: 8,
  },
  totalLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  totalValue: {
    fontSize: 18,
    fontWeight: '700',
    color: Colors.primary,
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
    marginBottom: 4,
  },
  messageButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  messageButtonText: {
    fontSize: 14,
    color: Colors.primary,
    fontWeight: '500',
  },
  deliveryPhoto: {
    width: '100%',
    height: 200,
    borderRadius: 12,
  },
  actionsContainer: {
    padding: 16,
    gap: 12,
  },
  pinSection: {
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    padding: 16,
  },
  pinLabel: {
    fontSize: 14,
    color: Colors.textSecondary,
    marginBottom: 12,
  },
  pinInputRow: {
    flexDirection: 'row',
    gap: 12,
  },
  pinInput: {
    flex: 1,
    backgroundColor: Colors.background,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 24,
    fontWeight: '700',
    textAlign: 'center',
    color: Colors.textPrimary,
    letterSpacing: 8,
  },
  pinDisplay: {
    backgroundColor: Colors.primary + '10',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  pinDisplayLabel: {
    fontSize: 14,
    color: Colors.textSecondary,
    marginBottom: 8,
  },
  pinDisplayCode: {
    fontSize: 32,
    fontWeight: '700',
    color: Colors.primary,
    letterSpacing: 8,
  },
  pinDisplayHint: {
    fontSize: 12,
    color: Colors.textTertiary,
    marginTop: 8,
    textAlign: 'center',
  },
  // Deadline Indicator Styles
  deadlineContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 16,
    marginVertical: 8,
    padding: 12,
    borderRadius: 12,
    gap: 12,
  },
  deadlineTextContainer: {
    flex: 1,
  },
  deadlineLabel: {
    fontSize: 12,
    color: Colors.textSecondary,
    marginBottom: 2,
  },
  deadlineValue: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  // Timeline Styles
  timelineCard: {
    backgroundColor: Colors.surface,
    borderRadius: 12,
    padding: 16,
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  timelineStep: {
    flexDirection: 'row',
    marginBottom: 16,
  },
  timelineIndicatorContainer: {
    alignItems: 'center',
    marginRight: 12,
  },
  timelineIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: Colors.border,
    borderWidth: 2,
    borderColor: Colors.surface,
  },
  timelineIndicatorCompleted: {
    backgroundColor: '#22C55E',
  },
  timelineLine: {
    width: 2,
    flex: 1,
    backgroundColor: Colors.border,
    marginTop: 4,
  },
  timelineLineCompleted: {
    backgroundColor: '#22C55E',
  },
  timelineContent: {
    flex: 1,
    paddingBottom: 8,
  },
  timelineTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 2,
  },
  timelineTitleIncomplete: {
    color: Colors.textSecondary,
  },
  timelineSubtitle: {
    fontSize: 12,
    color: Colors.textSecondary,
    marginBottom: 2,
  },
  timelineDate: {
    fontSize: 11,
    color: Colors.textTertiary,
  },
  // Escrow Styles
  escrowCard: {
    backgroundColor: Colors.surface,
    borderRadius: 16,
    padding: 16,
    shadowColor: Colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  escrowHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  escrowTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  escrowTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 8,
  },
  statusBadgeText: {
    fontSize: 12,
    fontWeight: '600',
  },
  escrowDetailsCard: {
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
  },
  escrowDetailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  escrowDetailLabel: {
    fontSize: 14,
    color: Colors.textSecondary,
  },
  escrowDetailValue: {
    fontSize: 14,
    fontWeight: '500',
  },
  escrowInfoText: {
    fontSize: 12,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 18,
  },
  // Payment Banner Styles
  paymentBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF7ED',
    borderRadius: 12,
    padding: 16,
    gap: 12,
    borderWidth: 1,
    borderColor: '#FDBA74',
  },
  paymentBannerContent: {
    flex: 1,
  },
  paymentBannerTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#EA580C',
    marginBottom: 4,
  },
  paymentBannerMessage: {
    fontSize: 14,
    color: '#9A3412',
    lineHeight: 18,
  },
  // Report Button Styles
  reportButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderRadius: 12,
    backgroundColor: '#FFF7ED',
    borderWidth: 1,
    borderColor: '#FDBA74',
    gap: 8,
  },
  reportButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#EA580C',
  },
  // Success Overlay Styles
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
  successActions: {
    width: '100%',
    gap: 12,
  },
  successButton: {
    backgroundColor: '#22C55E',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  successButtonText: {
    fontSize: 17,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  successButtonSecondary: {
    backgroundColor: '#F3F4F6',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  successButtonSecondaryText: {
    fontSize: 17,
    fontWeight: '600',
    color: '#374151',
  },
});

export default OrderDetailScreen;
