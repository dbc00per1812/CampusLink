// Messaging Service - Handle conversations and messages
import { supabase } from '../config/supabase';
import { Conversation, Message, MessageCreate } from '../types';
import { getBlockedUserIds, hasBlockingRelationship } from './userService';

// Get current user ID
const getCurrentUserId = async (): Promise<string | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.user.id ?? null;
};

// Get all conversations for current user
export const getConversations = async (): Promise<Conversation[]> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Get blocked user IDs to filter conversations
  const blockedIds = await getBlockedUserIds(userId);

  const { data, error } = await supabase
    .from('conversations')
    .select(`
      *,
      listing:listings(*),
      buyer:users!buyer_id(*),
      seller:users!seller_id(*),
      last_message:messages(*)
    `)
    .or(`buyer_id.eq.${userId},seller_id.eq.${userId}`)
    .order('last_message_at', { ascending: false, nullsFirst: false });

  if (error) throw error;
  
  // Process and filter out archived conversations and blocked users
  return (data ?? [])
    .map(conv => ({
      ...conv,
      last_message: conv.last_message?.[0] || null,
    }))
    .filter(conv => {
      // Filter out conversations archived by current user
      // Check for true explicitly (not just truthy) to handle null/undefined
      if (conv.buyer_id === userId && conv.archived_by_buyer === true) {
        console.log('📌 Filtering out archived conversation (buyer):', conv.id);
        return false;
      }
      if (conv.seller_id === userId && conv.archived_by_seller === true) {
        console.log('📌 Filtering out archived conversation (seller):', conv.id);
        return false;
      }
      
      // Filter out conversations with blocked users
      const otherUserId = conv.buyer_id === userId ? conv.seller_id : conv.buyer_id;
      if (blockedIds.includes(otherUserId)) {
        console.log('🚫 Filtering out conversation with blocked user:', otherUserId);
        return false;
      }
      
      return true;
    });
};

// Get a single conversation by ID
export const getConversation = async (conversationId: string): Promise<Conversation | null> => {
  const { data, error } = await supabase
    .from('conversations')
    .select(`
      *,
      listing:listings(*),
      buyer:users!buyer_id(*),
      seller:users!seller_id(*)
    `)
    .eq('id', conversationId)
    .single();

  if (error) {
    if (error.code === 'PGRST116') return null;
    throw error;
  }
  return data;
};

// Get or create a conversation for a listing
export const getOrCreateConversation = async (
  listingId: string,
  sellerId: string
): Promise<Conversation> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Check if conversation already exists
  const { data: existing } = await supabase
    .from('conversations')
    .select('*')
    .eq('listing_id', listingId)
    .eq('buyer_id', userId)
    .eq('seller_id', sellerId)
    .single();

  if (existing) return existing;

  // Create new conversation
  const { data, error } = await supabase
    .from('conversations')
    .insert({
      listing_id: listingId,
      buyer_id: userId,
      seller_id: sellerId,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Get or create a conversation for an order
// Matches iOS OrderDetailView.loadConversation() logic
export const getOrCreateConversationForOrder = async (
  orderId: string,
  listingId: string,
  buyerId: string,
  sellerId: string
): Promise<Conversation> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Find existing conversation - check BOTH directions
  // Conversation could have current user as buyer OR seller
  // IMPORTANT: Include buyer and seller user profiles for proper display names
  const { data: existing, error: searchError } = await supabase
    .from('conversations')
    .select(`
      *,
      buyer:users!buyer_id(*),
      seller:users!seller_id(*),
      listing:listings(*)
    `)
    .eq('listing_id', listingId)
    .or(`and(buyer_id.eq.${userId},seller_id.eq.${userId === buyerId ? sellerId : buyerId}),and(buyer_id.eq.${userId === buyerId ? sellerId : buyerId},seller_id.eq.${userId})`)
    .limit(1);

  if (searchError && searchError.code !== 'PGRST116') {
    throw searchError;
  }

  if (existing && existing.length > 0) {
    console.log('✅ Found existing conversation:', existing[0].id);
    console.log('   Buyer:', existing[0].buyer?.name || 'nil');
    console.log('   Seller:', existing[0].seller?.name || 'nil');
    return existing[0];
  }

  console.log('📝 Creating new conversation for order:', orderId);

  // Create new conversation if none exists
  const { data: created, error: createError } = await supabase
    .from('conversations')
    .insert({
      buyer_id: buyerId,
      seller_id: sellerId,
      listing_id: listingId,
      order_id: orderId,
    })
    .select(`
      *,
      buyer:users!buyer_id(*),
      seller:users!seller_id(*),
      listing:listings(*)
    `)
    .single();

  if (createError) throw createError;

  console.log('✅ Created new conversation:', created.id);
  console.log('   Buyer:', created.buyer?.name || 'nil');
  console.log('   Seller:', created.seller?.name || 'nil');

  return created;
};

// Get messages for a conversation
export const getMessages = async (
  conversationId: string,
  limit = 50,
  beforeId?: string
): Promise<Message[]> => {
  let query = supabase
    .from('messages')
    .select('*, sender:users!sender_id(*)')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: true })
    .limit(limit);

  if (beforeId) {
    // Pagination - get messages before a specific ID
    const { data: refMsg } = await supabase
      .from('messages')
      .select('created_at')
      .eq('id', beforeId)
      .single();
    
    if (refMsg) {
      query = query.lt('created_at', refMsg.created_at);
    }
  }

  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
};

// Send a message
export const sendMessage = async (
  conversationId: string,
  content: string,
  messageType: string = 'text'
): Promise<Message> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  console.log('📤 Sending message:', { userId, conversationId });

  // Check if there's a blocking relationship with the other user
  const conversation = await getConversation(conversationId);
  if (conversation) {
    const otherUserId = conversation.buyer_id === userId ? conversation.seller_id : conversation.buyer_id;
    const isBlocked = await hasBlockingRelationship(userId, otherUserId);
    if (isBlocked) {
      throw new Error('You cannot send messages to this user.');
    }
  }

  const { data, error } = await supabase
    .from('messages')
    .insert({
      conversation_id: conversationId,
      sender_id: userId,
      content,
      message_type: messageType,
    })
    .select('*, sender:users!sender_id(*)')
    .single();

  if (error) {
    console.error('❌ Error sending message:', error);
    // Provide helpful error messages based on error type
    if (error.code === '42501') {
      throw new Error('Permission denied. Please sign out and sign back in, then try again.');
    }
    if (error.code === '23503') {
      throw new Error('Conversation not found or your profile is incomplete.');
    }
    throw error;
  }

  // Update conversation's last_message_at
  await supabase
    .from('conversations')
    .update({ last_message_at: new Date().toISOString() })
    .eq('id', conversationId);

  return data;
};

// Mark messages as read
export const markMessagesAsRead = async (conversationId: string): Promise<void> => {
  const userId = await getCurrentUserId();
  if (!userId) return;

  const { error } = await supabase
    .from('messages')
    .update({ read_at: new Date().toISOString() })
    .eq('conversation_id', conversationId)
    .neq('sender_id', userId)
    .is('read_at', null);

  if (error) {
    console.error('Error marking messages as read:', error);
  }
};

// Delete a message (only own messages)
export const deleteMessage = async (messageId: string): Promise<void> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Only delete if the message belongs to the current user
  const { error } = await supabase
    .from('messages')
    .delete()
    .eq('id', messageId)
    .eq('sender_id', userId);

  if (error) throw error;
};

// Subscribe to new messages in a conversation
export const subscribeToMessages = (
  conversationId: string,
  onMessage: (message: Message) => void
) => {
  const subscription = supabase
    .channel(`messages:${conversationId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `conversation_id=eq.${conversationId}`,
      },
      async (payload) => {
        // Get current user ID to check blocking
        const { data: { session } } = await supabase.auth.getSession();
        const currentUserId = session?.user.id;
        
        // Check if message is from a blocked user
        if (currentUserId && payload.new.sender_id !== currentUserId) {
          const isBlocked = await hasBlockingRelationship(currentUserId, payload.new.sender_id);
          if (isBlocked) {
            console.log('🚫 Ignoring real-time message from blocked user');
            return;
          }
        }
        
        // Fetch the complete message with sender info
        const { data } = await supabase
          .from('messages')
          .select('*, sender:users!sender_id(*)')
          .eq('id', payload.new.id)
          .single();
        
        if (data) {
          onMessage(data);
        }
      }
    )
    .subscribe();

  return () => {
    subscription.unsubscribe();
  };
};

// Get or create a direct conversation with another user (no listing required)
// Used for personal DMs from forum, profile views, etc.
export const getOrCreateDirectConversation = async (
  otherUserId: string
): Promise<Conversation> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  if (userId === otherUserId) {
    throw new Error('Cannot start a conversation with yourself');
  }

  // Check if there's a blocking relationship
  const isBlocked = await hasBlockingRelationship(userId, otherUserId);
  if (isBlocked) {
    throw new Error('You cannot message this user.');
  }

  // Check if a direct conversation already exists (no listing)
  // We check both directions since either user could be buyer/seller
  const { data: existing, error: searchError } = await supabase
    .from('conversations')
    .select(`
      *,
      buyer:users!buyer_id(*),
      seller:users!seller_id(*),
      listing:listings(*)
    `)
    .is('listing_id', null)
    .or(`and(buyer_id.eq.${userId},seller_id.eq.${otherUserId}),and(buyer_id.eq.${otherUserId},seller_id.eq.${userId})`)
    .limit(1);

  if (searchError && searchError.code !== 'PGRST116') {
    throw searchError;
  }

  if (existing && existing.length > 0) {
    console.log('✅ Found existing direct conversation:', existing[0].id);
    return existing[0];
  }

  console.log('📝 Creating new direct conversation with user:', otherUserId);

  // Create new direct conversation (current user as buyer, other as seller)
  const { data: created, error: createError } = await supabase
    .from('conversations')
    .insert({
      buyer_id: userId,
      seller_id: otherUserId,
      listing_id: null,
    })
    .select(`
      *,
      buyer:users!buyer_id(*),
      seller:users!seller_id(*),
      listing:listings(*)
    `)
    .single();

  if (createError) throw createError;

  console.log('✅ Created new direct conversation:', created.id);
  return created;
};

// Archive a conversation
export const archiveConversation = async (conversationId: string): Promise<void> => {
  const userId = await getCurrentUserId();
  if (!userId) {
    console.error('❌ Archive failed: Not authenticated');
    throw new Error('Not authenticated');
  }

  console.log('📝 Archiving conversation:', conversationId, 'for user:', userId);

  // Get the conversation to determine if user is buyer or seller
  const conversation = await getConversation(conversationId);
  if (!conversation) {
    console.error('❌ Archive failed: Conversation not found');
    throw new Error('Conversation not found');
  }

  // Update the appropriate archived field based on user role
  const isBuyer = conversation.buyer_id === userId;
  const updateField = isBuyer 
    ? { archived_by_buyer: true }
    : { archived_by_seller: true };

  console.log('📝 Updating field:', updateField, 'for role:', isBuyer ? 'buyer' : 'seller');

  const { error, data } = await supabase
    .from('conversations')
    .update(updateField)
    .eq('id', conversationId)
    .select();

  if (error) {
    console.error('❌ Database update error:', error);
    throw error;
  }

  console.log('✅ Archive successful, updated data:', data);
};

// Subscribe to conversation updates
export const subscribeToConversations = (
  onUpdate: (conversation: Conversation) => void
) => {
  const getCurrentUserIdSync = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    return session?.user.id;
  };

  let userId: string | undefined;
  getCurrentUserIdSync().then(id => { userId = id ?? undefined; });

  const subscription = supabase
    .channel('conversations')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'conversations',
      },
      async (payload) => {
        const conv = payload.new as any;
        if (conv && userId && (conv.buyer_id === userId || conv.seller_id === userId)) {
          // Fetch the complete conversation
          const fullConv = await getConversation(conv.id);
          if (fullConv) {
            onUpdate(fullConv);
          }
        }
      }
    )
    .subscribe();

  return () => {
    subscription.unsubscribe();
  };
};

export default {
  getConversations,
  getConversation,
  getOrCreateConversation,
  getOrCreateConversationForOrder,
  getOrCreateDirectConversation,
  getMessages,
  sendMessage,
  markMessagesAsRead,
  deleteMessage,
  subscribeToMessages,
  subscribeToConversations,
  archiveConversation,
};

