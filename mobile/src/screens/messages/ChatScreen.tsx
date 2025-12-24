// Chat Screen - Modern iMessage-style design
import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TextInput,
  Pressable,
  KeyboardAvoidingView,
  Platform,
  Image,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, RouteProp, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as Haptics from 'expo-haptics';
import { UserAvatar, LoadingSpinner, ReportUserModal } from '../../components';
import {
  getConversation,
  getMessages,
  sendMessage,
  markMessagesAsRead,
  subscribeToMessages,
} from '../../services/messagingService';
import { supabase } from '../../config/supabase';
import { Conversation, Message, User } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows } from '../../utils/spacing';

type RouteParams = {
  Chat: { 
    conversationId: string;
    returnScreen?: 'ListingDetail' | 'ConversationsList';
    returnParams?: { listingId?: string };
  };
};

const ChatScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const route = useRoute<RouteProp<RouteParams, 'Chat'>>();
  const colors = useColors();
  const { conversationId, returnScreen, returnParams } = route.params;
  const flatListRef = useRef<FlatList>(null);

  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [messageText, setMessageText] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [showReportModal, setShowReportModal] = useState(false);

  useEffect(() => {
    loadUserId();
    loadConversation();
    loadMessages();
  }, [conversationId]);

  useEffect(() => {
    const unsubscribe = subscribeToMessages(conversationId, (newMessage) => {
      setMessages(prev => {
        if (prev.some(m => m.id === newMessage.id)) return prev;
        return [...prev, newMessage];
      });
      if (currentUserId && newMessage.sender_id !== currentUserId) {
        markMessagesAsRead(conversationId);
      }
    });

    return () => unsubscribe();
  }, [conversationId, currentUserId]);

  useFocusEffect(
    useCallback(() => {
      markMessagesAsRead(conversationId);
    }, [conversationId])
  );

  const loadUserId = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    setCurrentUserId(session?.user.id ?? null);
  };

  const loadConversation = async () => {
    try {
      const data = await getConversation(conversationId);
      setConversation(data);
    } catch (error) {
      console.error('Error loading conversation:', error);
    }
  };

  const loadMessages = async () => {
    try {
      const data = await getMessages(conversationId);
      setMessages(data);
    } catch (error) {
      console.error('Error loading messages:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSend = async () => {
    if (!messageText.trim() || isSending) return;

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }

    const text = messageText.trim();
    setMessageText('');
    setIsSending(true);

    try {
      const newMessage = await sendMessage(conversationId, text);
      setMessages(prev => [...prev, newMessage]);
      
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    } catch (error: any) {
      console.error('Error sending message:', error);
      Alert.alert('Error', 'Failed to send message. Please try again.');
      setMessageText(text);
    } finally {
      setIsSending(false);
    }
  };

  const getOtherUser = (): User | null => {
    if (!currentUserId || !conversation) return null;
    if (conversation.buyer_id === currentUserId) {
      return conversation.seller ?? null;
    }
    return conversation.buyer ?? null;
  };

  const formatTime = (dateStr: string): string => {
    const date = new Date(dateStr);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const formatDateHeader = (dateStr: string): string => {
    const date = new Date(dateStr);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    if (date.toDateString() === today.toDateString()) {
      return 'Today';
    } else if (date.toDateString() === yesterday.toDateString()) {
      return 'Yesterday';
    }
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
  };

  const renderMessage = ({ item, index }: { item: Message; index: number }) => {
    const isMe = item.sender_id === currentUserId;
    const showAvatar = !isMe && (index === 0 || messages[index - 1].sender_id !== item.sender_id);
    const showTimestamp = index === messages.length - 1 ||
      new Date(messages[index + 1]?.created_at).getTime() - new Date(item.created_at).getTime() > 300000; // 5 min gap

    return (
      <View style={styles.messageContainer}>
        <View style={[styles.messageRow, isMe ? styles.messageRowMe : styles.messageRowOther]}>
          {!isMe && (
            <View style={styles.avatarContainer}>
              {showAvatar ? (
                <UserAvatar user={item.sender as User} size={28} />
              ) : (
                <View style={styles.avatarPlaceholder} />
              )}
            </View>
          )}
          
          <View
            style={[
              styles.messageBubble,
              isMe
                ? [styles.bubbleMe, { backgroundColor: colors.primary }]
                : [styles.bubbleOther, { backgroundColor: colors.surfaceSecondary }],
            ]}
          >
            <Text
              style={[
                styles.messageText,
                { color: isMe ? colors.textInverse : colors.textPrimary },
              ]}
            >
              {item.content}
            </Text>
          </View>
        </View>
        
        {showTimestamp && (
          <Text
            style={[
              styles.timestamp,
              { color: colors.textTertiary },
              isMe ? styles.timestampMe : styles.timestampOther,
            ]}
          >
            {formatTime(item.created_at)}
          </Text>
        )}
      </View>
    );
  };

  const otherUser = getOtherUser();

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading chat..." />;
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      <KeyboardAvoidingView 
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.flex}
        keyboardVerticalOffset={0}
      >
        {/* Header */}
        <View style={[styles.header, { borderBottomColor: colors.border }]}>
          <Pressable
            onPress={() => {
              if (returnScreen === 'ListingDetail' && returnParams?.listingId) {
                navigation.navigate('Home', {
                  screen: 'ListingDetail',
                  params: { listingId: returnParams.listingId }
                });
              } else {
                navigation.goBack();
              }
            }}
            style={({ pressed }) => [styles.backButton, { opacity: pressed ? 0.5 : 1 }]}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons name="chevron-back" size={28} color={colors.primary} />
          </Pressable>
          
          <Pressable
            style={({ pressed }) => [styles.headerCenter, { opacity: pressed ? 0.7 : 1 }]}
            onPress={() => otherUser && navigation.navigate('Home', {
              screen: 'PublicProfile',
              params: { 
                userId: otherUser.id,
                returnTo: 'Chat',
                returnParams: { conversationId }
              }
            })}
          >
            {otherUser && <UserAvatar user={otherUser} size={36} />}
            <Text style={[styles.headerTitle, { color: colors.textPrimary }]} numberOfLines={1}>
              {otherUser?.name || 'Chat'}
            </Text>
          </Pressable>
          
          <Pressable 
            onPress={() => {
              if (Platform.OS !== 'web') {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              }
              setShowReportModal(true);
            }} 
            style={({ pressed }) => [styles.headerButton, { opacity: pressed ? 0.5 : 1 }]}
          >
            <Ionicons name="ellipsis-horizontal" size={24} color={colors.textSecondary} />
          </Pressable>
        </View>

        {/* Listing Info Bar */}
        {conversation?.listing && (
          <Pressable 
            style={({ pressed }) => [
              styles.listingBar,
              { backgroundColor: colors.surfaceSecondary, opacity: pressed ? 0.8 : 1 },
            ]}
            onPress={() => navigation.navigate('Home', { 
              screen: 'ListingDetail',
              params: { 
                listingId: conversation.listing!.id,
                returnTo: 'Chat',
                returnParams: { conversationId }
              }
            })}
          >
            {conversation.listing.photo && (
              <Image 
                source={{ uri: conversation.listing.photo }} 
                style={styles.listingImage} 
              />
            )}
            <View style={styles.listingInfo}>
              <Text style={[styles.listingTitle, { color: colors.textPrimary }]} numberOfLines={1}>
                {conversation.listing.title}
              </Text>
              <Text style={[styles.listingPrice, { color: colors.success }]}>
                ${conversation.listing.price?.toFixed(2)}
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={16} color={colors.textTertiary} />
          </Pressable>
        )}

        {/* Messages */}
        <FlatList
          ref={flatListRef}
          data={messages}
          renderItem={renderMessage}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.messagesList}
          onContentSizeChange={() => flatListRef.current?.scrollToEnd()}
          showsVerticalScrollIndicator={false}
          inverted={false}
        />

        {/* Input Bar */}
        <View style={[styles.inputBar, { borderTopColor: colors.border, backgroundColor: colors.background }]}>
          <View style={[styles.inputContainer, { backgroundColor: colors.surfaceSecondary }]}>
            <TextInput
              style={[styles.textInput, { color: colors.textPrimary }]}
              value={messageText}
              onChangeText={setMessageText}
              placeholder="Message..."
              placeholderTextColor={colors.textTertiary}
              multiline
              maxLength={1000}
              editable={!isSending}
            />
          </View>
          
          <Pressable
            style={({ pressed }) => [
              styles.sendButton,
              {
                backgroundColor: messageText.trim() ? colors.primary : colors.surfaceSecondary,
                opacity: pressed && messageText.trim() ? 0.8 : 1,
              },
            ]}
            onPress={handleSend}
            disabled={!messageText.trim() || isSending}
          >
            {isSending ? (
              <LoadingSpinner size="small" color={colors.textInverse} />
            ) : (
              <Ionicons 
                name="arrow-up" 
                size={20} 
                color={messageText.trim() ? colors.textInverse : colors.textTertiary} 
              />
            )}
          </Pressable>
        </View>
      </KeyboardAvoidingView>

      {/* Report User Modal */}
      <ReportUserModal
        visible={showReportModal}
        onClose={() => setShowReportModal(false)}
        reportedUserId={otherUser?.id}
        reportedUserName={otherUser?.name}
      />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  flex: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
  },
  backButton: {
    padding: Spacing.xs,
  },
  backButtonText: {
    fontSize: 17,
    fontWeight: '400',
  },
  headerCenter: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.sm,
  },
  headerTitle: {
    ...Typography.headline,
  },
  headerButton: {
    padding: Spacing.sm,
  },
  listingBar: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.sm,
    gap: Spacing.md,
  },
  listingImage: {
    width: 44,
    height: 44,
    borderRadius: BorderRadius.md,
  },
  listingInfo: {
    flex: 1,
  },
  listingTitle: {
    ...Typography.footnote,
    fontWeight: '500',
  },
  listingPrice: {
    ...Typography.footnoteBold,
  },
  messagesList: {
    padding: Spacing.md,
    paddingBottom: Spacing.xl,
  },
  messageContainer: {
    marginVertical: Spacing.xs,
  },
  messageRow: {
    flexDirection: 'row',
    maxWidth: '80%',
  },
  messageRowMe: {
    alignSelf: 'flex-end',
  },
  messageRowOther: {
    alignSelf: 'flex-start',
  },
  avatarContainer: {
    width: 28,
    marginRight: Spacing.sm,
    alignSelf: 'flex-end',
  },
  avatarPlaceholder: {
    width: 28,
    height: 28,
  },
  messageBubble: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: 20,
    maxWidth: '100%',
  },
  bubbleMe: {
    borderBottomRightRadius: 4,
  },
  bubbleOther: {
    borderBottomLeftRadius: 4,
  },
  messageText: {
    ...Typography.body,
  },
  timestamp: {
    ...Typography.caption2,
    marginTop: Spacing.xs,
  },
  timestampMe: {
    textAlign: 'right',
    marginRight: Spacing.xs,
  },
  timestampOther: {
    textAlign: 'left',
    marginLeft: 36 + Spacing.sm,
  },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    paddingBottom: Platform.OS === 'ios' ? Spacing.lg : Spacing.md,
    borderTopWidth: 1,
    gap: Spacing.sm,
  },
  inputContainer: {
    flex: 1,
    borderRadius: 22,
    paddingHorizontal: Spacing.md,
    paddingVertical: Platform.OS === 'ios' ? Spacing.sm : Spacing.xs,
    minHeight: 44,
    justifyContent: 'center',
  },
  textInput: {
    ...Typography.body,
    maxHeight: 100,
    paddingTop: 0,
    paddingBottom: 0,
  },
  sendButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
});

export default ChatScreen;
