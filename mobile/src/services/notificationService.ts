// Notification Service - Handle push notifications with OneSignal
import { supabase } from '../config/supabase';
import { ONESIGNAL_APP_ID } from '../config/secrets';
import { Platform } from 'react-native';

// OneSignal will be initialized when the SDK is properly integrated
let isInitialized = false;

export const initializeNotifications = async () => {
  if (isInitialized) return;
  
  try {
    // OneSignal initialization will be done via react-native-onesignal
    // OneSignal.setAppId(ONESIGNAL_APP_ID);
    console.log('OneSignal initialized with app ID:', ONESIGNAL_APP_ID.substring(0, 8) + '...');
    isInitialized = true;
  } catch (error) {
    console.error('Failed to initialize OneSignal:', error);
  }
};

// Request notification permissions
export const requestPermissions = async (): Promise<boolean> => {
  try {
    // OneSignal.promptForPushNotificationsWithUserResponse();
    return true;
  } catch (error) {
    console.error('Failed to request notification permissions:', error);
    return false;
  }
};

// Register device with backend
export const registerDevice = async (playerId: string): Promise<void> => {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.user) return;

  await supabase
    .from('users')
    .update({
      onesignal_player_id: playerId,
      device_platform: Platform.OS,
    })
    .eq('id', session.user.id);
};

// Set external user ID (link OneSignal to our user)
export const setExternalUserId = async (userId: string): Promise<void> => {
  try {
    // OneSignal.setExternalUserId(userId);
    console.log('Set external user ID:', userId);
  } catch (error) {
    console.error('Failed to set external user ID:', error);
  }
};

// Remove external user ID on logout
export const removeExternalUserId = async (): Promise<void> => {
  try {
    // OneSignal.removeExternalUserId();
    console.log('Removed external user ID');
  } catch (error) {
    console.error('Failed to remove external user ID:', error);
  }
};

// Send a test notification (for debugging)
export const sendTestNotification = async (): Promise<boolean> => {
  try {
    const { data, error } = await supabase.functions.invoke('send-test-notification', {
      body: {},
    });

    if (error) throw error;
    return true;
  } catch (error) {
    console.error('Failed to send test notification:', error);
    return false;
  }
};

// Handle notification received
export const onNotificationReceived = (callback: (notification: any) => void) => {
  // OneSignal.setNotificationWillShowInForegroundHandler(notificationReceivedEvent => {
  //   callback(notificationReceivedEvent.getNotification());
  //   notificationReceivedEvent.complete(notificationReceivedEvent.getNotification());
  // });
};

// Handle notification opened
export const onNotificationOpened = (callback: (notification: any) => void) => {
  // OneSignal.setNotificationOpenedHandler(openedEvent => {
  //   callback(openedEvent.notification);
  // });
};

export default {
  initializeNotifications,
  requestPermissions,
  registerDevice,
  setExternalUserId,
  removeExternalUserId,
  sendTestNotification,
  onNotificationReceived,
  onNotificationOpened,
};

