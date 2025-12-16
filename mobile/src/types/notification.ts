// Notification Types - Converted from NotificationModels.swift

export type NotificationType =
  | 'order_placed'
  | 'order_confirmed'
  | 'order_in_progress'
  | 'order_completed'
  | 'order_cancelled'
  | 'payment_succeeded'
  | 'payment_failed'
  | 'new_message'
  | 'rating_received'
  | 'rating_reminder'
  | 'payout_completed'
  | 'listing_interest'
  | 'marketplace_activity';

export type NotificationCategory =
  | 'orders'
  | 'payments'
  | 'messaging'
  | 'ratings'
  | 'marketplace';

// Display helpers
export const NotificationTypeDisplay: Record<NotificationType, string> = {
  order_placed: 'New Orders',
  order_confirmed: 'Order Confirmations',
  order_in_progress: 'Order Updates',
  order_completed: 'Order Completions',
  order_cancelled: 'Order Cancellations',
  payment_succeeded: 'Payment Confirmations',
  payment_failed: 'Payment Failures',
  new_message: 'New Messages',
  rating_received: 'New Ratings',
  rating_reminder: 'Rating Reminders',
  payout_completed: 'Payout Confirmations',
  listing_interest: 'Listing Interest',
  marketplace_activity: 'Marketplace Activity',
};

export const NotificationTypeIcon: Record<NotificationType, string> = {
  order_placed: 'shopping-cart',
  order_confirmed: 'check-circle',
  order_in_progress: 'clock',
  order_completed: 'check-circle',
  order_cancelled: 'x-circle',
  payment_succeeded: 'credit-card',
  payment_failed: 'alert-triangle',
  new_message: 'message-circle',
  rating_received: 'star',
  rating_reminder: 'star',
  payout_completed: 'arrow-down-circle',
  listing_interest: 'heart',
  marketplace_activity: 'bell',
};

export const NotificationTypeColor: Record<NotificationType, string> = {
  order_placed: '#3B82F6', // blue
  order_confirmed: '#22C55E', // green
  order_in_progress: '#F97316', // orange
  order_completed: '#22C55E', // green
  order_cancelled: '#EF4444', // red
  payment_succeeded: '#22C55E', // green
  payment_failed: '#EF4444', // red
  new_message: '#3B82F6', // blue
  rating_received: '#EAB308', // yellow
  rating_reminder: '#F97316', // orange
  payout_completed: '#22C55E', // green
  listing_interest: '#EF4444', // red
  marketplace_activity: '#A855F7', // purple
};

export const NotificationCategoryDisplay: Record<NotificationCategory, string> = {
  orders: 'Orders',
  payments: 'Payments',
  messaging: 'Messages',
  ratings: 'Ratings',
  marketplace: 'Marketplace',
};

export const NotificationCategoryIcon: Record<NotificationCategory, string> = {
  orders: 'shopping-cart',
  payments: 'credit-card',
  messaging: 'message-circle',
  ratings: 'star',
  marketplace: 'shopping-bag',
};

export const NotificationCategoryColor: Record<NotificationCategory, string> = {
  orders: '#3B82F6', // blue
  payments: '#22C55E', // green
  messaging: '#3B82F6', // blue
  ratings: '#EAB308', // yellow
  marketplace: '#A855F7', // purple
};

// Get category for notification type
export const getNotificationCategory = (type: NotificationType): NotificationCategory => {
  switch (type) {
    case 'order_placed':
    case 'order_confirmed':
    case 'order_in_progress':
    case 'order_completed':
    case 'order_cancelled':
      return 'orders';
    case 'payment_succeeded':
    case 'payment_failed':
    case 'payout_completed':
      return 'payments';
    case 'new_message':
      return 'messaging';
    case 'rating_received':
    case 'rating_reminder':
      return 'ratings';
    case 'listing_interest':
    case 'marketplace_activity':
      return 'marketplace';
  }
};

// Notification interface
export interface Notification {
  id: string;
  user_id: string;
  type: NotificationType;
  title: string;
  body: string;
  data: Record<string, unknown>;
  is_read: boolean;
  is_delivered: boolean;
  scheduled_for: string | null;
  delivered_at: string | null;
  read_at: string | null;
  created_at: string;
  // Related entity references
  order_id: string | null;
  message_id: string | null;
  listing_id: string | null;
  related_user_id: string | null;
}

// Notification Create
export interface NotificationCreate {
  user_id: string;
  type: NotificationType;
  title: string;
  body: string;
  data: Record<string, unknown>;
  scheduled_for: string | null;
  order_id: string | null;
  message_id: string | null;
  listing_id: string | null;
  related_user_id: string | null;
}

// Notification helper functions
export const getTimeAgo = (createdAt: string): string => {
  const now = new Date();
  const created = new Date(createdAt);
  const diffMs = now.getTime() - created.getTime();
  const diffSecs = Math.floor(diffMs / 1000);
  const diffMins = Math.floor(diffSecs / 60);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffDays > 0) return `${diffDays}d ago`;
  if (diffHours > 0) return `${diffHours}h ago`;
  if (diffMins > 0) return `${diffMins}m ago`;
  return 'Just now';
};

export const isRecentNotification = (createdAt: string): boolean => {
  const now = new Date();
  const created = new Date(createdAt);
  const diffMs = now.getTime() - created.getTime();
  return diffMs < 3600000; // Less than 1 hour
};

// User Notification Preferences
export interface UserNotificationPreferences {
  id: string;
  user_id: string;
  // Push notification preferences
  push_enabled: boolean;
  push_token: string | null;
  push_platform: string | null;
  // Notification type preferences
  order_notifications: boolean;
  message_notifications: boolean;
  payment_notifications: boolean;
  rating_notifications: boolean;
  marketplace_notifications: boolean;
  // Timing preferences
  quiet_hours_start: string;
  quiet_hours_end: string;
  timezone: string;
  // Frequency controls
  max_daily_notifications: number;
  group_similar_notifications: boolean;
  created_at: string;
  updated_at: string;
}

// Preferences Update (partial update)
export interface NotificationPreferencesUpdate {
  push_enabled?: boolean;
  push_token?: string;
  order_notifications?: boolean;
  message_notifications?: boolean;
  payment_notifications?: boolean;
  rating_notifications?: boolean;
  marketplace_notifications?: boolean;
  quiet_hours_start?: string;
  quiet_hours_end?: string;
  timezone?: string;
  max_daily_notifications?: number;
  group_similar_notifications?: boolean;
}

// Default preferences
export const defaultNotificationPreferences: Omit<UserNotificationPreferences, 'id' | 'user_id' | 'created_at' | 'updated_at'> = {
  push_enabled: true,
  push_token: null,
  push_platform: 'ios',
  order_notifications: true,
  message_notifications: true,
  payment_notifications: true,
  rating_notifications: true,
  marketplace_notifications: false,
  quiet_hours_start: '22:00',
  quiet_hours_end: '08:00',
  timezone: 'UTC',
  max_daily_notifications: 10,
  group_similar_notifications: true,
};

// Notification Summary
export interface NotificationSummary {
  total_unread: number;
  unread_by_category: Record<NotificationCategory, number>;
  recent_notifications: Notification[];
}

