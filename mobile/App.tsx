// CampusLink - React Native App Entry Point
import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StripeProvider } from '@stripe/stripe-react-native';

import { ThemeProvider, useIsDarkMode, OrderMonitorProvider } from './src/context';
import RootNavigator from './src/navigation/RootNavigator';
import { STRIPE_PUBLISHABLE_KEY } from './src/config/secrets';

// Create a client for React Query
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 1000 * 60 * 5, // 5 minutes
    },
  },
});

// App content with theme-aware status bar
const AppContent: React.FC = () => {
  const isDarkMode = useIsDarkMode();
  
  return (
    <>
      <StatusBar style={isDarkMode ? 'light' : 'dark'} />
      <RootNavigator />
    </>
  );
};

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <StripeProvider
          publishableKey={STRIPE_PUBLISHABLE_KEY}
          merchantIdentifier="merchant.com.campuslink"
        >
          <QueryClientProvider client={queryClient}>
            <ThemeProvider>
              <OrderMonitorProvider>
                <AppContent />
              </OrderMonitorProvider>
            </ThemeProvider>
          </QueryClientProvider>
        </StripeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
