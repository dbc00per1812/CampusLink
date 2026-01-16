// Community Forum Service - Handle forum channels and messages
import { supabase } from '../config/supabase';
import { ForumMessage, ForumChannel } from '../types/forum';

// Get current user ID
const getCurrentUserId = async (): Promise<string | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.user.id ?? null;
};

// Get current user's campus for filtering (with retry for new users)
const getCurrentUserCampus = async (retryCount = 0): Promise<string | null> => {
  const MAX_RETRIES = 3;
  const RETRY_DELAY_MS = 500;
  
  const userId = await getCurrentUserId();
  if (!userId) return null;
  
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('campus')
      .eq('id', userId)
      .single();
    
    if (error) {
      console.log('🔍 Forum: Error fetching user:', error.message);
      if (retryCount < MAX_RETRIES) {
        console.log(`🔄 Forum: Retrying campus load (attempt ${retryCount + 1}/${MAX_RETRIES})...`);
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS));
        return getCurrentUserCampus(retryCount + 1);
      }
      return null;
    }
    
    if (!user?.campus) {
      console.log('🔍 Forum: Current user has no campus set');
      if (retryCount < MAX_RETRIES) {
        console.log(`🔄 Forum: Campus not set, retrying (attempt ${retryCount + 1}/${MAX_RETRIES})...`);
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS));
        return getCurrentUserCampus(retryCount + 1);
      }
      return null;
    }
    
    return user.campus;
  } catch (err) {
    console.error('❌ Forum: Error fetching user campus:', err);
    return null;
  }
};

// Get messages for a forum channel (filtered by campus)
export const getForumMessages = async (
  channel: ForumChannel,
  limit = 100
): Promise<ForumMessage[]> => {
  // Get current user's campus for filtering
  const userCampus = await getCurrentUserCampus();
  
  // Use inner join to filter messages by sender's campus
  let query = supabase
    .from('forum_messages')
    .select('*, sender:users!inner(*)') // inner join for campus filtering
    .eq('channel', channel);
  
  // Apply campus filter - only show messages from same campus
  if (userCampus) {
    query = query.eq('users.campus', userCampus);
    console.log(`🔍 Forum: Filtering messages by campus: ${userCampus}`);
  }
  
  const { data, error } = await query
    .order('created_at', { ascending: true })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
};

// Send a forum message
export const sendForumMessage = async (
  channel: ForumChannel,
  content: string
): Promise<ForumMessage> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('forum_messages')
    .insert({
      channel,
      sender_id: userId,
      content,
    })
    .select('*, sender:users!sender_id(*)')
    .single();

  if (error) throw error;
  return data;
};

// Subscribe to new messages in a forum channel (with campus filtering)
export const subscribeToForumMessages = (
  channel: ForumChannel,
  onMessage: (message: ForumMessage) => void
) => {
  // Get user's campus once for filtering incoming messages
  let userCampus: string | null = null;
  getCurrentUserCampus().then(campus => {
    userCampus = campus;
    console.log(`🔍 Forum Subscription: Filtering by campus: ${userCampus}`);
  });

  const subscription = supabase
    .channel(`forum:${channel}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'forum_messages',
        filter: `channel=eq.${channel}`,
      },
      async (payload) => {
        // Fetch the complete message with sender info
        const { data } = await supabase
          .from('forum_messages')
          .select('*, sender:users!sender_id(*)')
          .eq('id', payload.new.id)
          .single();
        
        if (data) {
          // Filter by campus - only show messages from same campus
          if (userCampus && data.sender?.campus !== userCampus) {
            console.log(`🔍 Forum: Ignoring message from different campus: ${data.sender?.campus}`);
            return; // Skip messages from different campuses
          }
          onMessage(data);
        }
      }
    )
    .subscribe();

  return () => {
    subscription.unsubscribe();
  };
};

// Delete a forum message (only own messages)
export const deleteForumMessage = async (messageId: string): Promise<void> => {
  const userId = await getCurrentUserId();
  if (!userId) throw new Error('Not authenticated');

  // Only delete if the message belongs to the current user
  const { error } = await supabase
    .from('forum_messages')
    .delete()
    .eq('id', messageId)
    .eq('sender_id', userId);

  if (error) throw error;
};

export default {
  getForumMessages,
  sendForumMessage,
  subscribeToForumMessages,
  deleteForumMessage,
};

