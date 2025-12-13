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
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { 
  Button, 
  OrderStatusBadge, 
  UserAvatar, 
  LoadingSpinner 
} from '../../components';
import { 
  getOrder, 
  acceptOrder, 
  markDelivered, 
  confirmDelivery, 
  cancelOrder,
  verifyServicePin 
} from '../../services/orderService';
import { supabase } from '../../config/supabase';
import { Order, OrderStatus, OrderStatusDisplay } from '../../types';
import Colors from '../../utils/colors';

type RouteParams = {
  OrderDetail: { orderId: string };
};

const OrderDetailScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const route = useRoute<RouteProp<RouteParams, 'OrderDetail'>>();
  const { orderId } = route.params;

  const [order, setOrder] = useState<Order | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isProcessing, setIsProcessing] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [pinCode, setPinCode] = useState('');
  const [showPinInput, setShowPinInput] = useState(false);

  useEffect(() => {
    loadUserId();
    loadOrder();
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

  const handleAcceptOrder = async () => {
    if (!order) return;
    setIsProcessing(true);
    try {
      await acceptOrder(order.id);
      await loadOrder();
      Alert.alert('Success', 'Order accepted! Please proceed with delivery.');
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to accept order');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleMarkDelivered = async () => {
    if (!order) return;
    setIsProcessing(true);
    try {
      await markDelivered(order.id, '');
      await loadOrder();
      Alert.alert('Success', 'Order marked as delivered!');
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to mark as delivered');
    } finally {
      setIsProcessing(false);
    }
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
              Alert.alert('Success', 'Thank you! Transaction completed.');
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
      Alert.alert('Success', 'Service completed successfully!');
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
              Alert.alert('Cancelled', 'Order has been cancelled.');
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

  // Render action buttons based on order status and user role
  const renderActions = () => {
    if (!order) return null;

    const actions: React.ReactNode[] = [];

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

    // Cancel option (for certain statuses)
    if ((order.status === 'placed' || order.status === 'seller_confirmed') && (isBuyer || isSeller)) {
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

    return actions.length > 0 ? (
      <View style={styles.actionsContainer}>{actions}</View>
    ) : null;
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
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
            <Ionicons name="chevron-back" size={28} color={Colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Order Details</Text>
          <View style={styles.backButton} />
        </View>

        {/* Status Banner */}
        <View style={styles.statusBanner}>
          <OrderStatusBadge status={order.status} size="large" />
          <Text style={styles.statusDate}>
            {formatDate(order.updated_at || order.created_at)}
          </Text>
        </View>

        {/* Listing Info */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Item</Text>
          <View style={styles.listingCard}>
            {order.listing?.photo && (
              <Image source={{ uri: order.listing.photo }} style={styles.listingImage} />
            )}
            <View style={styles.listingInfo}>
              <Text style={styles.listingTitle}>{order.listing?.title || 'Unknown'}</Text>
              <Text style={styles.listingCategory}>{order.listing?.category}</Text>
            </View>
          </View>
        </View>

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
              <Text style={styles.summaryValue}>${order.subtotal.toFixed(2)}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Service Fee</Text>
              <Text style={styles.summaryValue}>${order.service_fee.toFixed(2)}</Text>
            </View>
            <View style={styles.divider} />
            <View style={styles.summaryRow}>
              <Text style={styles.totalLabel}>Total</Text>
              <Text style={styles.totalValue}>${order.total_amount.toFixed(2)}</Text>
            </View>
          </View>
        </View>

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
                onPress={() => {
                  // Navigate to chat with this user
                  navigation.navigate('Messages');
                }}
              >
                <Ionicons name="chatbubble-outline" size={16} color={Colors.primary} />
                <Text style={styles.messageButtonText}>Message</Text>
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 8,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  backButton: {
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  statusBanner: {
    alignItems: 'center',
    paddingVertical: 24,
    backgroundColor: Colors.surfaceSecondary,
  },
  statusDate: {
    fontSize: 13,
    color: Colors.textSecondary,
    marginTop: 8,
  },
  section: {
    padding: 16,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginBottom: 12,
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
});

export default OrderDetailScreen;
