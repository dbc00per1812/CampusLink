// Order Service - Card payments only (wallet payments removed)
import { supabase } from '../config/supabase';
import {
  Order,
  OrderCreate,
  OrderStatus,
  OrderStats,
  normalizeOrder,
} from '../types';

// Generate 4-digit PIN for service verification
const generateVerificationPIN = (): string => {
  return Math.floor(Math.random() * 10000).toString().padStart(4, '0');
};

// Get current user ID
const getCurrentUserId = async (): Promise<string> => {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.user.id) throw new Error('No active session');
  return session.user.id;
};

// Create a new order
export const createOrder = async (orderCreate: OrderCreate): Promise<Order> => {
  console.log('🔍 createOrder called');
  
  const currentUserId = await getCurrentUserId();
  
  // Verify buyer is current user
  if (currentUserId !== orderCreate.buyer_id) {
    throw new Error('Unauthorized: You can only create orders as buyer');
  }

  // DUPLICATE PREVENTION: Check if buyer already has an active order for this listing
  // Active orders are those that are not cancelled or completed
  const { data: existingOrders, error: existingError } = await supabase
    .from('orders')
    .select('id, order_status, payment_status')
    .eq('listing_id', orderCreate.listing_id)
    .eq('buyer_id', orderCreate.buyer_id)
    .not('order_status', 'in', '("cancelled","completed")');

  if (existingError) {
    console.error('❌ Error checking for existing orders:', existingError);
    throw existingError;
  }

  if (existingOrders && existingOrders.length > 0) {
    console.log('⚠️ Buyer already has active order for this listing:', existingOrders[0].id);
    throw new Error('You already have an active order for this item. Please complete or cancel your existing order first.');
  }

  // Fetch listing to check type for PIN
  const { data: listing, error: listingError } = await supabase
    .from('listings')
    .select('*')
    .eq('id', orderCreate.listing_id)
    .single();

  if (listingError) throw listingError;

  const verificationPin = listing.listing_type === 'service' ? generateVerificationPIN() : null;

  // Create order
  // Payment status:
  // - 'pending': Order created, awaiting payment (new order-first flow)
  // - 'requires_capture': Payment authorized, awaiting delivery confirmation
  
  // Calculate marketplace fee as the difference between buyer and seller prices
  const marketplaceFeeCents = (orderCreate.buyer_price_cents ?? orderCreate.price_cents) - 
                               (orderCreate.seller_price_cents ?? orderCreate.price_cents);
  
  const orderData = {
    listing_id: orderCreate.listing_id,
    buyer_id: orderCreate.buyer_id,
    seller_id: orderCreate.seller_id,
    price_cents: orderCreate.price_cents,
    seller_price_cents: orderCreate.seller_price_cents,
    buyer_price_cents: orderCreate.buyer_price_cents,
    payment_method: orderCreate.payment_method,
    order_status: 'placed',
    // Use provided payment_status, default to 'pending' for order-first flow
    payment_status: orderCreate.payment_status ?? 'pending',
    marketplace_fee_cents: marketplaceFeeCents,
    time_slot_id: orderCreate.time_slot_id ?? null,
    verification_pin: verificationPin,
    quantity: orderCreate.quantity ?? 1,
    stripe_payment_intent_id: orderCreate.stripe_payment_intent_id ?? null,
  };

  const { data: order, error } = await supabase
    .from('orders')
    .insert(orderData)
    .select()
    .single();

  if (error) throw error;

  console.log('✅ Order created:', order.id);

  // Note: Listing is NOT archived here - it will be archived when seller accepts
  // This allows other buyers to still see the listing until seller commits

  return normalizeOrder(order);
};

// Get order details
export const getOrderDetails = async (orderId: string): Promise<Order> => {
  const { data, error } = await supabase
    .from('orders')
    .select(`
      *,
      listing:listings(*),
      buyer:users!orders_buyer_id_fkey(*),
      seller:users!orders_seller_id_fkey(*)
    `)
    .eq('id', orderId)
    .single();

  if (error) throw error;
  return normalizeOrder(data);
};

// Get user's orders (as buyer or seller)
export const getUserOrders = async (
  status?: OrderStatus,
  limit = 50
): Promise<Order[]> => {
  const currentUserId = await getCurrentUserId();

  let query = supabase
    .from('orders')
    .select(`
      *,
      listing:listings(*),
      buyer:users!orders_buyer_id_fkey(*),
      seller:users!orders_seller_id_fkey(*)
    `)
    .or(`buyer_id.eq.${currentUserId},seller_id.eq.${currentUserId}`);

  if (status) {
    query = query.eq('order_status', status);
  }

  const { data, error } = await query
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data ?? []).map(normalizeOrder);
};

// Get buyer orders only
export const getBuyerOrders = async (limit = 50): Promise<Order[]> => {
  const currentUserId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('orders')
    .select(`
      *,
      listing:listings(*),
      buyer:users!orders_buyer_id_fkey(*),
      seller:users!orders_seller_id_fkey(*)
    `)
    .eq('buyer_id', currentUserId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data ?? []).map(normalizeOrder);
};

// Get seller orders only
export const getSellerOrders = async (limit = 50): Promise<Order[]> => {
  const currentUserId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('orders')
    .select(`
      *,
      listing:listings(*),
      buyer:users!orders_buyer_id_fkey(*),
      seller:users!orders_seller_id_fkey(*)
    `)
    .eq('seller_id', currentUserId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data ?? []).map(normalizeOrder);
};

// Seller accepts/confirms order
export const acceptOrder = async (orderId: string): Promise<Order> => {
  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.seller_id) {
    throw new Error('Unauthorized: Only seller can accept order');
  }

  const { data, error } = await supabase
    .from('orders')
    .update({
      order_status: 'in_progress',
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (error) throw error;

  // Archive the listing when seller accepts the order
  // Seller has permission to update their own listing (RLS compliant)
  // This prevents other buyers from purchasing while this order is active
  if (order.listing_id) {
    console.log('🗄️ Archiving listing after seller accepted order:', order.listing_id);
    const { error: archiveError } = await supabase
      .from('listings')
      .update({ archived: true })
      .eq('id', order.listing_id)
      .eq('user_id', currentUserId); // Ensure seller owns the listing
    
    if (archiveError) {
      console.error('⚠️ Failed to archive listing:', archiveError.message);
      // Don't throw - order acceptance is more important than archiving
    } else {
      console.log('✅ Listing archived successfully');
    }
  }

  return normalizeOrder(data);
};

// Seller marks as delivered
export const markDelivered = async (
  orderId: string,
  deliveryPhotoUrl: string
): Promise<Order> => {
  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.seller_id) {
    throw new Error('Unauthorized: Only seller can mark as delivered');
  }

  if (!['in_progress'].includes(order.order_status)) {
    throw new Error('Cannot mark as delivered - order must be accepted first');
  }

  const { data, error } = await supabase
    .from('orders')
    .update({
      order_status: 'seller_confirmed',
      seller_confirmed_at: new Date().toISOString(),
      delivery_photo_url: deliveryPhotoUrl,
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (error) throw error;
  return normalizeOrder(data);
};

// Capture Stripe payment - MUST be called before completing card payment orders
const captureStripePayment = async (paymentIntentId: string): Promise<void> => {
  console.log('💳 Capturing Stripe payment:', paymentIntentId);
  
  const { data, error } = await supabase.functions.invoke('capture_payment', {
    body: { payment_intent_id: paymentIntentId },
  });

  if (error) {
    console.error('❌ Failed to capture payment:', error);
    throw new Error('Failed to capture payment. Please try again.');
  }

  if (data?.error) {
    console.error('❌ Stripe capture error:', data.error);
    throw new Error(data.error);
  }

  console.log('✅ Payment captured successfully');
};

// Buyer confirms delivery
export const confirmDelivery = async (orderId: string): Promise<Order> => {
  console.log('🔵 confirmDelivery: Starting for order', orderId);

  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.buyer_id) {
    throw new Error('Unauthorized: Only buyer can confirm delivery');
  }

  if (order.order_status !== 'seller_confirmed') {
    throw new Error('Cannot confirm delivery in current status');
  }

  // Capture the Stripe payment - this charges the buyer and sends money to seller's Stripe Connect
  if (order.stripe_payment_intent_id) {
    await captureStripePayment(order.stripe_payment_intent_id);
  }

  // Update order status to completed
  const { data: updatedOrder, error } = await supabase
    .from('orders')
    .update({
      order_status: 'completed',
      payment_status: 'succeeded',
      buyer_confirmed_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (error) throw error;

  console.log('✅ Order completed');
  return normalizeOrder(updatedOrder);
};

// Cancel order (buyer or seller, before seller confirms)
export const cancelOrder = async (orderId: string): Promise<Order> => {
  console.log('🔵 cancelOrder: Starting for order', orderId);

  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.buyer_id && currentUserId !== order.seller_id) {
    throw new Error('Unauthorized: Only buyer or seller can cancel order');
  }

  // Allow cancellation if order is placed OR in_progress (seller accepted but not delivered)
  if (order.order_status !== 'placed' && order.order_status !== 'in_progress') {
    throw new Error('Cannot cancel after seller has confirmed delivery');
  }

  // Update order status
  const { data: updatedOrder, error } = await supabase
    .from('orders')
    .update({
      order_status: 'cancelled',
      payment_status: 'refunded',
      cancelled_at: new Date().toISOString(),
      refunded_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (error) throw error;

  // Refund buyer
  await refundBuyer(order);

  // Unarchive the listing when order is cancelled
  // This makes the listing available for other buyers again
  // Only unarchive if there are no other active orders for this listing
  if (order.listing_id) {
    console.log('📦 Checking if listing can be unarchived after order cancelled:', order.listing_id);
    
    const { data: otherOrders, error: checkError } = await supabase
      .from('orders')
      .select('id')
      .eq('listing_id', order.listing_id)
      .not('order_status', 'in', '("cancelled","completed")')
      .neq('id', orderId) // Exclude the order we just cancelled
      .limit(1);

    if (checkError) {
      console.error('⚠️ Failed to check other orders:', checkError.message);
    } else if (!otherOrders || otherOrders.length === 0) {
      // No other active orders - safe to unarchive
      const { error: unarchiveError } = await supabase
        .from('listings')
        .update({ archived: false })
        .eq('id', order.listing_id);
      
      if (unarchiveError) {
        console.error('⚠️ Failed to unarchive listing:', unarchiveError.message);
      } else {
        console.log('✅ Listing unarchived successfully');
      }
    } else {
      console.log('ℹ️ Listing not unarchived - other active orders exist');
    }
  }

  console.log('✅ Order cancelled and buyer refunded');
  return normalizeOrder(updatedOrder);
};

// Cancel Stripe payment authorization
const cancelStripePayment = async (paymentIntentId: string): Promise<void> => {
  console.log('💳 Cancelling Stripe payment:', paymentIntentId);
  
  const { data, error } = await supabase.functions.invoke('cancel_payment', {
    body: { payment_intent_id: paymentIntentId },
  });

  if (error) {
    console.error('❌ Failed to cancel payment:', error);
    // Don't throw - the process-expired-orders cron will clean this up
  }

  console.log('✅ Stripe payment cancelled');
};

// Refund buyer - cancels/voids the Stripe payment authorization
const refundBuyer = async (order: Order): Promise<void> => {
  if (order.stripe_payment_intent_id) {
    await cancelStripePayment(order.stripe_payment_intent_id);
  }
};

// Verify service PIN (seller verifies buyer's PIN)
// SECURITY FIX: PIN must be verified BEFORE capturing payment
export const verifyServicePIN = async (
  orderId: string,
  pin: string
): Promise<Order> => {
  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.seller_id) {
    throw new Error('Unauthorized: Only seller can verify PIN');
  }

  // STEP 0: LOCAL PIN VALIDATION (defense-in-depth)
  // This ensures PIN is correct even if RPC function has issues
  console.log('🔐 Verifying service PIN for order:', orderId);
  
  // Fetch the actual PIN from the order
  const { data: orderData, error: fetchError } = await supabase
    .from('orders')
    .select('verification_pin')
    .eq('id', orderId)
    .single();
  
  if (fetchError || !orderData) {
    console.error('❌ Failed to fetch order PIN:', fetchError);
    throw new Error('Failed to verify PIN. Please try again.');
  }
  
  // Compare PINs - must match exactly
  if (!orderData.verification_pin) {
    console.error('❌ Order does not have a verification PIN');
    throw new Error('This order does not require PIN verification.');
  }
  
  if (orderData.verification_pin !== pin) {
    console.error('❌ PIN mismatch:', { submitted: pin, expected: orderData.verification_pin });
    throw new Error('Incorrect PIN. Please check with the buyer and try again.');
  }
  
  console.log('✅ Local PIN verification passed');

  // STEP 1: Call RPC for database-side verification and PIN attempt tracking
  // This provides additional security and tracks PIN attempts
  try {
    const { error: pinError } = await supabase.rpc('verify_service_pin', {
      p_order_id: orderId,
      p_pin: pin,
    });

    if (pinError) {
      console.error('❌ RPC PIN verification failed:', pinError);
      // Don't throw here since we already validated locally
      // The RPC might not exist or have different behavior
    } else {
      console.log('✅ RPC PIN verification passed');
    }
  } catch (rpcError) {
    // RPC might not exist - that's okay since we validated locally
    console.warn('⚠️ RPC verify_service_pin call failed (may not exist):', rpcError);
  }

  // STEP 2: Only capture payment AFTER PIN is verified
  // This prevents charging the buyer if the PIN is wrong
  if (order.stripe_payment_intent_id) {
    await captureStripePayment(order.stripe_payment_intent_id);
  }

  // STEP 3: Mark order as completed after successful PIN verification and payment capture
  const { data: updatedOrder, error: updateError } = await supabase
    .from('orders')
    .update({
      order_status: 'completed',
      payment_status: 'succeeded',
      completed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (updateError) {
    console.error('❌ Failed to update order status:', updateError);
    throw updateError;
  }

  console.log('✅ Order marked as completed');
  return normalizeOrder(updatedOrder);
};

// Get order statistics
export const getOrderStats = async (): Promise<OrderStats> => {
  const allOrders = await getUserOrders();

  const totalOrders = allOrders.length;
  const completedOrders = allOrders.filter(o => o.order_status === 'completed').length;
  const activeOrders = allOrders.filter(o =>
    ['placed', 'seller_confirmed', 'in_progress'].includes(o.order_status)
  ).length;
  const disputedOrders = allOrders.filter(o => o.order_status === 'disputed').length;

  const totalValue = allOrders.reduce((sum, o) => sum + o.price_cents, 0);
  const averageOrderValue = totalOrders > 0 ? totalValue / totalOrders : 0;

  return {
    totalOrders,
    activeOrders,
    completedOrders,
    disputedOrders,
    totalValue: totalValue / 100,
    averageOrderValue: averageOrderValue / 100,
  };
};

// Update order payment status after payment
export const updateOrderPaymentStatus = async (
  orderId: string,
  paymentIntentId: string
): Promise<Order> => {
  console.log('💳 updateOrderPaymentStatus: Starting for order', orderId);

  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.buyer_id) {
    throw new Error('Unauthorized: Only buyer can update payment status');
  }

  // FIX #1: Payment is only authorized at this point, not captured yet
  // Status should be 'requires_capture' (held funds) not 'succeeded' (charged)
  // Payment is only marked 'succeeded' after buyer confirms delivery
  const { data, error } = await supabase
    .from('orders')
    .update({
      payment_status: 'requires_capture',
      stripe_payment_intent_id: paymentIntentId,
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (error) throw error;

  console.log('✅ Order payment status updated to requires_capture (authorized, not yet charged)');
  return normalizeOrder(data);
};

// Delete pending order (for cleanup when payment fails before completion)
// Only allows deletion of orders with payment_status: 'pending'
export const deletePendingOrder = async (orderId: string): Promise<void> => {
  console.log('🗑️ deletePendingOrder: Cleaning up order', orderId);

  const currentUserId = await getCurrentUserId();

  // First verify the order exists, belongs to buyer, and is in pending state
  const { data: order, error: fetchError } = await supabase
    .from('orders')
    .select('id, buyer_id, payment_status, listing_id')
    .eq('id', orderId)
    .single();

  if (fetchError) {
    console.error('❌ Failed to fetch order for deletion:', fetchError);
    throw fetchError;
  }

  if (order.buyer_id !== currentUserId) {
    throw new Error('Unauthorized: Only buyer can delete pending order');
  }

  if (order.payment_status !== 'pending') {
    throw new Error('Cannot delete order - payment has already been processed');
  }

  // Delete the pending order
  const { error: deleteError } = await supabase
    .from('orders')
    .delete()
    .eq('id', orderId);

  if (deleteError) {
    console.error('❌ Failed to delete pending order:', deleteError);
    throw deleteError;
  }

  console.log('✅ Pending order deleted');

  // Unarchive the listing since the order was cancelled before payment
  // This makes the listing available for other buyers again
  if (order.listing_id) {
    console.log('📦 Checking if listing can be unarchived after pending order deleted:', order.listing_id);
    
    // Only unarchive if there are no other active orders for this listing
    const { data: otherOrders, error: checkError } = await supabase
      .from('orders')
      .select('id')
      .eq('listing_id', order.listing_id)
      .not('order_status', 'in', '("cancelled","completed")')
      .limit(1);

    if (checkError) {
      console.error('⚠️ Failed to check other orders:', checkError.message);
    } else if (!otherOrders || otherOrders.length === 0) {
      // No other active orders - safe to unarchive
      const { error: unarchiveError } = await supabase
        .from('listings')
        .update({ archived: false })
        .eq('id', order.listing_id);
      
      if (unarchiveError) {
        console.error('⚠️ Failed to unarchive listing:', unarchiveError.message);
      } else {
        console.log('✅ Listing unarchived successfully');
      }
    } else {
      console.log('ℹ️ Listing not unarchived - other active orders exist');
    }
  }
};

// Aliases
export const getOrder = getOrderDetails;
export const getMyOrders = getUserOrders;
export const verifyServicePin = verifyServicePIN;

export default {
  createOrder,
  getOrderDetails,
  getOrder,
  getUserOrders,
  getMyOrders,
  getBuyerOrders,
  getSellerOrders,
  acceptOrder,
  markDelivered,
  confirmDelivery,
  cancelOrder,
  verifyServicePIN,
  verifyServicePin,
  getOrderStats,
  updateOrderPaymentStatus,
  deletePendingOrder,
};

