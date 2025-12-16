// Product and Listing Types - Converted from ProductModels.swift

export type ListingType = 'product' | 'service';
export type ListingIntent = 'offer' | 'seek';
export type ServiceLocation = 'on_campus' | 'off_campus' | 'remote';
export type DeliveryMethod = 'pickup' | 'delivery' | 'both';
export type OfferListingType = 'seek' | 'regular';
export type OfferUserRole = 'sender' | 'receiver' | 'none';

// Display name helpers
export const ListingTypeDisplay: Record<ListingType, string> = {
  product: 'Product',
  service: 'Service',
};

export const ListingIntentDisplay: Record<ListingIntent, string> = {
  offer: 'Sell',
  seek: 'Buy',
};

export const ServiceLocationDisplay: Record<ServiceLocation, string> = {
  on_campus: 'On Campus',
  off_campus: 'Off Campus',
  remote: 'Remote',
};

export const DeliveryMethodDisplay: Record<DeliveryMethod, string> = {
  pickup: 'Pickup',
  delivery: 'Delivery',
  both: 'Both',
};

export const DeliveryMethodDescription: Record<DeliveryMethod, string> = {
  pickup: 'Buyer will pick up',
  delivery: 'Seller will drop off',
  both: 'Pickup or delivery available',
};

// User interface
export interface User {
  id: string;
  name: string | null;
  bio: string | null;
  profile_pic: string | null;
  email: string | null;
  campus: string | null;
  created_at: string;
  campus_email_verified: boolean | null;
  trust_score: number | null;
  stripe_connect_id: string | null;
  stripe_payouts_enabled: boolean | null;
  stripe_details_submitted: boolean | null;
  verification_status: string | null;
  student_id_image_url: string | null;
  verification_submitted_at: string | null;
  verification_reviewed_at: string | null;
  verification_notes: string | null;
}

// Helper function for User
export const isVerifiedStudent = (user: User): boolean => {
  return user.verification_status === 'verified';
};

// Listing interface
export interface Listing {
  id: string;
  user_id: string;
  title: string;
  description: string;
  price: number | null;
  category: string;
  photo: string | null;
  photos: string[];
  is_sold: boolean;
  listing_type: ListingType;
  service_duration: string | null;
  service_location: ServiceLocation | null;
  service_availability: string | null;
  archived: boolean | null;
  created_at: string;
  intent: ListingIntent;
  budget_min: number | null;
  budget_max: number | null;
  expires_at: string | null;
  delivery_method: DeliveryMethod | null;
  quantity_available: number | null;
  quantity_sold: number | null;
  accepts_offers: boolean | null;
}

// Listing with User (for joined queries)
export interface ListingWithUser extends Listing {
  user: User;
}

// Listing Create (for inserting new listings)
export interface ListingCreate {
  title: string;
  description: string;
  price: number | null;
  category: string;
  photo: string | null;
  photos: string[];
  listing_type: ListingType;
  service_duration: string | null;
  service_location: ServiceLocation | null;
  service_availability: string | null;
  intent: ListingIntent;
  budget_min: number | null;
  budget_max: number | null;
  expires_at?: string | null;
  delivery_method: DeliveryMethod | null;
  quantity_available: number | null;
  accepts_offers: boolean | null;
}

// Computed properties helpers
export const hasMultipleUnits = (listing: Listing): boolean => {
  return (listing.quantity_available ?? 1) > 1;
};

export const isOutOfStock = (listing: Listing): boolean => {
  return (listing.quantity_available ?? 1) <= 0;
};

// Offer interface
export interface Offer {
  id: string;
  listing_id: string;
  listing_type: OfferListingType;
  offer_listing_id: string | null;
  offer_from_user_id: string;
  offer_to_user_id: string;
  parent_offer_id: string | null;
  buyer_id: string;
  seller_id: string;
  // Standard fields
  message: string | null;
  status: string;
  price_cents: number | null;
  offer_amount: number;
  order_id: string | null;
  created_at: string;
  updated_at: string;
  // Joined data
  listing?: Listing | null;
  buyer?: User | null;
  seller?: User | null;
}

// Offer helpers
export const getOfferPrice = (offer: Offer): number | null => {
  if (offer.price_cents === null) return null;
  return offer.price_cents / 100;
};

export const formatOfferPrice = (offer: Offer): string | null => {
  const price = getOfferPrice(offer);
  if (price === null) return null;
  return `$${price.toFixed(2)}`;
};

export const isCounterOffer = (offer: Offer): boolean => {
  return offer.parent_offer_id !== null;
};

export const isSeekOffer = (offer: Offer): boolean => {
  return offer.listing_type === 'seek';
};

export const isBuyerOffer = (offer: Offer): boolean => {
  return offer.listing_type === 'regular';
};

export const getOfferUserRole = (offer: Offer, currentUserId: string): OfferUserRole => {
  if (offer.offer_from_user_id.toLowerCase() === currentUserId.toLowerCase()) {
    return 'sender';
  } else if (offer.offer_to_user_id.toLowerCase() === currentUserId.toLowerCase()) {
    return 'receiver';
  }
  return 'none';
};

// Sample data for testing
export const sampleUser: User = {
  id: 'sample-user-id',
  name: 'Sample User',
  bio: 'This is a sample user for testing and preview purposes.',
  profile_pic: null,
  email: 'sample@example.com',
  campus: 'Indiana University Bloomington',
  created_at: new Date().toISOString(),
  campus_email_verified: true,
  trust_score: 85,
  stripe_connect_id: 'acct_sample123',
  stripe_payouts_enabled: true,
  stripe_details_submitted: true,
  verification_status: 'verified',
  student_id_image_url: null,
  verification_submitted_at: null,
  verification_reviewed_at: null,
  verification_notes: null,
};

export const sampleListing: Listing = {
  id: 'sample-listing-id',
  user_id: 'sample-user-id',
  title: 'Sample Product',
  description: 'This is a sample product description for testing and preview purposes.',
  price: 25.0,
  category: 'Electronics',
  photo: null,
  photos: [],
  is_sold: false,
  listing_type: 'product',
  service_duration: null,
  service_location: null,
  service_availability: null,
  archived: false,
  created_at: new Date().toISOString(),
  intent: 'offer',
  budget_min: null,
  budget_max: null,
  expires_at: null,
  delivery_method: 'pickup',
  quantity_available: 1,
  quantity_sold: 0,
  accepts_offers: false,
};

