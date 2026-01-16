-- Pending Seller Payouts Table
-- Tracks funds held in platform account for sellers who haven't completed Stripe onboarding
-- Run this in Supabase SQL Editor

-- Create the table
CREATE TABLE IF NOT EXISTS public.pending_seller_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id uuid NOT NULL REFERENCES public.users(id),
  order_id uuid NOT NULL REFERENCES public.orders(id),
  amount_cents integer NOT NULL,
  payment_intent_id text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'transferred', 'failed')),
  transfer_id text, -- Stripe transfer ID once transferred
  error_message text,
  transferred_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index for looking up pending payouts by seller
CREATE INDEX IF NOT EXISTS idx_pending_seller_payouts_seller_id 
ON public.pending_seller_payouts(seller_id) 
WHERE status = 'pending';

-- Index for looking up by order
CREATE INDEX IF NOT EXISTS idx_pending_seller_payouts_order_id 
ON public.pending_seller_payouts(order_id);

-- RLS policies
ALTER TABLE public.pending_seller_payouts ENABLE ROW LEVEL SECURITY;

-- Sellers can view their own pending payouts
CREATE POLICY "Sellers can view own pending payouts"
ON public.pending_seller_payouts
FOR SELECT
USING (auth.uid() = seller_id);

-- Only service role can insert/update (edge functions)
CREATE POLICY "Service role can manage pending payouts"
ON public.pending_seller_payouts
FOR ALL
USING (auth.role() = 'service_role');

-- Function to get total pending amount for a seller
CREATE OR REPLACE FUNCTION get_pending_payout_total(p_seller_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(SUM(amount_cents), 0)::integer
  FROM public.pending_seller_payouts
  WHERE seller_id = p_seller_id AND status = 'pending';
$$;

