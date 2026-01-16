import React, { useEffect } from 'react';
import { StatusBar, LogBox, Platform } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { StripeProvider } from '@stripe/stripe-react-native';
import * as SplashScreen from 'expo-splash-screen';
import { ThemeProvider } from './src/context/ThemeContext';
import { OrderMonitorProvider } from './src/context/OrderMonitorContext';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import RootNavigator from './src/navigation/RootNavigator';
import { configureImageCache } from './src/config/imageConfig';
import { STRIPE_PUBLISHABLE_KEY } from './src/config/secrets';
import { initializeNotifications } from './src/services/notificationService';

// Prevent splash screen from auto-hiding until app is ready
SplashScreen.preventAutoHideAsync().catch(() => {
  // Ignore errors - splash screen might already be hidden
});

// Configure React Query for optimal caching
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Keep data fresh for 5 minutes
      staleTime: 5 * 60 * 1000,
      // Cache for 10 minutes
      gcTime: 10 * 60 * 1000,
      // Retry failed requests
      retry: 2,
      // Refetch on window focus
      refetchOnWindowFocus: true,
      // Don't refetch on reconnect (we handle this manually)
      refetchOnReconnect: false,
    },
  },
});

// Ignore specific warnings
LogBox.ignoreLogs([
  'Non-serializable values were found in the navigation state',
  'Sending `onAnimatedValueUpdate` with no listeners registered',
]);

export default function App() {
  useEffect(() => {
    // Initialize OneSignal for push notifications
    initializeNotifications().catch((error) => {
      console.error('Failed to initialize notifications:', error);
    });

    // Configure image cache on app start for lightning-fast loading
    configureImageCache();
  }, []);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <StripeProvider
        publishableKey={STRIPE_PUBLISHABLE_KEY}
        merchantIdentifier="merchant.campuslink.com.campuslink"
        urlScheme="campuslink"
      >
        <QueryClientProvider client={queryClient}>
          <ThemeProvider>
            <OrderMonitorProvider>
              <StatusBar
                barStyle="dark-content"
                backgroundColor="transparent"
                translucent={Platform.OS === 'android'}
              />
              <RootNavigator />
            </OrderMonitorProvider>
          </ThemeProvider>
        </QueryClientProvider>
      </StripeProvider>
    </GestureHandlerRootView>
  );
}
