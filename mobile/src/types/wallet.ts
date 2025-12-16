// Wallet Types - Converted from WalletModels.swift

export type PayoutStatus =
  | 'pending'
  | 'processing'
  | 'in_transit'
  | 'completed'
  | 'paid'
  | 'failed'
  | 'cancelled';

export type TransactionType =
  | 'order_payment'
  | 'escrow_release'
  | 'payout'
  | 'refund'
  | 'fee'
  | 'adjustment';

export type PayoutDestination = 'stripe_connect' | 'bank_account' | 'venmo';

// Display helpers
export const PayoutStatusDisplay: Record<PayoutStatus, string> = {
  pending: 'Pending',
  processing: 'Processing',
  in_transit: 'In Transit',
  completed: 'Completed',
  paid: 'Paid',
  failed: 'Failed',
  cancelled: 'Cancelled',
};

export const PayoutStatusIcon: Record<PayoutStatus, string> = {
  pending: 'clock',
  processing: 'refresh-cw',
  in_transit: 'arrow-right-circle',
  completed: 'check-circle',
  paid: 'check-circle',
  failed: 'x-circle',
  cancelled: 'slash',
};

export const PayoutStatusColor: Record<PayoutStatus, string> = {
  pending: '#F97316', // orange
  processing: '#F97316', // orange
  in_transit: '#F97316', // orange
  completed: '#22C55E', // green
  paid: '#22C55E', // green
  failed: '#EF4444', // red
  cancelled: '#EF4444', // red
};

export const TransactionTypeDisplay: Record<TransactionType, string> = {
  order_payment: 'Order Payment',
  escrow_release: 'Escrow Released',
  payout: 'Withdrawal',
  refund: 'Refund',
  fee: 'Platform Fee',
  adjustment: 'Adjustment',
};

export const TransactionTypeIcon: Record<TransactionType, string> = {
  order_payment: 'shopping-cart',
  escrow_release: 'unlock',
  payout: 'dollar-sign',
  refund: 'corner-up-left',
  fee: 'percent',
  adjustment: 'sliders',
};

export const PayoutDestinationDisplay: Record<PayoutDestination, string> = {
  stripe_connect: 'Bank Account (via Stripe)',
  bank_account: 'Bank Account',
  venmo: 'Venmo',
};

// Wallet interface
export interface Wallet {
  user_id: string;
  available_cents: number;
  escrow_cents: number;
  updated_at: string;
}

// Wallet helper functions
export const getAvailableBalance = (wallet: Wallet): number => {
  return wallet.available_cents / 100;
};

export const getEscrowBalance = (wallet: Wallet): number => {
  return wallet.escrow_cents / 100;
};

export const getTotalBalance = (wallet: Wallet): number => {
  return getAvailableBalance(wallet) + getEscrowBalance(wallet);
};

export const formatAvailableBalance = (wallet: Wallet): string => {
  return `$${getAvailableBalance(wallet).toFixed(2)}`;
};

export const formatEscrowBalance = (wallet: Wallet): string => {
  return `$${getEscrowBalance(wallet).toFixed(2)}`;
};

export const formatTotalBalance = (wallet: Wallet): string => {
  return `$${getTotalBalance(wallet).toFixed(2)}`;
};

export const hasAvailableBalance = (wallet: Wallet): boolean => {
  return wallet.available_cents > 0;
};

export const hasEscrowBalance = (wallet: Wallet): boolean => {
  return wallet.escrow_cents > 0;
};

// Payout interface
export interface Payout {
  id: string;
  user_id: string;
  amount_cents: number;
  fee_cents: number;
  net_amount_cents: number;
  payout_type: string;
  payout_method: string;
  status: PayoutStatus;
  stripe_connect_account_id: string | null;
  stripe_transfer_id: string | null;
  error_message: string | null;
  retry_count: number | null;
  created_at: string;
  updated_at: string | null;
  paid_at: string | null;
}

// Payout helper functions
export const getPayoutAmount = (payout: Payout): number => {
  return payout.amount_cents / 100;
};

export const getPayoutFee = (payout: Payout): number => {
  return payout.fee_cents / 100;
};

export const getPayoutNetAmount = (payout: Payout): number => {
  return payout.net_amount_cents / 100;
};

export const formatPayoutAmount = (payout: Payout): string => {
  return `$${getPayoutAmount(payout).toFixed(2)}`;
};

export const formatPayoutFee = (payout: Payout): string => {
  return `$${getPayoutFee(payout).toFixed(2)}`;
};

export const formatPayoutNetAmount = (payout: Payout): string => {
  return `$${getPayoutNetAmount(payout).toFixed(2)}`;
};

export const isPayoutPending = (payout: Payout): boolean => {
  return payout.status === 'pending';
};

export const isPayoutCompleted = (payout: Payout): boolean => {
  return payout.status === 'completed' || payout.status === 'paid';
};

export const isPayoutFailed = (payout: Payout): boolean => {
  return payout.status === 'failed' || payout.status === 'cancelled';
};

export const canRetryPayout = (payout: Payout): boolean => {
  return isPayoutFailed(payout) && (payout.retry_count ?? 0) < 3;
};

// Payout Insert (for creating new payouts)
export interface PayoutInsert {
  user_id: string;
  seller_id: string;
  amount_cents: number;
  destination: string;
  fee_cents: number;
  net_amount_cents: number;
  payout_type: string;
  payout_method: string;
  status: string;
  stripe_connect_account_id: string | null;
  created_at: string;
  updated_at: string;
}

// Wallet Transaction interface
export interface WalletTransaction {
  id: string;
  user_id: string;
  type: TransactionType;
  amount_cents: number;
  balance_after_cents: number;
  description: string;
  related_id: string | null;
  created_at: string;
}

// Transaction helper functions
export const getTransactionAmount = (tx: WalletTransaction): number => {
  return tx.amount_cents / 100;
};

export const getTransactionBalanceAfter = (tx: WalletTransaction): number => {
  return tx.balance_after_cents / 100;
};

export const isTransactionCredit = (type: TransactionType): boolean => {
  return ['escrow_release', 'refund', 'adjustment'].includes(type);
};

export const formatTransactionAmount = (tx: WalletTransaction): string => {
  const prefix = isTransactionCredit(tx.type) ? '+' : '-';
  return `${prefix}$${Math.abs(getTransactionAmount(tx)).toFixed(2)}`;
};

export const formatTransactionBalance = (tx: WalletTransaction): string => {
  return `$${getTransactionBalanceAfter(tx).toFixed(2)}`;
};

// Transaction Insert (for creating new transactions)
export interface TransactionInsert {
  user_id: string;
  type: string;
  amount_cents: number;
  balance_after_cents: number;
  description: string;
  related_id: string | null;
  created_at: string;
}

// Payout Request
export interface PayoutRequest {
  amount_cents: number;
  destination: PayoutDestination;
}

export const getPayoutRequestAmount = (request: PayoutRequest): number => {
  return request.amount_cents / 100;
};

export const requiresOnboarding = (destination: PayoutDestination): boolean => {
  return destination === 'stripe_connect';
};

