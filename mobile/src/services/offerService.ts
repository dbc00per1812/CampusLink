// Offer Service - Handle offer operations
import { supabase } from '../config/supabase';
import { Offer } from '../types';

// Get current user ID
const getCurrentUserId = async (): Promise<string | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.user.id ?? null;
};

// Create a new offer
export const createOffer = async (
  listingId: string,
  sellerId: string,
  offerAmount: number,
  message?: string
): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .insert({
      listing_id: listingId,
      buyer_id: userId,
      seller_id: sellerId,
      offer_amount: offerAmount,
      message,
      status: 'pending',
    })
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Get offer by ID
export const getOffer = async (offerId: string): Promise<Offer | null> => {
  const { data, error } = await supabase
    .from('offers')
    .select('*, listing:listings(*), buyer:users!buyer_id(*), seller:users!seller_id(*)')
    .eq('id', offerId)
    .single();

  if (error) {
    if (error.code === 'PGRST116') return null;
    throw error;
  }
  return data;
};

// Get offers for a listing
export const getOffersForListing = async (listingId: string): Promise<Offer[]> => {
  const { data, error } = await supabase
    .from('offers')
    .select('*, buyer:users!buyer_id(*)')
    .eq('listing_id', listingId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
};

// Accept an offer
export const acceptOffer = async (offerId: string): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .update({ status: 'accepted' })
    .eq('id', offerId)
    .eq('seller_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Decline an offer
export const declineOffer = async (offerId: string): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .update({ status: 'declined' })
    .eq('id', offerId)
    .eq('seller_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Counter an offer
export const counterOffer = async (
  offerId: string,
  counterAmount: number,
  message?: string
): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .update({
      status: 'countered',
      counter_amount: counterAmount,
      counter_message: message,
    })
    .eq('id', offerId)
    .eq('seller_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Withdraw an offer (buyer only)
export const withdrawOffer = async (offerId: string): Promise<void> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { error } = await supabase
    .from('offers')
    .update({ status: 'withdrawn' })
    .eq('id', offerId)
    .eq('buyer_id', userId);

  if (error) throw error;
};

export default {
  createOffer,
  getOffer,
  getOffersForListing,
  acceptOffer,
  declineOffer,
  counterOffer,
  withdrawOffer,
};

