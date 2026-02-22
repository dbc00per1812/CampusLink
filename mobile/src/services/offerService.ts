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
      // Use the directional fields (offer_from/offer_to) as primary
      offer_from_user_id: userId,
      offer_to_user_id: sellerId,
      // Also populate legacy seller_id for backwards compatibility
      seller_id: sellerId,
      listing_type: 'regular',
      price_cents: offerAmountCents,
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
  // Use explicit FK name because offers has 3 FKs to listings
  const { data, error } = await supabase
    .from('offers')
    .select('*, listing:listings!offers_listing_id_fkey(*), offer_from:users!offer_from_user_id(*), offer_to:users!offer_to_user_id(*)')
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
    .select('*, offer_from:users!offer_from_user_id(*)')
    .eq('listing_id', listingId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
};

// Accept an offer (offer recipient only)
export const acceptOffer = async (offerId: string): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .update({ status: 'accepted' })
    .eq('id', offerId)
    .eq('offer_to_user_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Decline an offer (offer recipient only)
export const declineOffer = async (offerId: string): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('offers')
    .update({ status: 'declined' })
    .eq('id', offerId)
    .eq('offer_to_user_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Counter an offer - creates a new offer with swapped roles
export const counterOffer = async (
  offerId: string,
  counterAmountCents: number,
  message?: string
): Promise<Offer> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // First, get the original offer to swap roles
  const { data: originalOffer, error: fetchError } = await supabase
    .from('offers')
    .select('*')
    .eq('id', offerId)
    .single();

  if (fetchError) throw fetchError;
  if (!originalOffer) throw new Error('Offer not found');

  // Verify the current user can counter (must be the offer recipient)
  if (originalOffer.offer_to_user_id !== userId) {
    throw new Error('Only the offer recipient can counter');
  }

  // Mark original offer as countered
  const { error: updateError } = await supabase
    .from('offers')
    .update({ status: 'countered' })
    .eq('id', offerId);

  if (updateError) throw updateError;

  // Create new counter-offer with swapped roles
  const { data, error } = await supabase
    .from('offers')
    .insert({
      listing_id: originalOffer.listing_id,
      offer_from_user_id: userId, // Current user is now the offerer
      offer_to_user_id: originalOffer.offer_from_user_id, // Original offerer receives counter
      seller_id: originalOffer.seller_id,
      listing_type: originalOffer.listing_type,
      price_cents: counterAmountCents,
      message,
      status: 'pending',
      parent_offer_id: offerId, // Link to original offer
    })
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Withdraw an offer (offer sender only)
export const withdrawOffer = async (offerId: string): Promise<void> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { error } = await supabase
    .from('offers')
    .update({ status: 'withdrawn' })
    .eq('id', offerId)
    .eq('offer_from_user_id', userId);

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
    .eq('offer_from_user_id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Get user's sent offers (offers made by this user)
export const getBuyerOffers = async (): Promise<Offer[]> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Use explicit FK name because offers has 3 FKs to listings
  const { data, error } = await supabase
    .from('offers')
    .select('*, listing:listings!offers_listing_id_fkey(*), offer_to:users!offer_to_user_id(*)')
    .eq('offer_from_user_id', userId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
};

// Get user's received offers (offers made to this user)
export const getSellerOffers = async (): Promise<Offer[]> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Use explicit FK name because offers has 3 FKs to listings
  const { data, error } = await supabase
    .from('offers')
    .select('*, listing:listings!offers_listing_id_fkey(*), offer_from:users!offer_from_user_id(*)')
    .eq('offer_to_user_id', userId)
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

