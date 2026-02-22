// Offer Monitor Context - Shares pending offer state across the app
import React, { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import { Offer } from '../types';
import { supabase } from '../config/supabase';

interface OfferMonitorContextType {
  pendingReceivedOffers: Offer[];
  pendingSentOffers: Offer[];
  pendingReceivedCount: number;
  pendingSentCount: number;
  totalPendingCount: number;
  isMonitoring: boolean;
  refreshOffers: () => Promise<void>;
}

const OfferMonitorContext = createContext<OfferMonitorContextType | undefined>(undefined);

interface OfferMonitorProviderProps {
  children: ReactNode;
}

// Check interval in milliseconds (5 minutes like iOS)
const CHECK_INTERVAL = 5 * 60 * 1000;

export const OfferMonitorProvider: React.FC<OfferMonitorProviderProps> = ({ children }) => {
  const [pendingReceivedOffers, setPendingReceivedOffers] = useState<Offer[]>([]);
  const [pendingSentOffers, setPendingSentOffers] = useState<Offer[]>([]);
  const [isMonitoring, setIsMonitoring] = useState<boolean>(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  // Load pending offers for the current user
  const loadPendingOffers = useCallback(async (userId: string) => {
    try {
      // Load received offers that are pending (need user action)
      // Use explicit FK name because offers has 3 FKs to listings
      const { data: received, error: receivedError } = await supabase
        .from('offers')
        .select('*, listing:listings!offers_listing_id_fkey(*), offer_from:users!offer_from_user_id(*)')
        .eq('offer_to_user_id', userId)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

      if (receivedError) {
        console.error('❌ Error loading received offers:', receivedError);
      } else {
        setPendingReceivedOffers(received ?? []);
        console.log(`📬 Loaded ${received?.length ?? 0} pending received offers`);
      }

      // Load sent offers that are pending (waiting for response)
      // Use explicit FK name because offers has 3 FKs to listings
      const { data: sent, error: sentError } = await supabase
        .from('offers')
        .select('*, listing:listings!offers_listing_id_fkey(*), offer_to:users!offer_to_user_id(*)')
        .eq('offer_from_user_id', userId)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

      if (sentError) {
        console.error('❌ Error loading sent offers:', sentError);
      } else {
        setPendingSentOffers(sent ?? []);
        console.log(`📤 Loaded ${sent?.length ?? 0} pending sent offers`);
      }
    } catch (error) {
      console.error('❌ Error in loadPendingOffers:', error);
    }
  }, []);

  // Initialize monitoring when user logs in
  useEffect(() => {
    let intervalId: NodeJS.Timeout | null = null;

    const initializeMonitoring = async () => {
      try {
        // Get current user
        const { data: { session } } = await supabase.auth.getSession();
        
        if (session?.user) {
          setCurrentUserId(session.user.id);
          
          // Initial load
          await loadPendingOffers(session.user.id);
          
          // Set up periodic checks
          intervalId = setInterval(() => {
            loadPendingOffers(session.user.id);
          }, CHECK_INTERVAL);
          
          setIsMonitoring(true);
          console.log('✅ Offer monitoring initialized');
        }
      } catch (error) {
        console.error('❌ Error initializing offer monitoring:', error);
      }
    };

    initializeMonitoring();

    // Listen for auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session?.user) {
        setCurrentUserId(session.user.id);
        await loadPendingOffers(session.user.id);
        
        // Clear any existing interval and set new one
        if (intervalId) clearInterval(intervalId);
        intervalId = setInterval(() => {
          loadPendingOffers(session.user.id);
        }, CHECK_INTERVAL);
        
        setIsMonitoring(true);
      } else if (event === 'SIGNED_OUT') {
        if (intervalId) clearInterval(intervalId);
        setPendingReceivedOffers([]);
        setPendingSentOffers([]);
        setIsMonitoring(false);
        setCurrentUserId(null);
      }
    });

    // Cleanup on unmount
    return () => {
      subscription.unsubscribe();
      if (intervalId) clearInterval(intervalId);
    };
  }, [loadPendingOffers]);

  // Set up real-time subscription for offers
  useEffect(() => {
    if (!currentUserId) return;

    // Subscribe to changes in offers table
    const channel = supabase
      .channel('offer-changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'offers',
          filter: `offer_to_user_id=eq.${currentUserId}`,
        },
        () => {
          console.log('📬 Offer change detected (received)');
          loadPendingOffers(currentUserId);
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'offers',
          filter: `offer_from_user_id=eq.${currentUserId}`,
        },
        () => {
          console.log('📤 Offer change detected (sent)');
          loadPendingOffers(currentUserId);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [currentUserId, loadPendingOffers]);

  // Manual refresh function
  const refreshOffers = useCallback(async () => {
    if (currentUserId) {
      await loadPendingOffers(currentUserId);
    }
  }, [currentUserId, loadPendingOffers]);

  const pendingReceivedCount = pendingReceivedOffers.length;
  const pendingSentCount = pendingSentOffers.length;
  const totalPendingCount = pendingReceivedCount + pendingSentCount;

  return (
    <OfferMonitorContext.Provider
      value={{
        pendingReceivedOffers,
        pendingSentOffers,
        pendingReceivedCount,
        pendingSentCount,
        totalPendingCount,
        isMonitoring,
        refreshOffers,
      }}
    >
      {children}
    </OfferMonitorContext.Provider>
  );
};

// Custom hook to use the offer monitor context
export const useOfferMonitor = (): OfferMonitorContextType => {
  const context = useContext(OfferMonitorContext);
  
  if (context === undefined) {
    throw new Error('useOfferMonitor must be used within an OfferMonitorProvider');
  }
  
  return context;
};

export default OfferMonitorContext;
