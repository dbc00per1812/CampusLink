-- Create forum_messages table for community channels
-- This table stores messages from open community forums (General, Support)

-- Create the forum_messages table
CREATE TABLE IF NOT EXISTS public.forum_messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  channel text NOT NULL CHECK (channel IN ('general', 'support')),
  sender_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT forum_messages_pkey PRIMARY KEY (id),
  CONSTRAINT forum_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- Add index for efficient channel-based queries
CREATE INDEX IF NOT EXISTS idx_forum_messages_channel 
ON public.forum_messages(channel, created_at DESC);

-- Add index for sender lookups
CREATE INDEX IF NOT EXISTS idx_forum_messages_sender 
ON public.forum_messages(sender_id);

-- Enable Row Level Security
ALTER TABLE public.forum_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read forum messages
CREATE POLICY "Anyone can read forum messages"
ON public.forum_messages
FOR SELECT
USING (true);

-- Policy: Authenticated users can create forum messages
CREATE POLICY "Authenticated users can create forum messages"
ON public.forum_messages
FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Policy: Users can update their own messages (for future edit feature)
CREATE POLICY "Users can update their own messages"
ON public.forum_messages
FOR UPDATE
USING (auth.uid() = sender_id)
WITH CHECK (auth.uid() = sender_id);

-- Policy: Users can delete their own messages (for future delete feature)
CREATE POLICY "Users can delete their own messages"
ON public.forum_messages
FOR DELETE
USING (auth.uid() = sender_id);

-- Add comments for documentation
COMMENT ON TABLE public.forum_messages IS 'Community forum messages for open channels';
COMMENT ON COLUMN public.forum_messages.channel IS 'Forum channel name (general, support)';
COMMENT ON COLUMN public.forum_messages.sender_id IS 'User who sent the message';
COMMENT ON COLUMN public.forum_messages.content IS 'Message content';
COMMENT ON COLUMN public.forum_messages.created_at IS 'When the message was created';
COMMENT ON COLUMN public.forum_messages.updated_at IS 'When the message was last updated';

