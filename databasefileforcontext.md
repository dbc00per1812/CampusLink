-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  listing_id uuid,
  buyer_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  last_message_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  order_id uuid,
  CONSTRAINT conversations_pkey PRIMARY KEY (id),
  CONSTRAINT conversations_buyer_fkey FOREIGN KEY (buyer_id) REFERENCES public.users(id),
  CONSTRAINT conversations_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES public.listings(id),
  CONSTRAINT conversations_seller_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id)
);
CREATE TABLE public.disputes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL,
  opened_by uuid NOT NULL,
  reason text NOT NULL,
  status text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT disputes_pkey PRIMARY KEY (id),
  CONSTRAINT disputes_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT disputes_opened_by_fkey FOREIGN KEY (opened_by) REFERENCES public.users(id)
);
CREATE TABLE public.listings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  price numeric NOT NULL CHECK (price > 0::numeric),
  category text,
  photo text,
  is_sold boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  listing_type character varying NOT NULL DEFAULT 'product'::character varying CHECK (listing_type::text = ANY (ARRAY['product'::character varying, 'service'::character varying]::text[])),
  service_duration text,
  service_location character varying CHECK (service_location IS NULL OR (service_location::text = ANY (ARRAY['on_campus'::character varying, 'off_campus'::character varying, 'remote'::character varying]::text[]))),
  service_availability text,
  status text DEFAULT 'active'::text,
  reserved_by uuid,
  reserved_until timestamp with time zone,
  CONSTRAINT listings_pkey PRIMARY KEY (id),
  CONSTRAINT listings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  message_type character varying DEFAULT 'text'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  order_id uuid,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT messages_sender_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id)
);
CREATE TABLE public.orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL,
  buyer_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  price_cents integer NOT NULL,
  payment_method text NOT NULL,
  payment_status text NOT NULL,
  order_status text NOT NULL,
  auto_release_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES public.listings(id),
  CONSTRAINT orders_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id),
  CONSTRAINT orders_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.users(id)
);
CREATE TABLE public.payments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  listing_id uuid,
  buyer_id uuid NOT NULL,
  payment_intent_id text UNIQUE,
  amount numeric NOT NULL,
  status text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  seller_id uuid NOT NULL,
  escrow_release_at timestamp with time zone,
  delivered_at timestamp with time zone,
  buyer_confirmed_at timestamp with time zone,
  seller_proof_urls ARRAY DEFAULT '{}'::text[],
  dispute_status text DEFAULT 'none'::text CHECK (dispute_status = ANY (ARRAY['none'::text, 'open'::text, 'under_review'::text, 'resolved'::text, 'refunded'::text])),
  dispute_reason text,
  dispute_notes text,
  order_id uuid,
  payment_method text,
  auto_release_at timestamp with time zone,
  CONSTRAINT payments_pkey PRIMARY KEY (id),
  CONSTRAINT payments_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES public.listings(id),
  CONSTRAINT payments_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.users(id),
  CONSTRAINT payments_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id)
);
CREATE TABLE public.payouts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  seller_id uuid NOT NULL,
  amount_cents integer NOT NULL,
  destination text NOT NULL,
  status text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT payouts_pkey PRIMARY KEY (id),
  CONSTRAINT payouts_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id)
);
CREATE TABLE public.reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL,
  reported_user_id uuid,
  reported_listing_id uuid,
  report_type text NOT NULL CHECK (report_type = ANY (ARRAY['inappropriate_content'::text, 'scam'::text, 'harassment'::text, 'spam'::text, 'fake_profile'::text, 'other'::text])),
  description text NOT NULL,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'reviewing'::text, 'resolved'::text, 'dismissed'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT reports_pkey PRIMARY KEY (id),
  CONSTRAINT reports_reported_listing_id_fkey FOREIGN KEY (reported_listing_id) REFERENCES public.listings(id),
  CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id),
  CONSTRAINT reports_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.service_bookings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid,
  scheduled_at timestamp with time zone NOT NULL,
  duration_minutes integer NOT NULL,
  location text NOT NULL,
  special_requests text,
  status text NOT NULL DEFAULT 'scheduled'::text,
  created_at timestamp with time zone DEFAULT now(),
  order_id uuid,
  CONSTRAINT service_bookings_pkey PRIMARY KEY (id),
  CONSTRAINT service_bookings_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.payments(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL,
  name text,
  bio text,
  profile_pic text,
  email text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  campus_email_verified boolean DEFAULT false,
  trust_score integer,
  stripe_connect_id text,
  stripe_payouts_enabled boolean DEFAULT false,
  stripe_details_submitted boolean DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.wallets (
  user_id uuid NOT NULL,
  available_cents integer NOT NULL DEFAULT 0,
  escrow_cents integer NOT NULL DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT wallets_pkey PRIMARY KEY (user_id),
  CONSTRAINT wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);