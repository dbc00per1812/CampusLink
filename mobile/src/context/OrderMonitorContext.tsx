// Order Monitor Context - Shares active order state across the app
import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { Order } from '../types';
import { 
  startMonitoring, 
  stopMonitoring, 
  getCachedActiveOrders,
  getActiveOrderCount,
} from '../services/activeOrderMonitor';
import { supabase } from '../config/supabase';

interface OrderMonitorContextType {
  activeOrders: Order[];
  activeOrderCount: number;
  isMonitoring: boolean;
  refreshActiveOrders: () => Promise<void>;
}

const OrderMonitorContext = createContext<OrderMonitorContextType | undefined>(undefined);

interface OrderMonitorProviderProps {
  children: ReactNode;
}

export const OrderMonitorProvider: React.FC<OrderMonitorProviderProps> = ({ children }) => {
  const [activeOrders, setActiveOrders] = useState<Order[]>([]);
  const [activeOrderCount, setActiveOrderCount] = useState<number>(0);
  const [isMonitoring, setIsMonitoring] = useState<boolean>(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  // Initialize monitoring when user logs in
  useEffect(() => {
    const initializeMonitoring = async () => {
      try {
        // Get current user
        const { data: { session } } = await supabase.auth.getSession();
        
        if (session?.user) {
          setCurrentUserId(session.user.id);
          
          // Start monitoring with callback
          await startMonitoring(session.user.id, (orders) => {
            setActiveOrders(orders);
            setActiveOrderCount(getActiveOrderCount(session.user.id));
          });
          
          setIsMonitoring(true);
          console.log('✅ Order monitoring initialized');
        }
      } catch (error) {
        console.error('❌ Error initializing order monitoring:', error);
      }
    };

    initializeMonitoring();

    // Listen for auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session?.user) {
        setCurrentUserId(session.user.id);
        await startMonitoring(session.user.id, (orders) => {
          setActiveOrders(orders);
          setActiveOrderCount(getActiveOrderCount(session.user.id));
        });
        setIsMonitoring(true);
      } else if (event === 'SIGNED_OUT') {
        stopMonitoring();
        setActiveOrders([]);
        setActiveOrderCount(0);
        setIsMonitoring(false);
        setCurrentUserId(null);
      }
    });

    // Cleanup on unmount
    return () => {
      subscription.unsubscribe();
      stopMonitoring();
    };
  }, []);

  // Manual refresh function
  const refreshActiveOrders = async () => {
    if (currentUserId) {
      try {
        const { checkActiveOrders } = await import('../services/activeOrderMonitor');
        const orders = await checkActiveOrders(currentUserId);
        setActiveOrders(orders);
        setActiveOrderCount(getActiveOrderCount(currentUserId));
      } catch (error) {
        console.error('❌ Error refreshing active orders:', error);
      }
    }
  };

  return (
    <OrderMonitorContext.Provider
      value={{
        activeOrders,
        activeOrderCount,
        isMonitoring,
        refreshActiveOrders,
      }}
    >
      {children}
    </OrderMonitorContext.Provider>
  );
};

// Custom hook to use the order monitor context
export const useOrderMonitor = (): OrderMonitorContextType => {
  const context = useContext(OrderMonitorContext);
  
  if (context === undefined) {
    throw new Error('useOrderMonitor must be used within an OrderMonitorProvider');
  }
  
  return context;
};

export default OrderMonitorContext;
