-- ============================================================================
-- CREATE request_payout RPC FUNCTION
-- ============================================================================
-- This function creates a payout record in the payouts table.
-- It uses auth.uid() for security - the user ID is NOT passed from the client.
-- 
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.request_payout(
  p_amount_cents integer,
  p_destination text DEFAULT 'stripe_connect'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_fee_cents integer := 0;
  v_net_amount_cents integer;
  v_payout_type text := 'standard';
  v_payout_method text := 'bank_account';
  v_connect_id text;
  v_result json;
BEGIN
  -- Get authenticated user (secure - not from client)
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate amount
  IF p_amount_cents <= 0 THEN
    RAISE EXCEPTION 'Payout amount must be positive';
  END IF;

  -- Calculate net amount (amount minus platform fee)
  v_net_amount_cents := p_amount_cents - v_fee_cents;

  -- Get user's Stripe Connect ID
  SELECT stripe_connect_id INTO v_connect_id
  FROM users WHERE id = v_user_id;

  IF v_connect_id IS NULL THEN
    RAISE EXCEPTION 'Stripe Connect account not set up';
  END IF;

  -- Determine payout method from destination
  IF p_destination = 'bank_account' THEN
    v_payout_method := 'bank_account';
  ELSE
    v_payout_method := 'bank_account';
  END IF;

  -- Insert payout record with status 'pending'
  INSERT INTO payouts (
    user_id, amount_cents, fee_cents, net_amount_cents,
    payout_type, payout_method, status,
    stripe_connect_account_id, created_at, updated_at
  ) VALUES (
    v_user_id, p_amount_cents, v_fee_cents, v_net_amount_cents,
    v_payout_type, v_payout_method, 'pending',
    v_connect_id, now(), now()
  )
  RETURNING row_to_json(payouts.*) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- VERIFICATION: Check the function was created
-- ============================================================================
SELECT 
  routine_name, 
  routine_type,
  '✅ CREATED' AS status
FROM information_schema.routines 
WHERE routine_name = 'request_payout' 
  AND routine_schema = 'public';
