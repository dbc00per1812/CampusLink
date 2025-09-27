-- Minimal fix for offers system - only what's absolutely needed
-- Run this in Supabase SQL Editor

BEGIN;

-- Add price_cents column if it doesn't exist
ALTER TABLE public.offers 
ADD COLUMN IF NOT EXISTS price_cents integer;

-- Add order_id column to link offers with orders
ALTER TABLE public.offers 
ADD COLUMN IF NOT EXISTS order_id uuid;

-- Make offer_listing_id nullable  
ALTER TABLE public.offers 
ALTER COLUMN offer_listing_id DROP NOT NULL;

-- Update status constraint to include new paid status
ALTER TABLE public.offers 
DROP CONSTRAINT IF EXISTS offers_status_check,
ADD CONSTRAINT offers_status_check CHECK (
    status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'withdrawn'::text, 'expired'::text, 'paid_pending_acceptance'::text])
);

-- Simple accept function that just updates offer status
CREATE OR REPLACE FUNCTION accept_offer(
    p_offer_id uuid,
    p_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offer_row record;
BEGIN
    -- Get the offer (accept both pending and paid_pending_acceptance)
    SELECT * INTO v_offer_row FROM public.offers 
    WHERE id = p_offer_id 
    AND status IN ('pending', 'paid_pending_acceptance');
    
    IF v_offer_row IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Offer not found or already processed');
    END IF;
    
    -- Verify user is the seeker
    IF v_offer_row.seeker_id::uuid != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the seeker can accept offers');
    END IF;
    
    -- Update offer status to accepted
    UPDATE public.offers 
    SET status = 'accepted'
    WHERE id = p_offer_id;
    
    -- Decline other offers for this seek listing
    UPDATE public.offers 
    SET status = 'declined'
    WHERE seek_listing_id = v_offer_row.seek_listing_id 
    AND id != p_offer_id 
    AND status IN ('pending', 'paid_pending_acceptance');
    
    -- Archive the seek listing (no updated_at column)
    UPDATE public.listings 
    SET archived = true
    WHERE id = v_offer_row.seek_listing_id;
    
    RETURN jsonb_build_object('success', true);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Simple decline function
CREATE OR REPLACE FUNCTION decline_offer(
    p_offer_id uuid,
    p_user_id uuid,
    p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update offer status to declined
    UPDATE public.offers 
    SET status = 'declined'
    WHERE id = p_offer_id 
    AND (seeker_id::uuid = p_user_id OR seller_id::uuid = p_user_id);
    
    RETURN jsonb_build_object('success', true);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION accept_offer TO authenticated;
GRANT EXECUTE ON FUNCTION decline_offer TO authenticated;

COMMIT;

SELECT 'Offers system ready! Accept/decline should now work.' as status;
