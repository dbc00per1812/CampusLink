// Community Forum Types

import { User } from './product';

// Forum channel types
export type ForumChannel = 'general' | 'support';

export const ForumChannelNames: Record<ForumChannel, string> = {
  general: 'General',
  support: 'Support',
};

// Forum message interface
export interface ForumMessage {
  id: string;
  channel: ForumChannel;
  sender_id: string;
  content: string;
  created_at: string;
  updated_at: string | null;
  // Joined data
  sender?: User | null;
}

// Forum message create interface
export interface ForumMessageCreate {
  channel: ForumChannel;
  content: string;
}

