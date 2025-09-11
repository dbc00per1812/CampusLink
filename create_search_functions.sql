-- Create search indexes and functions for CampusLink
-- Run this in your Supabase SQL editor

-- Step 1: Create GIN index on tsv column for full-text search
CREATE INDEX IF NOT EXISTS idx_listings_tsv_gin ON public.listings USING GIN(tsv);

-- Step 2: Create additional performance indexes
CREATE INDEX IF NOT EXISTS idx_listings_search_active ON public.listings(status, archived) 
WHERE status = 'active' AND archived = false;

CREATE INDEX IF NOT EXISTS idx_listings_price_range ON public.listings(price) 
WHERE price IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_listings_category_search ON public.listings(category, status)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_listings_location_search ON public.listings(service_location, status)
WHERE status = 'active' AND service_location IS NOT NULL;

-- Step 3: Create the search_listings function
CREATE OR REPLACE FUNCTION search_listings(
  search_term text DEFAULT '',
  category_filter text DEFAULT NULL,
  intent_filter text DEFAULT NULL,
  min_price numeric DEFAULT NULL,
  max_price numeric DEFAULT NULL,
  location_filter text DEFAULT NULL,
  listing_type_filter text DEFAULT NULL,
  trust_score_min integer DEFAULT NULL,
  sort_by text DEFAULT 'relevance',
  limit_count integer DEFAULT 20,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  listing_data json,
  search_rank real
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    row_to_json(listings_with_user.*) as listing_data,
    CASE 
      WHEN search_term = '' THEN 0
      ELSE ts_rank(l.tsv, plainto_tsquery('simple', search_term))
    END as search_rank
  FROM (
    SELECT 
      l.id,
      l.user_id,
      l.title,
      l.description,
      l.price,
      l.category,
      l.photo,
      l.is_sold,
      l.created_at,
      l.listing_type,
      l.service_duration,
      l.service_location,
      l.service_availability,
      l.status,
      l.reserved_by,
      l.reserved_until,
      l.service_type,
      l.slots_available,
      l.max_bookings_per_slot,
      l.archived,
      l.intent,
      l.budget_min,
      l.budget_max,
      l.expires_at,
      u.name as user_name,
      u.email as user_email,
      u.trust_score as user_trust_score,
      u.profile_pic as user_profile_pic
    FROM public.listings l
    JOIN public.users u ON l.user_id = u.id
    WHERE l.status = 'active' 
      AND l.archived = false
      AND (search_term = '' OR l.tsv @@ plainto_tsquery('simple', search_term))
      AND (category_filter IS NULL OR l.category = category_filter)
      AND (intent_filter IS NULL OR l.intent = intent_filter)
      AND (min_price IS NULL OR l.price >= min_price)
      AND (max_price IS NULL OR l.price <= max_price)
      AND (location_filter IS NULL OR l.service_location = location_filter)
      AND (listing_type_filter IS NULL OR l.listing_type = listing_type_filter)
      AND (trust_score_min IS NULL OR u.trust_score >= trust_score_min)
  ) as listings_with_user
  ORDER BY 
    CASE sort_by
      WHEN 'relevance' THEN search_rank
      WHEN 'price_low' THEN -COALESCE(listings_with_user.price, 0)
      WHEN 'price_high' THEN COALESCE(listings_with_user.price, 0)
      WHEN 'newest' THEN EXTRACT(EPOCH FROM listings_with_user.created_at)
      WHEN 'trust_score' THEN COALESCE(listings_with_user.user_trust_score, 0)
      ELSE search_rank
    END DESC
  LIMIT limit_count
  OFFSET offset_count;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create search suggestions function
CREATE OR REPLACE FUNCTION get_search_suggestions(
  partial_term text, 
  max_suggestions integer DEFAULT 10
)
RETURNS TABLE(suggestion text, category text, count bigint) AS $$
BEGIN
  RETURN QUERY
  WITH word_suggestions AS (
    SELECT DISTINCT
      unnest(string_to_array(title, ' ')) as word,
      category,
      1 as count
    FROM public.listings
    WHERE status = 'active' 
      AND archived = false
      AND lower(unnest(string_to_array(title, ' '))) LIKE lower(partial_term) || '%'
      AND char_length(unnest(string_to_array(title, ' '))) > 2
  ),
  title_suggestions AS (
    SELECT DISTINCT
      title as word,
      category,
      1 as count
    FROM public.listings
    WHERE status = 'active'
      AND archived = false  
      AND lower(title) LIKE '%' || lower(partial_term) || '%'
  )
  SELECT w.word, w.category, SUM(w.count)::bigint
  FROM (
    SELECT * FROM word_suggestions
    UNION ALL
    SELECT * FROM title_suggestions
  ) w
  GROUP BY w.word, w.category
  ORDER BY SUM(w.count) DESC, char_length(w.word) ASC
  LIMIT max_suggestions;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION get_search_suggestions TO authenticated;

-- Step 6: Test the search function
-- SELECT * FROM search_listings('laptop', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);
