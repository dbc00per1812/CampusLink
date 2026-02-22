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

// Auth initialization timeout (5 seconds max)
const AUTH_TIMEOUT_MS = 5000;

// Helper to create a timeout promise
const withTimeout = <T,>(promise: Promise<T>, ms: number): Promise<T> => {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error('Auth timeout')), ms)
    ),
  ]);
};

export const RootNavigator: React.FC = () => {
  const [session, setSession] = useState<Session | null>(null);
  const [isReady, setIsReady] = useState(false);
  const splashHiddenRef = useRef(false);
  const navigationReadyRef = useRef(false);
  const authInitializedRef = useRef(false);

  // Hide splash screen once - uses ref to prevent multiple calls
  const hideSplash = useCallback(async () => {
    if (splashHiddenRef.current) return;
    splashHiddenRef.current = true;
    try {
      await SplashScreen.hideAsync();
      console.log('✅ Splash screen hidden');
    } catch (error) {
      // Splash might already be hidden - that's fine
    }
  }, []);

  // Try to hide splash when both auth and navigation are ready
  const tryHideSplash = useCallback(() => {
    if (authInitializedRef.current && navigationReadyRef.current) {
      hideSplash();
    }
  }, [hideSplash]);

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
    let isMounted = true;

    // Get initial session with timeout protection
    const initializeAuth = async () => {
      try {
        console.log('🔐 Starting auth initialization...');
        
        const { data: { session } } = await withTimeout(
          supabase.auth.getSession(),
          AUTH_TIMEOUT_MS
        );
        
        if (!isMounted) return;
        
        if (session?.user) {
          // Verify profile exists before allowing app access
          // Use a shorter timeout for profile check
          try {
            const profileExists = await withTimeout(
              verifyUserProfile(session.user.id),
              3000
            );
            
            if (!isMounted) return;
            
            if (profileExists) {
              setSession(session);
              // Register for push notifications in background
              registerUserForNotifications(session.user.id).catch((error) => {
                console.error('Failed to register for notifications:', error);
              });
            } else {
              setSession(null);
            }
          } catch (profileError) {
            console.error('❌ Profile verification timeout:', profileError);
            // On timeout, allow access anyway - they have a valid session
            if (isMounted) {
              setSession(session);
            }
          }
        } else {
          setSession(null);
        }
      } catch (error) {
        console.error('❌ Auth initialization error:', error);
        if (isMounted) {
          setSession(null);
        }
      } finally {
        if (isMounted) {
          authInitializedRef.current = true;
          setIsReady(true);
          tryHideSplash();
          console.log('✅ Auth initialization complete');
        }
      }
    };

    initializeAuth();

    // Listen for auth changes (after initial load)
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (_event, newSession) => {
        if (!isMounted) return;
        
        if (newSession?.user) {
          // Verify profile exists for new sessions
          try {
            const profileExists = await withTimeout(
              verifyUserProfile(newSession.user.id),
              3000
            );
            
            if (!isMounted) return;
            
            if (profileExists) {
              setSession(newSession);
              registerUserForNotifications(newSession.user.id).catch((error) => {
                console.error('Failed to register for notifications:', error);
              });
            } else {
              setSession(null);
            }
          } catch (error) {
            // On timeout, allow access - they have a valid session
            if (isMounted) {
              setSession(newSession);
            }
          }
        } else {
          setSession(newSession);
        }
      }
    );

    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, [tryHideSplash]);

  // Failsafe: Hide splash after 4 seconds AND mark as ready
  // This ensures the app is usable even if something hangs
  useEffect(() => {
    const failsafeTimeout = setTimeout(() => {
      if (!authInitializedRef.current) {
        console.log('⏰ Auth failsafe timeout - forcing ready state');
        authInitializedRef.current = true;
        setIsReady(true);
      }
      hideSplash();
    }, 4000);

    return () => clearTimeout(failsafeTimeout);
  }, [hideSplash]);

  // Called when NavigationContainer is ready
  const onNavigationReady = useCallback(() => {
    console.log('🧭 Navigation ready');
    navigationReadyRef.current = true;
    tryHideSplash();
  }, [tryHideSplash]);

  // Show a loading indicator while initializing
  if (!isReady) {
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

