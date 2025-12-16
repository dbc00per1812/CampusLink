-- Create user_interests table to store user category preferences for personalized recommendations
-- This table stores which categories (products/services) users are interested in
-- Used by the "For You" feed to prioritize relevant listings

CREATE TABLE IF NOT EXISTS public.user_interests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  category text NOT NULL,
  listing_type text NOT NULL CHECK (listing_type = ANY (ARRAY['product'::text, 'service'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  
  CONSTRAINT user_interests_pkey PRIMARY KEY (id),
  CONSTRAINT user_interests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  
  -- Ensure a user can't have duplicate category+type combinations
  CONSTRAINT user_interests_unique_category UNIQUE (user_id, category, listing_type)
);

-- Create index for faster lookups by user_id
CREATE INDEX IF NOT EXISTS idx_user_interests_user_id ON public.user_interests(user_id);

-- Enable Row Level Security
ALTER TABLE public.user_interests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own interests
CREATE POLICY "Users can view own interests"
  ON public.user_interests
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own interests
CREATE POLICY "Users can insert own interests"
  ON public.user_interests
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own interests
CREATE POLICY "Users can delete own interests"
  ON public.user_interests
  FOR DELETE
  USING (auth.uid() = user_id);

-- Users can update their own interests
CREATE POLICY "Users can update own interests"
  ON public.user_interests
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

