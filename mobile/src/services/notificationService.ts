// OneSignal Notification Service - Unified iOS & Android Push Notifications
import OneSignal, { LogLevel } from 'react-native-onesignal';
import { Platform } from 'react-native';
import { supabase } from '../config/supabase';
import { ONESIGNAL_APP_ID } from '../config/secrets';

let isInitialized = false;

/**
 * Initialize OneSignal push notifications
 * Call this once during app startup, before user authentication
 */
export const initializeNotifications = async (): Promise<void> => {
  if (isInitialized) {
    console.log('OneSignal already initialized');
    return;
  }

  try {
    console.log('🔔 Initializing OneSignal...');
    console.log('OneSignal App ID:', ONESIGNAL_APP_ID);
    
    // Set log level for debugging (remove in production)
    OneSignal.Debug.setLogLevel(LogLevel.Verbose);

    // Initialize OneSignal with App ID
    OneSignal.initialize(ONESIGNAL_APP_ID);

    // Request notification permissions (iOS)
    // Android permissions are granted by default
    if (Platform.OS === 'ios') {
      // Request permission (won't show prompt if already granted)
      const permission = await OneSignal.Notifications.requestPermission(false);
      console.log('OneSignal permission status:', permission);
    }

    isInitialized = true;
    console.log('✅ OneSignal initialized successfully');
  } catch (error) {
    console.error('❌ Failed to initialize OneSignal:', error);
    throw error;
  }
};

/**
 * Register user and save OneSignal player ID to database
 * Call this after user authentication
 */
export const registerUserForNotifications = async (userId: string): Promise<void> => {
  try {
    console.log('📝 Registering user for notifications:', userId);

    // Set external user ID (links OneSignal player to your user ID)
    OneSignal.login(userId);
    console.log('✅ External user ID set successfully');

    // Get OneSignal subscription ID (device token)
    const subscriptionId = OneSignal.User.pushSubscription.id;
    
    if (subscriptionId) {
      const platform = Platform.OS as 'ios' | 'android';

      console.log('OneSignal Subscription ID:', subscriptionId);

      // Save to database
      const { error } = await supabase
        .from('user_notification_preferences')
        .upsert(
          {
            user_id: userId,
            push_token: subscriptionId,
            push_platform: platform,
            push_enabled: true,
            updated_at: new Date().toISOString(),
          },
          {
            onConflict: 'user_id',
          }
        );

      if (error) {
        console.error('Failed to save OneSignal subscription ID:', error);
      } else {
        console.log('✅ OneSignal subscription ID saved to database');
      }
    } else {
      console.warn('⚠️ No OneSignal subscription ID available yet');
    }
  } catch (error) {
    console.error('❌ Error registering user for notifications:', error);
    throw error;
  }
};

/**
 * Unregister user from notifications (e.g., on logout)
 */
export const unregisterUserNotifications = async (userId: string): Promise<void> => {
  try {
    console.log('📤 Unregistering user from notifications:', userId);

    // Logout from OneSignal
    OneSignal.logout();

    // Update database
    const { error } = await supabase
      .from('user_notification_preferences')
      .update({
        push_token: null,
        push_enabled: false,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (error) {
      console.error('Failed to unregister user:', error);
    } else {
      console.log('✅ User unregistered from notifications');
    }

    // Clear notifications (iOS)
    if (Platform.OS === 'ios') {
      OneSignal.Notifications.clearAll();
    }
  } catch (error) {
    console.error('❌ Error unregistering user notifications:', error);
  }
};

/**
 * Request notification permissions (call after user logs in)
 */
export const requestNotificationPermissions = async (): Promise<boolean> => {
  try {
    const hasPermission = OneSignal.Notifications.hasPermission();
    
    if (hasPermission) {
      console.log('✅ Notification permissions already granted');
      return true;
    }

    // Request permission
    const granted = await OneSignal.Notifications.requestPermission(true);
    console.log('Notification permission response:', granted);
    return granted;
  } catch (error) {
    console.error('❌ Error requesting notification permissions:', error);
    return false;
  }
};

/**
 * Update notification preferences in database
 */
export const updateNotificationPreferences = async (
  userId: string,
  preferences: {
    order_notifications?: boolean;
    message_notifications?: boolean;
    payment_notifications?: boolean;
    rating_notifications?: boolean;
    marketplace_notifications?: boolean;
  }
): Promise<void> => {
  try {
    const { error } = await supabase
      .from('user_notification_preferences')
      .update({
        ...preferences,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (error) throw error;
    console.log('✅ Notification preferences updated');
  } catch (error) {
    console.error('❌ Error updating notification preferences:', error);
    throw error;
  }
};

/**
 * Get current notification preferences
 */
export const getNotificationPreferences = async (userId: string) => {
  try {
    const { data, error } = await supabase
      .from('user_notification_preferences')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (error) throw error;
    return data;
  } catch (error) {
    console.error('❌ Error getting notification preferences:', error);
    return null;
  }
};

/**
 * Set up notification event handlers
 * Call this once during app initialization
 */
export const setupNotificationHandlers = (
  onNotificationReceived?: (notification: any) => void,
  onNotificationOpened?: (openedEvent: any) => void
): void => {
  // Handle notification received (foreground)
  OneSignal.Notifications.addEventListener('foregroundWillDisplay', (event) => {
    console.log('📬 Notification received in foreground:', event);
    
    const notification = event.notification;
    
    // Call custom handler if provided
    if (onNotificationReceived) {
      onNotificationReceived(notification);
    }

    // Display the notification
    event.preventDefault();
    event.notification.display();
  });

  // Handle notification tapped
  OneSignal.Notifications.addEventListener('click', (event) => {
    console.log('👆 Notification tapped:', event);
    
    const notification = event.notification;
    const data = notification.additionalData;

    // Call custom handler if provided
    if (onNotificationOpened) {
      onNotificationOpened({ notification, data });
    }
  });

  console.log('✅ Notification handlers set up');
};

/**
 * Get device state (subscription ID, permission status, etc.)
 */
export const getDeviceState = async () => {
  try {
    const subscriptionId = OneSignal.User.pushSubscription.id;
    const hasPermission = OneSignal.Notifications.hasPermission();
    const optedIn = OneSignal.User.pushSubscription.optedIn;
    
    return {
      subscriptionId,
      hasPermission,
      optedIn,
    };
  } catch (error) {
    console.error('❌ Error getting device state:', error);
    return null;
  }
};

/**
 * Set notification badge count (iOS only)
 */
export const setBadgeCount = async (count: number): Promise<void> => {
  if (Platform.OS === 'ios') {
    // OneSignal automatically manages badges, but you can clear them
    if (count === 0) {
      OneSignal.Notifications.clearAll();
    }
  }
};

/**
 * Check if user has granted notification permissions
 */
export const hasNotificationPermissions = async (): Promise<boolean> => {
  try {
    return OneSignal.Notifications.hasPermission();
  } catch (error) {
    console.error('❌ Error checking notification permissions:', error);
    return false;
  }
};

/**
 * Add tags to user for segmentation
 */
export const addUserTags = async (tags: Record<string, string>): Promise<void> => {
  try {
    OneSignal.User.addTags(tags);
    console.log('✅ User tags added:', tags);
  } catch (error) {
    console.error('❌ Error adding user tags:', error);
  }
};

/**
 * Remove user tags
 */
export const removeUserTags = async (tagKeys: string[]): Promise<void> => {
  try {
    OneSignal.User.removeTags(tagKeys);
    console.log('✅ User tags removed:', tagKeys);
  } catch (error) {
    console.error('❌ Error removing user tags:', error);
  }
};

export default {
  initializeNotifications,
  registerUserForNotifications,
  unregisterUserNotifications,
  requestNotificationPermissions,
  updateNotificationPreferences,
  getNotificationPreferences,
  setupNotificationHandlers,
  getDeviceState,
  setBadgeCount,
  hasNotificationPermissions,
  addUserTags,
  removeUserTags,
};
