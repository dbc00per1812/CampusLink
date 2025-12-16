// Messaging Types - Converted from MessagingModels.swift

import { Listing, ListingWithUser, User } from './product';

// Conversation interface
export interface Conversation {
  id: string;
  listing_id: string | null;
  buyer_id: string;
  seller_id: string;
  last_message_at: string | null;
  created_at: string;
  updated_at: string | null;
  archived_by_buyer: boolean;
  archived_by_seller: boolean;
  // Joined data
  listing?: Listing | null;
  buyer?: User | null;
  seller?: User | null;
  last_message?: Message | null;
}

// Message interface
export interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  message_type: string | null;
  created_at: string;
  read_at: string | null;
  // Joined data
  sender?: User | null;
}

// Helper functions for Conversation
export const getOtherParticipant = (
  conversation: Conversation,
  currentUserId: string
): User | null => {
  const me = currentUserId.toLowerCase();
  if (conversation.buyer_id.toLowerCase() === me) return conversation.seller ?? null;
  if (conversation.seller_id.toLowerCase() === me) return conversation.buyer ?? null;
  return null;
};

export const isParticipant = (
  conversation: Conversation,
  userId: string
): boolean => {
  const me = userId.toLowerCase();
  return (
    conversation.buyer_id.toLowerCase() === me ||
    conversation.seller_id.toLowerCase() === me
  );
};

export const getConversationDisplayName = (
  conversation: Conversation,
  currentUserId: string
): string => {
  const other = getOtherParticipant(conversation, currentUserId);
  if (other) {
    return formatName(other.name ?? other.email ?? 'Unknown User');
  }
  return 'Conversation';
};

export const getConversationPreviewText = (conversation: Conversation): string => {
  if (conversation.last_message) {
    return conversation.last_message.content;
  }
  if (conversation.listing) {
    return `About: ${conversation.listing.title}`;
  }
  return 'No messages yet';
};

// Helper functions for Message
export const isSentByCurrentUser = (message: Message, userId: string): boolean => {
  return message.sender_id.toLowerCase() === userId.toLowerCase();
};

// Helper to format name (capitalize first letter of each word)
const formatName = (name: string): string => {
  return name
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
};

// Convert Listing to ListingWithUser using seller information
export const conversationToListingWithUser = (
  conversation: Conversation,
  currentUserId: string
): ListingWithUser | null => {
  if (!conversation.listing || !conversation.seller) return null;

  return {
    ...conversation.listing,
    user: conversation.seller,
  };
};

// Message types enum (for message_type field)
export type MessageType = 'text' | 'offer' | 'system' | 'image';

export const MessageTypeDisplay: Record<MessageType, string> = {
  text: 'Text',
  offer: 'Offer',
  system: 'System',
  image: 'Image',
};

// Message Create interface
export interface MessageCreate {
  conversation_id: string;
  content: string;
  message_type?: string;
}

