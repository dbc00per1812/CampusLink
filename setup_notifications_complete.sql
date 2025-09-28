-- Complete Notifications Setup
-- This file ensures all notification tables and functions are properly set up

-- Ensure notifications table exists with all required columns
CREATE TABLE IF NOT EXISTS notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  is_read boolean DEFAULT false,
  is_delivered boolean DEFAULT false,
  scheduled_for timestamp with time zone,
  delivered_at timestamp with time zone,
  read_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  
  -- Related entity references
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  message_id uuid,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  related_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_order_id ON notifications(order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_listing_id ON notifications(listing_id) WHERE listing_id IS NOT NULL;

-- Ensure user_notification_preferences table exists
CREATE TABLE IF NOT EXISTS user_notification_preferences (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  
  -- Push notification settings
  push_enabled boolean DEFAULT true,
  push_token text,
  push_platform text CHECK (push_platform IN ('ios', 'android')),
  
  -- Notification type preferences
  order_notifications boolean DEFAULT true,
  message_notifications boolean DEFAULT true,
  payment_notifications boolean DEFAULT true,
  rating_notifications boolean DEFAULT true,
  marketplace_notifications boolean DEFAULT true,
  
  -- Timing preferences
  quiet_hours_start text DEFAULT '22:00',
  quiet_hours_end text DEFAULT '08:00',
  timezone text DEFAULT 'America/New_York',
  
  -- Frequency controls
  max_daily_notifications int DEFAULT 50,
  group_similar_notifications boolean DEFAULT true,
  
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create or update user preferences when user signs up
CREATE OR REPLACE FUNCTION create_user_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create preferences for new users
DROP TRIGGER IF EXISTS trigger_create_user_preferences ON auth.users;
CREATE TRIGGER trigger_create_user_preferences
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_notification_preferences();

-- Update the push token for a user
CREATE OR REPLACE FUNCTION update_push_token(
  p_user_id uuid,
  p_token text,
  p_platform text DEFAULT 'ios'
)
RETURNS void AS $$
BEGIN
  INSERT INTO user_notification_preferences (user_id, push_token, push_platform)
  VALUES (p_user_id, p_token, p_platform)
  ON CONFLICT (user_id) DO UPDATE
  SET 
    push_token = EXCLUDED.push_token,
    push_platform = EXCLUDED.push_platform,
    updated_at = now();
END;
$$ LANGUAGE plpgsql;

-- Mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE notifications
  SET 
    is_read = true,
    read_at = now()
  WHERE id = p_notification_id;
END;
$$ LANGUAGE plpgsql;

-- Mark all notifications as read for a user
CREATE OR REPLACE FUNCTION mark_all_notifications_read(p_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE notifications
  SET 
    is_read = true,
    read_at = now()
  WHERE user_id = p_user_id AND is_read = false;
END;
$$ LANGUAGE plpgsql;

-- Get unread notification count for a user
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id uuid)
RETURNS int AS $$
DECLARE
  count int;
BEGIN
  SELECT COUNT(*) INTO count
  FROM notifications
  WHERE user_id = p_user_id AND is_read = false;
  RETURN count;
END;
$$ LANGUAGE plpgsql;

-- RLS Policies for notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- System can insert notifications (through triggers)
CREATE POLICY "System can insert notifications" ON notifications
  FOR INSERT WITH CHECK (true);

-- RLS Policies for user_notification_preferences
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can view and update their own preferences
CREATE POLICY "Users can view own preferences" ON user_notification_preferences
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences" ON user_notification_preferences
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences" ON user_notification_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create existing user preferences for users who don't have them
INSERT INTO user_notification_preferences (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM user_notification_preferences)
ON CONFLICT (user_id) DO NOTHING;
