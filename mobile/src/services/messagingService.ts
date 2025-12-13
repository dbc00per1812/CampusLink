// Messaging Service - Handle conversations and messages
import { supabase } from '../config/supabase';
import { Conversation, Message, MessageCreate } from '../types';

// Get current user ID
const getCurrentUserId = async (): Promise<string | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.user.id ?? null;
};

// Get all conversations for current user
export const getConversations = async (): Promise<Conversation[]> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

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
  
  // Process and return conversations with last message
  return (data ?? []).map(conv => ({
    ...conv,
    last_message: conv.last_message?.[0] || null,
  }));
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

  if (error) throw error;

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
  getMessages,
  sendMessage,
  markMessagesAsRead,
  subscribeToMessages,
  subscribeToConversations,
};

