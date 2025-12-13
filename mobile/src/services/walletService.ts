// Wallet Service - Converted from WalletService.swift
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

// Get wallet balance (formatted)
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

// Request a payout
export const requestPayout = async (
  amountCents: number,
  destination: 'stripe_connect' | 'bank_account' = 'stripe_connect'
): Promise<Payout> => {
  const userId = await getCurrentUserId();

  // Verify sufficient balance
  const wallet = await getOrCreateWallet();
  if (wallet.available_cents < amountCents) {
    throw new Error('Insufficient funds');
  }

  // Call RPC to process payout
  const { data, error } = await supabase.rpc('request_payout', {
    p_user_id: userId,
    p_amount_cents: amountCents,
    p_destination: destination,
  });

  if (error) throw error;
  return data;
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

// Alias for getBalance
export const getWalletBalance = async () => {
  const balance = await getBalance();
  return { available: balance.available, pending: 0, escrow: balance.escrow };
};

// Alias for getTransactions
export const getTransactionHistory = getTransactions;

// Alias for getPayouts  
export const getPayoutHistory = getPayouts;

export default {
  getWallet,
  getOrCreateWallet,
  getBalance,
  getWalletBalance,
  getTransactions,
  getTransactionHistory,
  getPayouts,
  getPayoutHistory,
  requestPayout,
  canWithdraw,
  getPendingPayoutAmount,
};

