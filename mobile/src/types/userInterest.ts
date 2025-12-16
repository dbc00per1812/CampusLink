// User Interest Types

import { ListingType } from './product';

export interface UserInterest {
  id: string;
  user_id: string;
  category: string;
  listing_type: ListingType;
  created_at: string;
}

export interface UserInterestCreate {
  user_id: string;
  category: string;
  listing_type: ListingType;
}

