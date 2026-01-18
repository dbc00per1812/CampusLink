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
  offerAmountCents: number,
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
      // Also populate the directional fields for database compatibility
      offer_from_user_id: userId,
      offer_to_user_id: sellerId,
      listing_type: 'regular',
      offer_amount: offerAmountCents,
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

// Update offer with order ID after payment (links offer to created order)
export const updateOfferWithOrder = async (
  offerId: string,
  orderId: string
): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .update({
      order_id: orderId,
      status: 'paid_pending_acceptance',
      updated_at: new Date().toISOString(),
    })
    .eq('id', offerId)
    .eq('buyer_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Get buyer's sent offers
export const getBuyerOffers = async (): Promise<Offer[]> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .select('*, listing:listings(*), seller:users!seller_id(*)')
    .eq('buyer_id', userId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
};

// Get seller's received offers
export const getSellerOffers = async (): Promise<Offer[]> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .select('*, listing:listings(*), buyer:users!buyer_id(*)')
    .eq('seller_id', userId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
};

export default {
  createOffer,
  getOffer,
  getOffersForListing,
  acceptOffer,
  declineOffer,
  counterOffer,
  withdrawOffer,
  updateOfferWithOrder,
  getBuyerOffers,
  getSellerOffers,
};

