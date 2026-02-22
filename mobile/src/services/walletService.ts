// Wallet Service - Converted from WalletService.swift
// 
// IMPORTANT: Stripe is the SINGLE SOURCE OF TRUTH for balance
// The local 'wallets' table is only used for in-app wallet payment tracking
// All balance displays should use getWalletBalance() which queries Stripe
//
import { supabase } from '../config/supabase';
import { Wallet, WalletTransaction, Payout, PayoutStatus } from '../types';

// Get current user ID
const getCurrentUserId = async (): Promise<string> => {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.user.id) throw new Error('No active session');
  return session.user.id;
};

// Get user's wallet
export const getWallet = async (): Promise<Wallet | null> => {
  const userId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('wallets')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (error) {
    if (error.code === 'PGRST116') return null; // Not found
    throw error;
  }

  return data;
};

// Get or create wallet
export const getOrCreateWallet = async (): Promise<Wallet> => {
  const userId = await getCurrentUserId();

  // Try to get existing wallet
  const { data: existing, error: fetchError } = await supabase
    .from('wallets')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (existing) return existing;

  // Create new wallet if doesn't exist
  const { data: newWallet, error: createError } = await supabase
    .from('wallets')
    .insert({
      user_id: userId,
      available_cents: 0,
      escrow_cents: 0,
    })
    .select()
    .single();

  if (createError) throw createError;
  return newWallet;
};

// Get LOCAL wallet balance (for in-app wallet payments only)
// ⚠️ DEPRECATED: Use getWalletBalance() for the real balance from Stripe
// This only shows the local database balance, not actual Stripe funds
export const getBalance = async (): Promise<{
  available: number;
  escrow: number;
  total: number;
  formatted: {
    available: string;
    escrow: string;
    total: string;
  };
}> => {
  // For actual balance, use getWalletBalance() which queries Stripe
  console.warn('⚠️ getBalance() uses local DB. Use getWalletBalance() for Stripe balance (source of truth)');
  
  const wallet = await getOrCreateWallet();

  const available = wallet.available_cents / 100;
  const escrow = wallet.escrow_cents / 100;
  const total = available + escrow;

  return {
    available,
    escrow,
    total,
    formatted: {
      available: `$${available.toFixed(2)}`,
      escrow: `$${escrow.toFixed(2)}`,
      total: `$${total.toFixed(2)}`,
    },
  };
};

// Get transaction history
export const getTransactions = async (limit = 50): Promise<WalletTransaction[]> => {
  const userId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('wallet_transactions')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) {
    // Table might not exist - return empty array
    console.warn('Could not fetch transactions:', error);
    return [];
  }

  return data ?? [];
};

// Get payout history
export const getPayouts = async (limit = 50): Promise<Payout[]> => {
  const userId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('payouts')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
};

// Get REAL balance from Stripe (source of truth)
export const getStripeBalance = async (): Promise<{
  available: number;
  pending: number;
  error?: string;
}> => {
  try {
    const { data, error } = await supabase.functions.invoke('get-stripe-balance');
    
    if (error) {
      console.error('Error fetching Stripe balance:', error);
      return { available: 0, pending: 0, error: error.message };
    }

    // Convert cents to dollars
    return {
      available: (data?.available_for_standard_cents || 0) / 100,
      pending: (data?.pending_cents || 0) / 100,
      error: data?.error,
    };
  } catch (err: any) {
    console.error('Error invoking get-stripe-balance:', err);
    return { available: 0, pending: 0, error: err.message };
  }
};

// Request a payout
export const requestPayout = async (
  amountCents: number,
  destination: 'stripe_connect' | 'bank_account' = 'stripe_connect'
): Promise<Payout> => {
  const userId = await getCurrentUserId();

  // Verify sufficient balance using REAL Stripe balance
  const stripeBalance = await getStripeBalance();
  const availableCents = Math.round(stripeBalance.available * 100);
  
  if (amountCents > availableCents) {
    throw new Error(`Insufficient funds. Available: $${stripeBalance.available.toFixed(2)}`);
  }

  // Step 1: Call RPC to create payout record
  // Note: auth.uid() is used server-side for security — no need to pass user ID
  const { data: payout, error } = await supabase.rpc('request_payout', {
    p_amount_cents: amountCents,
    p_destination: destination,
  });

  if (error) throw error;

  // Step 2: Call process-payout edge function to actually process with Stripe
  // This matches the Swift implementation flow
  console.log('🔄 Calling process-payout Edge Function for payout:', payout.id);
  
  const { data: processResult, error: processError } = await supabase.functions.invoke('process-payout', {
    body: { payout_id: payout.id },
  });

  if (processError) {
    console.error('❌ Payout processing failed:', processError);
    throw new Error('Failed to initiate payout with Stripe. Please contact support.');
  }

  if (processResult?.error) {
    console.error('❌ Payout processing failed:', processResult.error);
    throw new Error(processResult.error);
  }

  console.log('✅ Payout processing initiated. Stripe Payout ID:', processResult?.stripe_payout_id);
  
  return payout;
};

// Check if user can withdraw (has completed Stripe onboarding)
export const canWithdraw = async (): Promise<{
  canWithdraw: boolean;
  reason?: string;
}> => {
  const userId = await getCurrentUserId();

  const { data: user, error } = await supabase
    .from('users')
    .select('stripe_connect_id, stripe_payouts_enabled')
    .eq('id', userId)
    .single();

  if (error) throw error;

  if (!user.stripe_connect_id) {
    return {
      canWithdraw: false,
      reason: 'Please complete payout setup to withdraw funds.',
    };
  }

  if (!user.stripe_payouts_enabled) {
    return {
      canWithdraw: false,
      reason: 'Payout setup is incomplete. Please complete verification.',
    };
  }

  return { canWithdraw: true };
};

// Get pending payout amount
export const getPendingPayoutAmount = async (): Promise<number> => {
  const userId = await getCurrentUserId();

  const { data, error } = await supabase
    .from('payouts')
    .select('amount_cents')
    .eq('user_id', userId)
    .in('status', ['pending', 'processing', 'in_transit']);

  if (error) throw error;

  return (data ?? []).reduce((sum, p) => sum + p.amount_cents, 0);
};

// Get pending payouts for sellers who haven't completed Stripe setup
// These are funds held in platform account waiting for seller onboarding
export const getPendingSellerPayouts = async (): Promise<number> => {
  try {
    const userId = await getCurrentUserId();
    
    const { data, error } = await supabase
      .from('pending_seller_payouts')
      .select('amount_cents')
      .eq('seller_id', userId)
      .eq('status', 'pending');

    if (error) {
      console.warn('Could not fetch pending seller payouts:', error);
      return 0;
    }

    const totalCents = (data ?? []).reduce((sum, p) => sum + p.amount_cents, 0);
    return totalCents / 100;
  } catch (err) {
    console.warn('Error fetching pending seller payouts:', err);
    return 0;
  }
};

// PRIMARY BALANCE FUNCTION - Uses Stripe as source of truth
// This is what should be displayed to users in the wallet screen
export const getWalletBalance = async () => {
  // Get the REAL balance from Stripe Connect account
  // This is the actual money available for payout
  const stripeBalance = await getStripeBalance();
  
  // Also check for pending payouts (funds held before Stripe onboarding)
  const pendingPayouts = await getPendingSellerPayouts();
  
  return { 
    available: stripeBalance.available, 
    pending: stripeBalance.pending,
    pendingOnboarding: pendingPayouts, // Funds waiting for Stripe setup
  };
};

// Alias for getTransactions
export const getTransactionHistory = getTransactions;

// Alias for getPayouts  
export const getPayoutHistory = getPayouts;

export default {
  getWallet,
  getOrCreateWallet,
  getBalance,
  getStripeBalance,
  getWalletBalance,
  getTransactions,
  getTransactionHistory,
  getPayouts,
  getPayoutHistory,
  requestPayout,
  canWithdraw,
  getPendingPayoutAmount,
};

