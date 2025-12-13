// Order Service - Converted from OrderService.swift
import { supabase } from '../config/supabase';
import {
  Order,
  OrderCreate,
  OrderStatus,
  OrderStats,
  Listing,
  Wallet,
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

  // Fetch listing to check type for PIN
  const { data: listing, error: listingError } = await supabase
    .from('listings')
    .select('*')
    .eq('id', orderCreate.listing_id)
    .single();

  if (listingError) throw listingError;

  const verificationPin = listing.listing_type === 'service' ? generateVerificationPIN() : null;

  // Create order
  const orderData = {
    listing_id: orderCreate.listing_id,
    buyer_id: orderCreate.buyer_id,
    seller_id: orderCreate.seller_id,
    price_cents: orderCreate.price_cents,
    seller_price_cents: orderCreate.seller_price_cents,
    buyer_price_cents: orderCreate.buyer_price_cents,
    payment_method: orderCreate.payment_method,
    order_status: 'placed',
    payment_status: 'succeeded',
    marketplace_fee_cents: 0,
    time_slot_id: orderCreate.time_slot_id,
    verification_pin: verificationPin,
    quantity: orderCreate.quantity,
  };

  const { data: order, error } = await supabase
    .from('orders')
    .insert(orderData)
    .select()
    .single();

  if (error) throw error;

  console.log('✅ Order created:', order.id);
  return order;
};

// Get order details
export const getOrderDetails = async (orderId: string): Promise<Order> => {
  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .eq('id', orderId)
    .single();

  if (error) throw error;
  return data;
};

// Get user's orders (as buyer or seller)
export const getUserOrders = async (
  status?: OrderStatus,
  limit = 50
): Promise<Order[]> => {
  const currentUserId = await getCurrentUserId();

  let query = supabase
    .from('orders')
    .select('*')
    .or(`buyer_id.eq.${currentUserId},seller_id.eq.${currentUserId}`);

  if (status) {
    query = query.eq('order_status', status);
  }

  const { data, error } = await query
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
};

// Get buyer orders only
export const getBuyerOrders = async (limit = 50): Promise<Order[]> => {
  const currentUserId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .eq('buyer_id', currentUserId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
};

// Get seller orders only
export const getSellerOrders = async (limit = 50): Promise<Order[]> => {
  const currentUserId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .eq('seller_id', currentUserId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
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
      order_status: 'seller_confirmed',
      seller_confirmed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (error) throw error;
  return data;
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

  if (!['placed', 'in_progress'].includes(order.order_status)) {
    throw new Error('Cannot mark as delivered in current status');
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
  return data;
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

  // Update order status to completed
  const { data: updatedOrder, error } = await supabase
    .from('orders')
    .update({
      order_status: 'completed',
      buyer_confirmed_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .select()
    .single();

  if (error) throw error;

  // Release escrow funds to seller
  await releaseEscrowFunds(order);

  console.log('✅ Order completed and escrow released');
  return updatedOrder;
};

// Release escrow funds to seller wallet
const releaseEscrowFunds = async (order: Order): Promise<void> => {
  console.log('🔵 releaseEscrowFunds: Starting for order', order.id);

  // Get or create seller's wallet
  let { data: wallet, error: walletError } = await supabase
    .from('wallets')
    .select('*')
    .eq('user_id', order.seller_id)
    .single();

  if (walletError) {
    // Create wallet if doesn't exist
    const { data: newWallet, error: createError } = await supabase
      .from('wallets')
      .insert({
        user_id: order.seller_id,
        available_cents: 0,
        escrow_cents: 0,
      })
      .select()
      .single();

    if (createError) throw createError;
    wallet = newWallet;
  }

  // Calculate net amount
  const netAmountCents = order.price_cents - order.marketplace_fee_cents;

  // Update seller's wallet
  const { error: updateError } = await supabase
    .from('wallets')
    .update({
      available_cents: wallet.available_cents + netAmountCents,
      updated_at: new Date().toISOString(),
    })
    .eq('user_id', order.seller_id);

  if (updateError) throw updateError;

  console.log('✅ Escrow funds released:', netAmountCents, 'cents');
};

// Cancel order (buyer only, before seller confirms)
export const cancelOrder = async (orderId: string): Promise<Order> => {
  console.log('🔵 cancelOrder: Starting for order', orderId);

  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.buyer_id) {
    throw new Error('Unauthorized: Only buyer can cancel order');
  }

  if (order.order_status !== 'placed') {
    throw new Error('Cannot cancel after seller has confirmed');
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

  console.log('✅ Order cancelled and buyer refunded');
  return updatedOrder;
};

// Refund buyer's wallet
const refundBuyer = async (order: Order): Promise<void> => {
  if (order.payment_method === 'card') {
    // For card payments, would void Stripe authorization
    console.log('💳 Card payment - would void Stripe authorization');
    return;
  }

  // For wallet payments, credit back to buyer
  let { data: wallet, error: walletError } = await supabase
    .from('wallets')
    .select('*')
    .eq('user_id', order.buyer_id)
    .single();

  if (walletError) {
    // Create wallet if doesn't exist
    const { data: newWallet, error: createError } = await supabase
      .from('wallets')
      .insert({
        user_id: order.buyer_id,
        available_cents: 0,
        escrow_cents: 0,
      })
      .select()
      .single();

    if (createError) throw createError;
    wallet = newWallet;
  }

  const refundAmount = order.buyer_price_cents ?? order.price_cents;

  await supabase
    .from('wallets')
    .update({
      available_cents: wallet.available_cents + refundAmount,
      updated_at: new Date().toISOString(),
    })
    .eq('user_id', order.buyer_id);

  console.log('✅ Buyer refunded:', refundAmount, 'cents');
};

// Verify service PIN (seller verifies buyer's PIN)
export const verifyServicePIN = async (
  orderId: string,
  pin: string
): Promise<Order> => {
  const currentUserId = await getCurrentUserId();
  const order = await getOrderDetails(orderId);

  if (currentUserId !== order.seller_id) {
    throw new Error('Unauthorized: Only seller can verify PIN');
  }

  // Call RPC function
  await supabase.rpc('verify_service_pin', {
    p_order_id: orderId,
    p_pin: pin,
  });

  return getOrderDetails(orderId);
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
};

