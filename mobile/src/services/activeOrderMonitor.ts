// Active Order Monitor - Converted from ActiveOrderMonitor.swift
// Tracks orders requiring action and deadline monitoring

import { supabase } from '../config/supabase';
import { Order, OrderStatus } from '../types';
import { getUserOrders } from './orderService';

// Constants
export const ORDER_DEADLINE_SECONDS = 5 * 24 * 60 * 60; // 5 days in seconds
export const DEADLINE_WARNING_SECONDS = 4 * 24 * 60 * 60; // 4 days (24 hours before deadline)

// Monitor state
let monitoringInterval: NodeJS.Timeout | null = null;
let activeOrdersCache: Order[] = [];
let onUpdateCallback: ((orders: Order[]) => void) | null = null;

/**
 * Start monitoring active orders for the current user
 * Checks every 60 seconds for updates
 */
export const startMonitoring = async (userId: string, onUpdate?: (orders: Order[]) => void): Promise<void> => {
  console.log('🔍 Starting active order monitoring for user:', userId);
  
  if (onUpdate) {
    onUpdateCallback = onUpdate;
  }
  
  // Initial check
  await checkActiveOrders(userId);
  
  // Set up periodic monitoring (every 60 seconds)
  if (!monitoringInterval) {
    monitoringInterval = setInterval(async () => {
      await checkActiveOrders(userId);
    }, 60000); // 60 seconds
  }
};

/**
 * Stop monitoring active orders
 */
export const stopMonitoring = (): void => {
  console.log('⏸️ Stopping active order monitoring');
  
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
    monitoringInterval = null;
  }
  
  onUpdateCallback = null;
  activeOrdersCache = [];
};

/**
 * Check for active orders requiring action
 * Returns orders where user needs to take action
 */
export const checkActiveOrders = async (userId: string): Promise<Order[]> => {
  try {
    // Get all user orders
    const allOrders = await getUserOrders();
    
    // Filter to active orders requiring action
    const activeOrders = allOrders.filter(order => requiresUserAction(order, userId));
    
    // Update cache
    activeOrdersCache = activeOrders;
    
    // Notify callback
    if (onUpdateCallback) {
      onUpdateCallback(activeOrders);
    }
    
    console.log(`📊 Active orders requiring action: ${activeOrders.length}`);
    return activeOrders;
  } catch (error) {
    console.error('❌ Error checking active orders:', error);
    return [];
  }
};

/**
 * Get cached active orders (without fetching)
 */
export const getCachedActiveOrders = (): Order[] => {
  return activeOrdersCache;
};

/**
 * Determine if an order requires user action
 */
export const requiresUserAction = (order: Order, userId: string): boolean => {
  // Completed, cancelled, or refunded orders don't require action
  if (['completed', 'cancelled', 'refunded'].includes(order.order_status)) {
    return false;
  }
  
  // For buyers
  if (order.buyer_id === userId) {
    // Pending payment
    if (order.payment_status === 'pending') {
      return true;
    }
    
    // Seller confirmed delivery, buyer needs to confirm
    if (order.order_status === 'seller_confirmed') {
      return true;
    }
    
    // Orders near deadline or past deadline
    if (isNearDeadline(order) || isPastDeadline(order)) {
      return true;
    }
  }
  
  // For sellers
  if (order.seller_id === userId) {
    // New order placed, seller needs to confirm
    if (order.order_status === 'placed') {
      return true;
    }
    
    // In progress, seller needs to mark delivered
    if (order.order_status === 'in_progress') {
      return true;
    }
  }
  
  return false;
};

/**
 * Calculate time until deadline from order creation
 * Returns seconds remaining (can be negative if past deadline)
 */
export const timeUntilDeadline = (order: Order): number => {
  const createdAt = new Date(order.created_at).getTime() / 1000; // Convert to seconds
  const now = Date.now() / 1000; // Current time in seconds
  const elapsed = now - createdAt;
  const remaining = ORDER_DEADLINE_SECONDS - elapsed;
  
  return remaining;
};

/**
 * Check if order is within 24 hours of deadline
 */
export const isNearDeadline = (order: Order): boolean => {
  const remaining = timeUntilDeadline(order);
  return remaining > 0 && remaining <= (ORDER_DEADLINE_SECONDS - DEADLINE_WARNING_SECONDS);
};

/**
 * Check if order is past deadline
 */
export const isPastDeadline = (order: Order): boolean => {
  return timeUntilDeadline(order) <= 0;
};

/**
 * Get deadline status color
 * - blue: Normal (more than 24 hours)
 * - orange: Warning (within 24 hours)
 * - red: Expired (past deadline)
 */
export const getDeadlineColor = (order: Order): string => {
  if (isPastDeadline(order)) {
    return '#EF4444'; // red
  }
  
  if (isNearDeadline(order)) {
    return '#F97316'; // orange
  }
  
  return '#3B82F6'; // blue
};

/**
 * Format time remaining as human-readable string
 * Examples: "4d 12h", "23h 45m", "45m", "Expired"
 */
export const formattedTimeRemaining = (order: Order): string => {
  const secondsRemaining = timeUntilDeadline(order);
  
  if (secondsRemaining <= 0) {
    return 'Expired';
  }
  
  const days = Math.floor(secondsRemaining / (24 * 60 * 60));
  const hours = Math.floor((secondsRemaining % (24 * 60 * 60)) / (60 * 60));
  const minutes = Math.floor((secondsRemaining % (60 * 60)) / 60);
  
  if (days > 0) {
    return `${days}d ${hours}h left`;
  }
  
  if (hours > 0) {
    return `${hours}h ${minutes}m left`;
  }
  
  return `${minutes}m left`;
};

/**
 * Get deadline progress (0-1)
 * 1 = just created, 0 = deadline reached
 */
export const getDeadlineProgress = (order: Order): number => {
  const remaining = timeUntilDeadline(order);
  const progress = remaining / ORDER_DEADLINE_SECONDS;
  
  // Clamp between 0 and 1
  return Math.max(0, Math.min(1, progress));
};

/**
 * Get count of active orders requiring action
 */
export const getActiveOrderCount = (userId: string): number => {
  return activeOrdersCache.filter(order => requiresUserAction(order, userId)).length;
};

/**
 * Get deadline timestamp (absolute time)
 */
export const getDeadlineTimestamp = (order: Order): Date => {
  const createdAt = new Date(order.created_at);
  const deadlineMs = createdAt.getTime() + (ORDER_DEADLINE_SECONDS * 1000);
  return new Date(deadlineMs);
};

/**
 * Format deadline as date string
 */
export const formatDeadlineDate = (order: Order): string => {
  const deadline = getDeadlineTimestamp(order);
  
  // Format as "Dec 15 at 3:00 PM"
  const formatter = new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
  
  return formatter.format(deadline);
};

export default {
  startMonitoring,
  stopMonitoring,
  checkActiveOrders,
  getCachedActiveOrders,
  requiresUserAction,
  timeUntilDeadline,
  isNearDeadline,
  isPastDeadline,
  getDeadlineColor,
  formattedTimeRemaining,
  getDeadlineProgress,
  getActiveOrderCount,
  getDeadlineTimestamp,
  formatDeadlineDate,
  ORDER_DEADLINE_SECONDS,
  DEADLINE_WARNING_SECONDS,
};
