// React Hook for OneSignal Push Notifications
import { useEffect, useState } from 'react';
import { useNavigation } from '@react-navigation/native';
import {
  setupNotificationHandlers,
  registerUserForNotifications,
  requestNotificationPermissions,
  getDeviceState,
  hasNotificationPermissions,
} from '../services/notificationService';

interface UsePushNotificationsProps {
  userId: string | null;
  onNotificationReceived?: (notification: any) => void;
}

export const usePushNotifications = ({
  userId,
  onNotificationReceived,
}: UsePushNotificationsProps) => {
  const navigation = useNavigation();
  const [isInitialized, setIsInitialized] = useState(false);
  const [hasPermissions, setHasPermissions] = useState(false);
  const [playerID, setPlayerID] = useState<string | null>(null);

  // Register user when authenticated
  useEffect(() => {
    if (!userId) {
      setIsInitialized(false);
      return;
    }

    const registerUser = async () => {
      try {
        // Register user with OneSignal
        await registerUserForNotifications(userId);
        
        // Check permissions status
        const permitted = await hasNotificationPermissions();
        setHasPermissions(permitted);

        // Get subscription ID
        const deviceState = await getDeviceState();
        if (deviceState?.subscriptionId) {
          setPlayerID(deviceState.subscriptionId);
        }

        setIsInitialized(true);
        console.log('✅ User registered for push notifications');
      } catch (error) {
        console.error('❌ Failed to register user for notifications:', error);
      }
    };

    registerUser();
  }, [userId]);

  // Set up notification handlers
  useEffect(() => {
    const handleNotificationReceived = (notification: any) => {
      console.log('📬 Notification received in hook:', notification);
      
      // Update badge or other UI elements
      if (onNotificationReceived) {
        onNotificationReceived(notification);
      }
    };

    const handleNotificationOpened = ({ notification, data }: any) => {
      console.log('👆 Notification tapped in hook:', notification);
      console.log('Notification data:', data);
      
      // Navigate based on notification data
      handleNotificationNavigation(data, navigation);
    };

    // Set up handlers
    setupNotificationHandlers(handleNotificationReceived, handleNotificationOpened);

    // Cleanup is handled by OneSignal internally
    return () => {
      // OneSignal manages its own lifecycle
    };
  }, [navigation, onNotificationReceived]);

  // Method to request permissions (call from UI button)
  const requestPermissions = async () => {
    const granted = await requestNotificationPermissions();
    setHasPermissions(granted);
    return granted;
  };

  return {
    isInitialized,
    hasPermissions,
    playerID,
    requestPermissions,
  };
};

/**
 * Navigate to appropriate screen based on notification data
 */
function handleNotificationNavigation(data: any, navigation: any) {
  if (!data) {
    console.log('No navigation data in notification');
    return;
  }

  try {
    // Navigate based on notification type
    if (data.order_id) {
      console.log('Navigating to OrderDetail:', data.order_id);
      navigation.navigate('OrderDetail', { orderId: data.order_id });
    } else if (data.conversation_id) {
      console.log('Navigating to Chat:', data.conversation_id);
      navigation.navigate('Chat', { conversationId: data.conversation_id });
    } else if (data.listing_id) {
      console.log('Navigating to ListingDetail:', data.listing_id);
      navigation.navigate('ListingDetail', { listingId: data.listing_id });
    } else if (data.screen) {
      // Generic screen navigation
      console.log('Navigating to screen:', data.screen);
      navigation.navigate(data.screen, data.params || {});
    } else {
      console.log('No specific navigation route found in data');
    }
  } catch (error) {
    console.error('❌ Error navigating from notification:', error);
  }
}

export default usePushNotifications;
