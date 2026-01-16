// Notification Service - OneSignal Implementation
import { Platform } from 'react-native';
import OneSignal from 'react-native-onesignal';
import { supabase } from '../config/supabase';

const ONESIGNAL_APP_ID = 'cb72afc9-84c6-4cfc-8cc3-64f63d1700c1';

let isInitialized = false;

/**
 * Initialize OneSignal SDK
 */
export const initializeNotifications = async (): Promise<void> => {
  if (isInitialized) {
    console.log('OneSignal already initialized');
    return;
  }

  try {
    console.log('🔔 Initializing OneSignal...');

    // Initialize OneSignal with App ID
    OneSignal.initialize(ONESIGNAL_APP_ID);

    // iOS: Request permission when user is logged in (done separately)
    // Android: Prompts automatically on first app launch

    // Enable verbose logging for debugging (disable in production)
    OneSignal.Debug.setLogLevel(6);

    isInitialized = true;
    console.log('✅ OneSignal initialized successfully');
  } catch (error) {
    console.error('❌ Error initializing OneSignal:', error);
    throw error;
  }
};

/**
 * Register user for notifications after authentication
 */
export const registerUserForNotifications = async (userId: string): Promise<void> => {
  try {
    console.log('📝 Registering user for notifications:', userId);

    // Set external user ID (Supabase user ID)
    OneSignal.login(userId);

    // Get subscription ID (player ID)
    const deviceState = await OneSignal.User.pushSubscription.getIdAsync();
    console.log('Device subscription ID:', deviceState);

    // Save subscription ID to database
    if (deviceState) {
      await updateUserPushToken(userId, deviceState);
    }

    // Add user tags for segmentation
    OneSignal.User.addTags({
      platform: Platform.OS,
      app_version: '2.3.0',
    });

    console.log('✅ User registered for notifications');
  } catch (error) {
    console.error('❌ Error registering user for notifications:', error);
    throw error;
  }
};

/**
 * Unregister user from notifications on logout
 */
export const unregisterUserNotifications = async (userId: string): Promise<void> => {
  try {
    console.log('📤 Unregistering user from notifications:', userId);

    // Logout from OneSignal (clears external user ID)
    OneSignal.logout();

    // Clear push token in database
    await clearUserPushToken(userId);

    console.log('✅ User unregistered from notifications');
  } catch (error) {
    console.error('❌ Error unregistering user:', error);
  }
};

/**
 * Request notification permissions (iOS only - Android grants automatically)
 */
export const requestNotificationPermissions = async (): Promise<boolean> => {
  try {
    console.log('🔔 Requesting notification permissions...');

    const hasPermission = await OneSignal.Notifications.getPermissionAsync();
    
    if (!hasPermission) {
      const granted = await OneSignal.Notifications.requestPermission(true);
      console.log('Permission granted:', granted);
      return granted;
    }

    console.log('Permission already granted');
    return true;
  } catch (error) {
    console.error('❌ Error requesting permissions:', error);
    return false;
  }
};

/**
 * Set up notification event handlers
 */
export const setupNotificationHandlers = (
  onNotificationReceived?: (notification: any) => void,
  onNotificationOpened?: (openedEvent: any) => void
): void => {
  try {
    console.log('📬 Setting up notification handlers...');

    // Handle notification received while app is in foreground
    OneSignal.Notifications.addEventListener('foregroundWillDisplay', (event) => {
      console.log('📬 Notification received in foreground:', event.notification);
      
      if (onNotificationReceived) {
        onNotificationReceived(event.notification);
      }

      // Display notification even when app is in foreground
      event.preventDefault();
      event.notification.display();
    });

    // Handle notification tap/click
    OneSignal.Notifications.addEventListener('click', (event) => {
      console.log('👆 Notification clicked:', event.notification);
      console.log('Additional data:', event.notification.additionalData);
      
      if (onNotificationOpened) {
        onNotificationOpened({
          notification: event.notification,
          data: event.notification.additionalData || {},
        });
      }
    });

    // Handle permission changes
    OneSignal.Notifications.addEventListener('permissionChange', (granted) => {
      console.log('🔔 Notification permission changed:', granted);
    });

    console.log('✅ Notification handlers set up successfully');
  } catch (error) {
    console.error('❌ Error setting up notification handlers:', error);
  }
};

/**
 * Get device state (subscription ID and permission status)
 */
export const getDeviceState = async () => {
  try {
    const subscriptionId = await OneSignal.User.pushSubscription.getIdAsync();
    const hasPermission = await OneSignal.Notifications.getPermissionAsync();
    const optedIn = OneSignal.User.pushSubscription.getOptedIn();

    return {
      subscriptionId,
      hasPermission,
      optedIn,
    };
  } catch (error) {
    console.error('❌ Error getting device state:', error);
    return {
      subscriptionId: null,
      hasPermission: false,
      optedIn: false,
    };
  }
};

/**
 * Check if user has granted notification permissions
 */
export const hasNotificationPermissions = async (): Promise<boolean> => {
  try {
    return await OneSignal.Notifications.getPermissionAsync();
  } catch (error) {
    console.error('❌ Error checking permissions:', error);
    return false;
  }
};

/**
 * Set notification badge count (iOS only)
 */
export const setBadgeCount = async (count: number): Promise<void> => {
  try {
    if (Platform.OS === 'ios') {
      // OneSignal handles badge count automatically based on unread notifications
      console.log('Badge count set to:', count);
    }
  } catch (error) {
    console.error('❌ Error setting badge count:', error);
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

/**
 * Update user notification preferences in database
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
 * Update user's push token in database
 */
const updateUserPushToken = async (userId: string, pushToken: string): Promise<void> => {
  try {
    // Check if preferences exist
    const { data: existing } = await supabase
      .from('user_notification_preferences')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (existing) {
      // Update existing record
      const { error } = await supabase
        .from('user_notification_preferences')
        .update({
          push_token: pushToken,
          push_enabled: true,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId);

      if (error) throw error;
    } else {
      // Create new record
      const { error } = await supabase
        .from('user_notification_preferences')
        .insert({
          user_id: userId,
          push_token: pushToken,
          push_enabled: true,
        });

      if (error) throw error;
    }

    console.log('✅ Push token saved to database');
  } catch (error) {
    console.error('❌ Error saving push token:', error);
  }
};

/**
 * Clear user's push token in database
 */
const clearUserPushToken = async (userId: string): Promise<void> => {
  try {
    const { error } = await supabase
      .from('user_notification_preferences')
      .update({
        push_token: null,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (error) throw error;
    console.log('✅ Push token cleared from database');
  } catch (error) {
    console.error('❌ Error clearing push token:', error);
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
