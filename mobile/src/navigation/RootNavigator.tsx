// Root Navigator - Handles Auth State
import React, { useEffect, useState, useCallback, useRef } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Session } from '@supabase/supabase-js';
import { Alert, View, ActivityIndicator, StyleSheet } from 'react-native';
import * as SplashScreen from 'expo-splash-screen';

import { RootStackParamList } from './types';
import AuthNavigator from './AuthNavigator';
import TabNavigator from './TabNavigator';
import { supabase } from '../config/supabase';
import { signOut } from '../services/authService';
import { registerUserForNotifications } from '../services/notificationService';

const Stack = createNativeStackNavigator<RootStackParamList>();

// Track if splash has been hidden to prevent multiple calls
let splashHidden = false;

const hideSplashScreen = async () => {
  if (splashHidden) return;
  splashHidden = true;
  try {
    await SplashScreen.hideAsync();
    console.log('✅ Splash screen hidden');
  } catch (error) {
    // Ignore - splash might already be hidden
  }
};

export const RootNavigator: React.FC = () => {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const navigationReady = useRef(false);

  // Verify user has a valid profile in the database
  const verifyUserProfile = async (userId: string): Promise<boolean> => {
    try {
      console.log('🔍 Verifying user profile for', userId);
      
      const { data, error } = await supabase
        .from('users')
        .select('id, name, email, campus')
        .eq('id', userId)
        .single();
      
      if (error || !data) {
        console.error('❌ Profile verification failed:', error);
        
        // Profile missing - force re-authentication
        await signOut();
        
        Alert.alert(
          'Profile Error',
          'Your profile is incomplete. Please sign up again.',
          [{ text: 'OK' }]
        );
        
        return false;
      }
      
      console.log('✅ Profile verified successfully');
      return true;
    } catch (error) {
      console.error('❌ Profile verification error:', error);
      return false;
    }
  };

  useEffect(() => {
    // Get initial session
    const initializeAuth = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        
        if (session?.user) {
          // Verify profile exists before allowing app access
          const profileExists = await verifyUserProfile(session.user.id);
          if (profileExists) {
            setSession(session);
            // Register user for push notifications
            registerUserForNotifications(session.user.id).catch((error) => {
              console.error('Failed to register for notifications:', error);
            });
          } else {
            setSession(null);
          }
        } else {
          setSession(session);
        }
      } catch (error) {
        console.error('❌ Auth initialization error:', error);
        setSession(null);
      } finally {
        setLoading(false);
      }
    };

    initializeAuth();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (_event, session) => {
        if (session?.user) {
          // Verify profile exists for new sessions
          const profileExists = await verifyUserProfile(session.user.id);
          if (profileExists) {
            setSession(session);
            // Register user for push notifications
            registerUserForNotifications(session.user.id).catch((error) => {
              console.error('Failed to register for notifications:', error);
            });
          } else {
            setSession(null);
          }
        } else {
          setSession(session);
        }
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  // Failsafe: Hide splash screen after 3 seconds no matter what
  useEffect(() => {
    const failsafeTimeout = setTimeout(() => {
      console.log('⏰ Splash screen failsafe timeout triggered');
      hideSplashScreen();
    }, 3000);

    return () => clearTimeout(failsafeTimeout);
  }, []);

  // Hide splash when both conditions are met: loading complete AND navigation ready
  useEffect(() => {
    if (!loading && navigationReady.current) {
      hideSplashScreen();
    }
  }, [loading]);

  // Called when NavigationContainer is ready
  const onNavigationReady = useCallback(() => {
    navigationReady.current = true;
    // If loading is already complete, hide splash now
    if (!loading) {
      hideSplashScreen();
    }
  }, [loading]);

  // Show a loading indicator while initializing (fallback if splash hides early)
  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#FFFFFF" />
      </View>
    );
  }

  return (
    <NavigationContainer onReady={onNavigationReady}>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {session ? (
          <Stack.Screen name="Main" component={TabNavigator} />
        ) : (
          <Stack.Screen name="Auth" component={AuthNavigator} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#4285F4',
  },
});

export default RootNavigator;

