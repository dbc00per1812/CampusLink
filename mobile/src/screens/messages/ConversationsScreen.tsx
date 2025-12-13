// ConversationsScreen - List of conversations
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { UserAvatar, LoadingSpinner, EmptyState } from '../../components';
import { getConversations, subscribeToConversations } from '../../services/messagingService';
import { supabase } from '../../config/supabase';
import { Conversation, User } from '../../types';
import Colors from '../../utils/colors';

const ConversationsScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  useEffect(() => {
    loadUserId();
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadConversations();
    }, [])
  );

  useEffect(() => {
    // Subscribe to conversation updates
    const unsubscribe = subscribeToConversations((updatedConv) => {
      setConversations(prev => {
        const index = prev.findIndex(c => c.id === updatedConv.id);
        if (index >= 0) {
          const updated = [...prev];
          updated[index] = updatedConv;
          return updated.sort((a, b) => 
            new Date(b.last_message_at || b.created_at).getTime() - 
            new Date(a.last_message_at || a.created_at).getTime()
          );
        }
        return [updatedConv, ...prev];
      });
    });

    return () => unsubscribe();
  }, []);

  const loadUserId = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    setCurrentUserId(session?.user.id ?? null);
  };

  const loadConversations = async () => {
    try {
      const data = await getConversations();
      setConversations(data);
    } catch (error) {
      console.error('Error loading conversations:', error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadConversations();
  };

  const getOtherUser = (conversation: Conversation): User | null => {
    if (!currentUserId) return null;
    if (conversation.buyer_id === currentUserId) {
      return conversation.seller ?? null;
    }
    return conversation.buyer ?? null;
  };

  const getRelativeTime = (dateStr: string): string => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return 'now';
    if (diffMins < 60) return `${diffMins}m`;
    if (diffHours < 24) return `${diffHours}h`;
    if (diffDays < 7) return `${diffDays}d`;
    return date.toLocaleDateString();
  };

  const isUnread = (conversation: Conversation): boolean => {
    if (!currentUserId || !conversation.last_message) return false;
    return (
      conversation.last_message.sender_id !== currentUserId &&
      !conversation.last_message.read_at
    );
  };

  const renderConversation = ({ item }: { item: Conversation }) => {
    const otherUser = getOtherUser(item);
    const unread = isUnread(item);
    const timeStr = getRelativeTime(item.last_message_at || item.created_at);

    return (
      <TouchableOpacity
        style={styles.conversationRow}
        onPress={() => navigation.navigate('Chat', { conversationId: item.id })}
      >
        <UserAvatar user={otherUser} size={56} />
        
        <View style={styles.conversationContent}>
          <View style={styles.conversationHeader}>
            <Text style={[styles.userName, unread && styles.unreadText]} numberOfLines={1}>
              {otherUser?.name || 'Unknown'}
            </Text>
            <Text style={styles.timeText}>{timeStr}</Text>
          </View>
          
          <View style={styles.previewRow}>
            <Text 
              style={[styles.previewText, unread && styles.unreadText]} 
              numberOfLines={2}
            >
              {item.last_message?.content || 'No messages yet'}
            </Text>
            {unread && <View style={styles.unreadDot} />}
          </View>
          
          {item.listing && (
            <View style={styles.listingRow}>
              <Ionicons name="pricetag" size={12} color={Colors.primary} />
              <Text style={styles.listingTitle} numberOfLines={1}>
                {item.listing.title}
              </Text>
            </View>
          )}
        </View>
        
        <Ionicons name="chevron-forward" size={16} color={Colors.textTertiary} />
      </TouchableOpacity>
    );
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading conversations..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Messages</Text>
        <TouchableOpacity onPress={handleRefresh} style={styles.refreshButton}>
          <Ionicons name="refresh" size={24} color={Colors.primary} />
        </TouchableOpacity>
      </View>

      {conversations.length === 0 ? (
        <EmptyState
          icon="chatbubbles-outline"
          title="No Conversations Yet"
          message="Start a conversation by contacting a seller about their listing"
        />
      ) : (
        <FlatList
          data={conversations}
          renderItem={renderConversation}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          refreshControl={
            <RefreshControl
              refreshing={isRefreshing}
              onRefresh={handleRefresh}
              tintColor={Colors.primary}
            />
          }
          ItemSeparatorComponent={() => <View style={styles.separator} />}
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: Colors.textPrimary,
  },
  refreshButton: {
    padding: 8,
  },
  listContent: {
    paddingBottom: 20,
  },
  conversationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  conversationContent: {
    flex: 1,
    marginLeft: 12,
    marginRight: 8,
  },
  conversationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  userName: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
    flex: 1,
  },
  timeText: {
    fontSize: 12,
    color: Colors.textTertiary,
    marginLeft: 8,
  },
  previewRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  previewText: {
    fontSize: 14,
    color: Colors.textSecondary,
    flex: 1,
    lineHeight: 20,
  },
  unreadText: {
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  unreadDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.primary,
    marginLeft: 8,
  },
  listingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
    gap: 4,
  },
  listingTitle: {
    fontSize: 12,
    color: Colors.primary,
    flex: 1,
  },
  separator: {
    height: 1,
    backgroundColor: Colors.border,
    marginLeft: 84,
  },
});

export default ConversationsScreen;
