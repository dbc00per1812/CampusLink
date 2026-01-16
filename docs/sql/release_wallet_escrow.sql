-- Phase 2: Wallet Escrow Protection
-- Creates atomic RPC function for releasing wallet escrow funds to seller
-- Run this SQL in Supabase Dashboard > SQL Editor

-- Function to atomically release funds from buyer's escrow to seller's wallet
CREATE OR REPLACE FUNCTION release_wallet_escrow(
  p_order_id UUID,
  p_buyer_id UUID,
  p_seller_id UUID,
  p_amount_cents INTEGER
) RETURNS void AS $$
BEGIN
  -- Deduct from buyer's escrow
  UPDATE wallets 
  SET escrow_cents = escrow_cents - p_amount_cents,
      updated_at = NOW()
  WHERE user_id = p_buyer_id
    AND escrow_cents >= p_amount_cents;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient escrow balance';
  END IF;

  -- Add to seller's available
  INSERT INTO wallets (user_id, available_cents, escrow_cents, updated_at)
  VALUES (p_seller_id, p_amount_cents, 0, NOW())
  ON CONFLICT (user_id) DO UPDATE
  SET available_cents = wallets.available_cents + p_amount_cents,
      updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION release_wallet_escrow(UUID, UUID, UUID, INTEGER) TO authenticated;

-- Function to atomically refund escrow back to buyer's available balance
CREATE OR REPLACE FUNCTION refund_wallet_escrow(
  p_buyer_id UUID,
  p_amount_cents INTEGER
) RETURNS void AS $$
BEGIN
  -- Move from buyer's escrow back to available
  UPDATE wallets 
  SET escrow_cents = escrow_cents - p_amount_cents,
      available_cents = available_cents + p_amount_cents,
      updated_at = NOW()
  WHERE user_id = p_buyer_id
    AND escrow_cents >= p_amount_cents;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient escrow balance for refund';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION refund_wallet_escrow(UUID, INTEGER) TO authenticated;

