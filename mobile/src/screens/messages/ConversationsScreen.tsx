// ConversationsScreen - Modern messages list with Community tab
import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  RefreshControl,
  Platform,
  Animated,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Swipeable } from 'react-native-gesture-handler';
import * as Haptics from 'expo-haptics';
import { UserAvatar, LoadingSpinner, EmptyState } from '../../components';
import { getConversations, subscribeToConversations, archiveConversation } from '../../services/messagingService';
import { supabase } from '../../config/supabase';
import { Conversation, User } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows } from '../../utils/spacing';
import CommunityForumScreen from './CommunityForumScreen';

type TabType = 'messages' | 'community';

const ConversationsScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const colors = useColors();
  const [activeTab, setActiveTab] = useState<TabType>('messages');
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
    const unsubscribe = subscribeToConversations((updatedConv) => {
      setConversations(prev => {
        // Check if this conversation is archived by current user
        const isArchivedByMe = currentUserId && (
          (updatedConv.buyer_id === currentUserId && updatedConv.archived_by_buyer) ||
          (updatedConv.seller_id === currentUserId && updatedConv.archived_by_seller)
        );

        // If archived, remove it from the list
        if (isArchivedByMe) {
          return prev.filter(c => c.id !== updatedConv.id);
        }

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
  }, [currentUserId]);

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

  const handleConversationPress = useCallback((conversationId: string) => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    navigation.navigate('Chat', { 
      conversationId,
      returnScreen: 'ConversationsList'
    });
  }, [navigation]);

  const handleArchiveConversation = useCallback(async (conversation: Conversation) => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }

    try {
      // Optimistically remove from UI
      setConversations(prev => prev.filter(c => c.id !== conversation.id));
      
      // Archive in database
      await archiveConversation(conversation.id);
      console.log('✅ Conversation archived successfully:', conversation.id);
    } catch (error: any) {
      console.error('❌ Error archiving conversation:', error);
      console.error('Error details:', error.message || error);
      
      // Check if it's a column doesn't exist error
      if (error.message?.includes('column') || error.message?.includes('archived_by')) {
        Alert.alert(
          'Database Update Required',
          'The archive feature requires a database update. Please run the SQL migration in Supabase dashboard.\n\nFile: docs/sql/add_conversation_archive_fields.sql',
          [{ text: 'OK' }]
        );
      } else {
        Alert.alert('Error', `Failed to archive conversation: ${error.message || 'Unknown error'}`);
      }
      
      // Reload conversations on error
      loadConversations();
    }
  }, []);

  const renderRightActions = (
    conversation: Conversation,
    progress: Animated.AnimatedInterpolation<number>
  ) => {
    const translateX = progress.interpolate({
      inputRange: [0, 1],
      outputRange: [80, 0],
    });

    return (
      <Animated.View
        style={[
          styles.swipeAction,
          { transform: [{ translateX }] },
        ]}
      >
        <Pressable
          style={[styles.deleteButton, { backgroundColor: colors.error }]}
          onPress={() => handleArchiveConversation(conversation)}
        >
          <Ionicons name="trash-outline" size={24} color="#FFFFFF" />
          <Text style={styles.deleteText}>Delete</Text>
        </Pressable>
      </Animated.View>
    );
  };

  const renderConversation = ({ item }: { item: Conversation }) => {
    const otherUser = getOtherUser(item);
    const unread = isUnread(item);
    const timeStr = getRelativeTime(item.last_message_at || item.created_at);

    return (
      <Swipeable
        renderRightActions={(progress) => renderRightActions(item, progress)}
        overshootRight={false}
        friction={2}
      >
        <Pressable
          style={({ pressed }) => [
            styles.conversationRow,
            { backgroundColor: pressed ? colors.surfaceSecondary : colors.background },
          ]}
          onPress={() => handleConversationPress(item.id)}
        >
          <View style={styles.avatarWrapper}>
            <UserAvatar user={otherUser} size={56} />
            {unread && (
              <View style={[styles.unreadBadge, { backgroundColor: colors.primary }]} />
            )}
          </View>
          
          <View style={styles.conversationContent}>
            <View style={styles.conversationHeader}>
              <Text
                style={[
                  styles.userName,
                  { color: colors.textPrimary },
                  unread && styles.unreadText,
                ]}
                numberOfLines={1}
              >
                {otherUser?.name || 'Unknown'}
              </Text>
              <Text style={[styles.timeText, { color: colors.textTertiary }]}>
                {timeStr}
              </Text>
            </View>
            
            <Text 
              style={[
                styles.previewText,
                { color: unread ? colors.textPrimary : colors.textSecondary },
                unread && styles.unreadText,
              ]} 
              numberOfLines={2}
            >
              {item.last_message?.content || 'No messages yet'}
            </Text>
            
            {item.listing && (
              <View style={[styles.listingBadge, { backgroundColor: colors.primaryMuted }]}>
                <Ionicons name="pricetag" size={10} color={colors.primary} />
                <Text style={[styles.listingTitle, { color: colors.primary }]} numberOfLines={1}>
                  {item.listing.title}
                </Text>
              </View>
            )}
          </View>
          
          <Ionicons name="chevron-forward" size={18} color={colors.textTertiary} />
        </Pressable>
      </Swipeable>
    );
  };

  if (isLoading && activeTab === 'messages') {
    return <LoadingSpinner fullScreen message="Loading conversations..." />;
  }

  // Render Community tab
  if (activeTab === 'community') {
    return <CommunityForumScreen onBack={() => setActiveTab('messages')} />;
  }

  // Render Messages tab
  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>
          Messages
        </Text>
        <Pressable
          onPress={handleRefresh}
          style={({ pressed }) => [
            styles.refreshButton,
            { backgroundColor: colors.primaryMuted, opacity: pressed ? 0.7 : 1 },
          ]}
        >
          <Ionicons name="refresh" size={20} color={colors.primary} />
        </Pressable>
      </View>

      {/* Tab Switcher */}
      <View style={[styles.tabContainer, { backgroundColor: colors.background }]}>
        <Pressable
          onPress={() => {
            setActiveTab('messages');
            if (Platform.OS !== 'web') {
              Haptics.selectionAsync();
            }
          }}
          style={[
            styles.tab,
            activeTab === 'messages' && [styles.tabActive, { borderBottomColor: colors.primary }],
          ]}
        >
          <Text
            style={[
              styles.tabText,
              { color: activeTab === 'messages' ? colors.primary : colors.textSecondary },
            ]}
          >
            Direct Messages
          </Text>
        </Pressable>
        
        <Pressable
          onPress={() => {
            setActiveTab('community');
            if (Platform.OS !== 'web') {
              Haptics.selectionAsync();
            }
          }}
          style={[
            styles.tab,
            activeTab === 'community' && [styles.tabActive, { borderBottomColor: colors.primary }],
          ]}
        >
          <Text
            style={[
              styles.tabText,
              { color: activeTab === 'community' ? colors.primary : colors.textSecondary },
            ]}
          >
            Community
          </Text>
        </Pressable>
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
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl
              refreshing={isRefreshing}
              onRefresh={handleRefresh}
              tintColor={colors.primary}
            />
          }
          ItemSeparatorComponent={() => (
            <View style={[styles.separator, { backgroundColor: colors.border }]} />
          )}
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
  },
  headerTitle: {
    ...Typography.largeTitle,
  },
  refreshButton: {
    width: 40,
    height: 40,
    borderRadius: BorderRadius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
  listContent: {
    paddingBottom: Spacing.xl,
  },
  conversationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  avatarWrapper: {
    position: 'relative',
  },
  unreadBadge: {
    position: 'absolute',
    top: 0,
    right: 0,
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 2,
    borderColor: '#FFFFFF',
  },
  conversationContent: {
    flex: 1,
    marginLeft: Spacing.md,
    marginRight: Spacing.sm,
    gap: 4,
  },
  conversationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  userName: {
    ...Typography.headline,
    flex: 1,
  },
  timeText: {
    ...Typography.caption2,
    marginLeft: Spacing.sm,
  },
  previewText: {
    ...Typography.subheadline,
    lineHeight: 20,
  },
  unreadText: {
    fontWeight: '600',
  },
  listingBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    paddingHorizontal: Spacing.sm,
    paddingVertical: 3,
    borderRadius: BorderRadius.sm,
    gap: 4,
    marginTop: 2,
  },
  listingTitle: {
    ...Typography.caption2,
    fontWeight: '500',
  },
  separator: {
    height: 1,
    marginLeft: 84,
  },
  swipeAction: {
    width: 80,
    justifyContent: 'center',
    alignItems: 'center',
  },
  deleteButton: {
    flex: 1,
    width: 80,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 4,
  },
  deleteText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  tabContainer: {
    flexDirection: 'row',
    paddingHorizontal: Spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(0,0,0,0.1)',
  },
  tab: {
    flex: 1,
    paddingVertical: Spacing.md,
    alignItems: 'center',
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabActive: {
    borderBottomWidth: 2,
  },
  tabText: {
    ...Typography.subheadline,
    fontWeight: '600',
  },
});

export default ConversationsScreen;
