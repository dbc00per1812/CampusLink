// Stripe Service - Handle Stripe payments and Connect
import { supabase } from '../config/supabase';
import { STRIPE_PUBLISHABLE_KEY } from '../config/secrets';

// Initialize Stripe (will be done when SDK is properly integrated)
let stripe: any = null;

export const initializeStripe = async () => {
  // Stripe initialization will be done via @stripe/stripe-react-native
  // This is a placeholder for the SDK setup
  console.log('Stripe initialized with key:', STRIPE_PUBLISHABLE_KEY.substring(0, 10) + '...');
};

// Create a payment intent for an order
export const createPaymentIntent = async (
  orderId: string,
  amount: number
): Promise<{ clientSecret: string; paymentIntentId: string }> => {
  const { data, error } = await supabase.functions.invoke('create-payment-intent', {
    body: { orderId, amount },
  });

  if (error) throw error;
  return data;
};

// Confirm payment with payment method
export const confirmPayment = async (
  clientSecret: string,
  paymentMethodId: string
): Promise<{ success: boolean; error?: string }> => {
  // This will be implemented with @stripe/stripe-react-native
  // For now, return placeholder
  try {
    // stripe.confirmPayment(clientSecret, { paymentMethodId });
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
};

// Create Stripe Connect onboarding link
export const createConnectAccountLink = async (): Promise<string> => {
  const { data, error } = await supabase.functions.invoke('create-connect-account-link', {
    body: { 
      refreshUrl: 'campuslink://wallet',
      returnUrl: 'campuslink://wallet',
    },
  });

  if (error) throw error;
  return data.url;
};

// Create Stripe Connect account
export const createConnectAccount = async (): Promise<string> => {
  const { data, error } = await supabase.functions.invoke('create-connect-account', {
    body: {},
  });

  if (error) throw error;
  return data.accountId;
};

// Get Stripe Connect account status
export const getConnectAccountStatus = async (): Promise<{
  hasAccount: boolean;
  isEnabled: boolean;
  detailsSubmitted: boolean;
}> => {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.user) {
    return { hasAccount: false, isEnabled: false, detailsSubmitted: false };
  }

  const { data } = await supabase
    .from('users')
    .select('stripe_connect_id, stripe_payouts_enabled, stripe_details_submitted')
    .eq('id', session.user.id)
    .single();

  return {
    hasAccount: !!data?.stripe_connect_id,
    isEnabled: data?.stripe_payouts_enabled ?? false,
    detailsSubmitted: data?.stripe_details_submitted ?? false,
  };
};

// Create a payout
export const createPayout = async (amount: number): Promise<{ success: boolean }> => {
  const { data, error } = await supabase.functions.invoke('create-payout', {
    body: { amount },
  });

  if (error) throw error;
  return { success: true };
};

export default {
  initializeStripe,
  createPaymentIntent,
  confirmPayment,
  createConnectAccountLink,
  createConnectAccount,
  getConnectAccountStatus,
  createPayout,
};

