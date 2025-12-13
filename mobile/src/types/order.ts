// Order Types - Converted from OrderModels.swift

import { Listing, User } from './product';

export type OrderStatus = 
  | 'placed'
  | 'seller_confirmed'
  | 'in_progress'
  | 'completed'
  | 'disputed'
  | 'cancelled'
  | 'refunded';

export type PaymentStatus =
  | 'pending'
  | 'requires_capture'
  | 'captured'
  | 'succeeded'
  | 'released'
  | 'failed'
  | 'refunded';

export type PaymentMethod = 'wallet' | 'card';

// Display name helpers
export const OrderStatusDisplay: Record<OrderStatus, string> = {
  placed: 'Order Placed',
  seller_confirmed: 'Seller Confirmed',
  in_progress: 'In Progress',
  completed: 'Completed',
  disputed: 'Disputed',
  cancelled: 'Cancelled',
  refunded: 'Refunded',
};

export const OrderStatusIcon: Record<OrderStatus, string> = {
  placed: 'cart-plus',
  seller_confirmed: 'check-circle',
  in_progress: 'clock',
  completed: 'check-circle',
  disputed: 'alert-triangle',
  cancelled: 'x-circle',
  refunded: 'corner-up-left',
};

export const OrderStatusColor: Record<OrderStatus, string> = {
  placed: '#3B82F6', // blue
  seller_confirmed: '#F97316', // orange
  in_progress: '#EAB308', // yellow
  completed: '#22C55E', // green
  disputed: '#EF4444', // red
  cancelled: '#6B7280', // gray
  refunded: '#A855F7', // purple
};

export const PaymentStatusDisplay: Record<PaymentStatus, string> = {
  pending: 'Payment Pending',
  requires_capture: 'Payment Ready',
  captured: 'Payment Captured',
  succeeded: 'Payment Succeeded',
  released: 'Payment Released',
  failed: 'Payment Failed',
  refunded: 'Payment Refunded',
};

export const PaymentMethodDisplay: Record<PaymentMethod, string> = {
  wallet: 'Campus Wallet',
  card: 'Credit/Debit Card',
};

// Order interface
export interface Order {
  id: string;
  listing_id: string;
  buyer_id: string;
  seller_id: string;
  price_cents: number;
  seller_price_cents: number | null;
  buyer_price_cents: number | null;
  payment_method: PaymentMethod;
  payment_status: PaymentStatus;
  order_status: OrderStatus;
  // Status alias
  status: OrderStatus;
  seller_confirmed_at: string | null;
  in_progress_at: string | null;
  completed_at: string | null;
  cancelled_at: string | null;
  refunded_at: string | null;
  updated_at: string | null;
  created_at: string;
  stripe_escrow_account_id: string | null;
  marketplace_fee_cents: number;
  stripe_payment_intent_id: string | null;
  time_slot_id: string | null;
  delivery_photo_url: string | null;
  verification_pin: string | null;
  quantity: number;
  listing?: Listing | null;
  buyer?: User | null;
  seller?: User | null;
  // Computed fields (populated by queries)
  subtotal: number;
  service_fee: number;
  total_amount: number;
  service_pin: string | null;
  delivery_photo: string | null;
}

// Helper to normalize order data from API
export const normalizeOrder = (raw: any): Order => ({
  ...raw,
  status: raw.order_status,
  subtotal: raw.price_cents / 100,
  service_fee: raw.marketplace_fee_cents / 100,
  total_amount: (raw.buyer_price_cents ?? raw.price_cents) / 100,
  service_pin: raw.verification_pin,
  delivery_photo: raw.delivery_photo_url,
});

// Order with full details (buyer and seller populated)
export interface OrderWithDetails {
  order: Order;
  listing: Listing;
  buyer: User;
  seller: User;
}

// Order Create (for inserting new orders)
export interface OrderCreate {
  listing_id: string;
  buyer_id: string;
  seller_id: string;
  price_cents: number;
  seller_price_cents: number | null;
  buyer_price_cents: number | null;
  payment_method: PaymentMethod;
  time_slot_id: string | null;
  quantity: number;
}

// Order Insert (for database operations)
export interface OrderInsert {
  listing_id: string;
  buyer_id: string;
  seller_id: string;
  price_cents: number;
  seller_price_cents: number | null;
  buyer_price_cents: number | null;
  payment_method: string;
  order_status: string;
  payment_status: string;
  created_at: string;
  updated_at: string;
  stripe_escrow_account_id: string | null;
  marketplace_fee_cents: number;
  stripe_payment_intent_id: string | null;
  time_slot_id: string | null;
  verification_pin: string | null;
  quantity: number;
}

// Helper functions
export const getOrderPrice = (order: Order): number => {
  return order.price_cents / 100;
};

export const getSellerPrice = (order: Order): number => {
  return (order.seller_price_cents ?? order.price_cents) / 100;
};

export const getBuyerPrice = (order: Order): number => {
  return (order.buyer_price_cents ?? order.price_cents) / 100;
};

export const formatOrderPrice = (order: Order): string => {
  return `$${getOrderPrice(order).toFixed(2)}`;
};

export const formatSellerPrice = (order: Order): string => {
  return `$${getSellerPrice(order).toFixed(2)}`;
};

export const formatBuyerPrice = (order: Order): string => {
  return `$${getBuyerPrice(order).toFixed(2)}`;
};

export const isOrderActive = (status: OrderStatus): boolean => {
  return ['placed', 'seller_confirmed', 'in_progress', 'completed', 'disputed'].includes(status);
};

export const isOrderFinal = (status: OrderStatus): boolean => {
  return ['completed', 'cancelled', 'refunded'].includes(status);
};

export const requiresEscrow = (method: PaymentMethod): boolean => {
  return true; // Both wallet and card require escrow
};

export const hasEscrowAccount = (order: Order): boolean => {
  return order.stripe_escrow_account_id !== null;
};

export const getEscrowStatus = (order: Order): string => {
  if (order.stripe_escrow_account_id === null) return 'No Escrow';
  if (order.order_status === 'completed') return 'Released';
  return 'Held in Escrow';
};

export const hasDeliveryPhoto = (order: Order): boolean => {
  return order.delivery_photo_url !== null;
};

// Order filters
export interface OrderFilters {
  status?: OrderStatus;
  paymentMethod?: PaymentMethod;
  isActive?: boolean;
  dateRange?: { start: Date; end: Date };
}

// Order statistics
export interface OrderStats {
  totalOrders: number;
  activeOrders: number;
  completedOrders: number;
  disputedOrders: number;
  totalValue: number;
  averageOrderValue: number;
}

export const getCompletionRate = (stats: OrderStats): number => {
  if (stats.totalOrders === 0) return 0;
  return stats.completedOrders / stats.totalOrders;
};

export const getDisputeRate = (stats: OrderStats): number => {
  if (stats.totalOrders === 0) return 0;
  return stats.disputedOrders / stats.totalOrders;
};

