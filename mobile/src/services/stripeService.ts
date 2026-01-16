// Stripe Service - Handle Stripe payments and Connect
import { supabase } from '../config/supabase';
import { initPaymentSheet, presentPaymentSheet } from '@stripe/stripe-react-native';

/**
 * Payment Intent Response from Edge Function
 */
interface PaymentIntentResponse {
  client_secret: string;
  payment_intent_id: string;
  seller_price_cents: number;
  buyer_price_cents: number;
  stripe_fee_cents: number;
  campuslink_cut_cents: number;
  application_fee_cents: number;
  seller_receives_cents: number;
}

/**
 * Payment Result from PaymentSheet
 */
export interface PaymentResult {
  success: boolean;
  error?: string;
}

/**
 * Configure PaymentSheet for a listing purchase
 * @param listingId - The ID of the listing to purchase
 * @returns Payment intent details
 */
export const configurePaymentSheet = async (
  listingId: string
): Promise<PaymentIntentResponse> => {
  try {
    console.log('💳 Configuring PaymentSheet for listing:', listingId);

    // Call edge function to create payment intent
    const { data, error } = await supabase.functions.invoke('create_payment_intent', {
      body: { listing_id: listingId },
    });

    if (error) {
      console.error('❌ Error creating payment intent:', error);
      throw new Error(error.message || 'Failed to create payment intent');
    }

    if (!data?.client_secret) {
      throw new Error('No client secret returned from payment intent');
    }

    console.log('✅ Payment intent created:', data.payment_intent_id);
    console.log('   Buyer pays:', `$${data.buyer_price_cents / 100}`);
    console.log('   Seller receives:', `$${data.seller_receives_cents / 100}`);

    // Initialize PaymentSheet with the client secret and payment method configuration
    const { error: initError } = await initPaymentSheet({
      merchantDisplayName: 'CampusLink',
      paymentIntentClientSecret: data.client_secret,
      defaultBillingDetails: {
        name: '',
      },
      returnURL: 'campuslink://payment-complete',
      allowsDelayedPaymentMethods: false,
      // Enable Apple Pay on iOS
      applePay: {
        merchantCountryCode: 'US',
        merchantId: 'merchant.campuslink.com.campuslink',
      },
      // Enable Google Pay on Android
      googlePay: {
        merchantCountryCode: 'US',
        testEnv: __DEV__, // Use test environment in development
        currencyCode: 'USD',
      },
      // Primary button label
      primaryButtonLabel: 'Pay {{amount}}',
    });

    if (initError) {
      console.error('❌ Error initializing PaymentSheet:', initError);
      throw new Error(initError.message || 'Failed to initialize PaymentSheet');
    }

    console.log('✅ PaymentSheet initialized successfully with Apple Pay and Google Pay');

    return {
      client_secret: data.client_secret,
      payment_intent_id: data.payment_intent_id,
      seller_price_cents: data.seller_price_cents,
      buyer_price_cents: data.buyer_price_cents,
      stripe_fee_cents: data.stripe_fee_cents,
      campuslink_cut_cents: data.campuslink_cut_cents,
      application_fee_cents: data.application_fee_cents,
      seller_receives_cents: data.seller_receives_cents,
    };
  } catch (error: any) {
    console.error('❌ Error in configurePaymentSheet:', error);
    throw error;
  }
};

/**
 * Configure PaymentSheet for an existing order (e.g., accepted offer)
 * @param orderId - The ID of the order to pay for
 * @returns Payment intent details
 */
export const configurePaymentSheetForOrder = async (
  orderId: string
): Promise<PaymentIntentResponse> => {
  try {
    console.log('💳 Configuring PaymentSheet for order:', orderId);

    // Call edge function to create payment intent for existing order
    const { data, error } = await supabase.functions.invoke('create_payment_intent', {
      body: { order_id: orderId },
    });

    if (error) {
      console.error('❌ Error creating payment intent:', error);
      throw new Error(error.message || 'Failed to create payment intent');
    }

    if (!data?.client_secret) {
      throw new Error('No client secret returned from payment intent');
    }

    console.log('✅ Payment intent created for order:', data.payment_intent_id);
    console.log('   Buyer pays:', `$${data.buyer_price_cents / 100}`);

    // Initialize PaymentSheet with the client secret and payment method configuration
    const { error: initError } = await initPaymentSheet({
      merchantDisplayName: 'CampusLink',
      paymentIntentClientSecret: data.client_secret,
      defaultBillingDetails: {
        name: '',
      },
      returnURL: 'campuslink://payment-complete',
      allowsDelayedPaymentMethods: false,
      // Enable Apple Pay on iOS
      applePay: {
        merchantCountryCode: 'US',
        merchantId: 'merchant.campuslink.com.campuslink',
      },
      // Enable Google Pay on Android
      googlePay: {
        merchantCountryCode: 'US',
        testEnv: __DEV__, // Use test environment in development
        currencyCode: 'USD',
      },
      // Primary button label
      primaryButtonLabel: 'Pay {{amount}}',
    });

    if (initError) {
      console.error('❌ Error initializing PaymentSheet:', initError);
      throw new Error(initError.message || 'Failed to initialize PaymentSheet');
    }

    console.log('✅ PaymentSheet initialized successfully with Apple Pay and Google Pay');

    return {
      client_secret: data.client_secret,
      payment_intent_id: data.payment_intent_id,
      seller_price_cents: data.seller_price_cents,
      buyer_price_cents: data.buyer_price_cents,
      stripe_fee_cents: data.stripe_fee_cents,
      campuslink_cut_cents: data.campuslink_cut_cents,
      application_fee_cents: data.application_fee_cents,
      seller_receives_cents: data.seller_receives_cents,
    };
  } catch (error: any) {
    console.error('❌ Error in configurePaymentSheetForOrder:', error);
    throw error;
  }
};

/**
 * Present the Stripe PaymentSheet to the user
 * @returns Payment result indicating success or failure
 */
export const presentStripePaymentSheet = async (): Promise<PaymentResult> => {
  try {
    console.log('💳 Presenting PaymentSheet...');

    const { error } = await presentPaymentSheet();

    if (error) {
      // User cancelled - this is normal, not an error
      if (error.code === 'Canceled') {
        console.log('ℹ️ Payment cancelled by user');
        return {
          success: false,
          error: 'Payment cancelled',
        };
      }

      // Actual error
      console.error('❌ PaymentSheet error:', error);
      return {
        success: false,
        error: error.message || 'Payment failed',
      };
    }

    console.log('✅ Payment completed successfully');

    return {
      success: true,
    };
  } catch (error: any) {
    console.error('❌ Error presenting PaymentSheet:', error);
    return {
      success: false,
      error: error.message || 'An unexpected error occurred',
    };
  }
};

// Create Stripe Connect onboarding link
export const createConnectAccountLink = async (): Promise<string> => {
  // Use HTTPS redirect URLs that Stripe accepts, then redirect to app deep link
  // This matches the Swift implementation
  const { data, error } = await supabase.functions.invoke('connect_onboarding', {
    body: { 
      return_url: 'https://stripe-redirect.netlify.app/stripe-return.html',
      refresh_url: 'https://stripe-redirect.netlify.app/stripe-refresh.html',
    },
  });

  if (error) throw error;
  if (data?.onboarding_complete) {
    throw new Error('Account already set up');
  }
  return data.onboarding_url;
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

export default {
  configurePaymentSheet,
  configurePaymentSheetForOrder,
  presentStripePaymentSheet,
  createConnectAccountLink,
  getConnectAccountStatus,
};

