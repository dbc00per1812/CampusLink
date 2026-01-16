// Community Forum Screen - Open channels for all users
import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TextInput,
  Pressable,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ActionSheetIOS,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as Haptics from 'expo-haptics';
import { UserAvatar, LoadingSpinner, EmptyState } from '../../components';
import {
  getForumMessages,
  sendForumMessage,
  subscribeToForumMessages,
  deleteForumMessage,
} from '../../services/forumService';
import { getOrCreateDirectConversation } from '../../services/messagingService';
import { supabase } from '../../config/supabase';
import { ForumMessage, ForumChannel } from '../../types/forum';
import { User } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows } from '../../utils/spacing';

interface CommunityForumScreenProps {
  onBack?: () => void;
}

const CommunityForumScreen: React.FC<CommunityForumScreenProps> = ({ onBack }) => {
  const colors = useColors();
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const flatListRef = useRef<FlatList>(null);

  const [selectedChannel, setSelectedChannel] = useState<ForumChannel>('general');
  const [messages, setMessages] = useState<ForumMessage[]>([]);
  const [messageText, setMessageText] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [isStartingDM, setIsStartingDM] = useState(false);

  useEffect(() => {
    loadUserId();
    loadMessages();
  }, [selectedChannel]);

  useEffect(() => {
    const unsubscribe = subscribeToForumMessages(selectedChannel, (newMessage) => {
      setMessages(prev => {
        if (prev.some(m => m.id === newMessage.id)) return prev;
        return [...prev, newMessage];
      });
      // Auto-scroll to bottom when new message arrives
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    });

    return () => unsubscribe();
  }, [selectedChannel]);

  const loadUserId = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    setCurrentUserId(session?.user.id ?? null);
  };

  const loadMessages = async () => {
    setIsLoading(true);
    try {
      const data = await getForumMessages(selectedChannel);
      setMessages(data);
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: false });
      }, 100);
    } catch (error) {
      console.error('Error loading forum messages:', error);
      Alert.alert('Error', 'Failed to load messages. Please try again.');
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
      const newMessage = await sendForumMessage(selectedChannel, text);
      // Duplicate check: realtime subscription may have already added this message
      setMessages(prev => {
        if (prev.some(m => m.id === newMessage.id)) return prev;
        return [...prev, newMessage];
      });
      
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    } catch (error: any) {
      console.error('Error sending forum message:', error);
      Alert.alert('Error', 'Failed to send message. Please try again.');
      setMessageText(text);
    } finally {
      setIsSending(false);
    }
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

  const shouldShowDateHeader = (currentMessage: ForumMessage, index: number): boolean => {
    if (index === 0) return true;
    const prevMessage = messages[index - 1];
    const currentDate = new Date(currentMessage.created_at).toDateString();
    const prevDate = new Date(prevMessage.created_at).toDateString();
    return currentDate !== prevDate;
  };

  const handleDeleteMessage = async (messageId: string) => {
    try {
      await deleteForumMessage(messageId);
      setMessages(prev => prev.filter(m => m.id !== messageId));
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }
    } catch (error: any) {
      console.error('Error deleting forum message:', error);
      Alert.alert('Error', 'Failed to delete message. Please try again.');
    }
  };

  const handleMessageLongPress = (message: ForumMessage) => {
    // Only allow deleting own messages
    if (message.sender_id !== currentUserId) return;

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }

    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          options: ['Cancel', 'Delete Message'],
          destructiveButtonIndex: 1,
          cancelButtonIndex: 0,
        },
        (buttonIndex) => {
          if (buttonIndex === 1) {
            Alert.alert(
              'Delete Message',
              'Are you sure you want to delete this message?',
              [
                { text: 'Cancel', style: 'cancel' },
                { 
                  text: 'Delete', 
                  style: 'destructive',
                  onPress: () => handleDeleteMessage(message.id)
                },
              ]
            );
          }
        }
      );
    } else {
      Alert.alert(
        'Delete Message',
        'Are you sure you want to delete this message?',
        [
          { text: 'Cancel', style: 'cancel' },
          { 
            text: 'Delete', 
            style: 'destructive',
            onPress: () => handleDeleteMessage(message.id)
          },
        ]
      );
    }
  };

  // Handle tapping on a forum user's avatar or name
  const handleUserTap = (user: User | null | undefined, senderId: string) => {
    if (!user || senderId === currentUserId) return;

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }

    const userName = user.name || 'this user';

    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          options: ['Cancel', 'Send Direct Message', 'View Profile'],
          cancelButtonIndex: 0,
          title: userName,
        },
        (buttonIndex) => {
          if (buttonIndex === 1) {
            startDirectMessage(user);
          } else if (buttonIndex === 2) {
            viewUserProfile(user);
          }
        }
      );
    } else {
      Alert.alert(
        userName,
        'What would you like to do?',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Send Direct Message', onPress: () => startDirectMessage(user) },
          { text: 'View Profile', onPress: () => viewUserProfile(user) },
        ]
      );
    }
  };

  // Start a direct message conversation with a forum user
  const startDirectMessage = async (user: User) => {
    if (isStartingDM) return;
    
    setIsStartingDM(true);
    try {
      const conversation = await getOrCreateDirectConversation(user.id);
      
      // Navigate to chat screen
      navigation.navigate('Chat', {
        conversationId: conversation.id,
        returnScreen: 'ConversationsList',
      });
    } catch (error: any) {
      console.error('Error starting DM:', error);
      Alert.alert('Error', error.message || 'Failed to start conversation. Please try again.');
    } finally {
      setIsStartingDM(false);
    }
  };

  // Navigate to user's public profile
  const viewUserProfile = (user: User) => {
    navigation.navigate('Home', {
      screen: 'PublicProfile',
      params: { userId: user.id }
    });
  };

  const renderMessage = ({ item, index }: { item: ForumMessage; index: number }) => {
    const isOwnMessage = item.sender_id === currentUserId;
    const showDateHeader = shouldShowDateHeader(item, index);
    const canTapUser = !isOwnMessage && item.sender;

    return (
      <View>
        {showDateHeader && (
          <View style={styles.dateHeader}>
            <Text style={[styles.dateHeaderText, { color: colors.textTertiary }]}>
              {formatDateHeader(item.created_at)}
            </Text>
          </View>
        )}
        
        <View
          style={[
            styles.messageContainer,
            isOwnMessage ? styles.ownMessageContainer : styles.otherMessageContainer,
          ]}
        >
          {!isOwnMessage && (
            <Pressable 
              style={({ pressed }) => [
                styles.avatarContainer,
                pressed && canTapUser && { opacity: 0.7 },
              ]}
              onPress={() => handleUserTap(item.sender, item.sender_id)}
              disabled={!canTapUser}
            >
              <UserAvatar user={item.sender} size={32} />
            </Pressable>
          )}
          
          <Pressable
            onLongPress={() => handleMessageLongPress(item)}
            delayLongPress={500}
            style={({ pressed }) => [
              styles.messageBubble,
              isOwnMessage
                ? [styles.ownMessage, { backgroundColor: colors.primary }]
                : [styles.otherMessage, { backgroundColor: colors.surfaceSecondary }],
              pressed && isOwnMessage && { opacity: 0.8 },
            ]}
          >
            {!isOwnMessage && (
              <Pressable
                onPress={() => handleUserTap(item.sender, item.sender_id)}
                disabled={!canTapUser}
                style={({ pressed }) => [pressed && canTapUser && { opacity: 0.7 }]}
              >
                <Text style={[styles.senderName, { color: colors.primary }]}>
                  {item.sender?.name || 'Anonymous'}
                </Text>
              </Pressable>
            )}
            <Text
              style={[
                styles.messageText,
                { color: isOwnMessage ? '#FFFFFF' : colors.textPrimary },
              ]}
            >
              {item.content}
            </Text>
            <Text
              style={[
                styles.messageTime,
                { color: isOwnMessage ? 'rgba(255,255,255,0.7)' : colors.textTertiary },
              ]}
            >
              {formatTime(item.created_at)}
            </Text>
          </Pressable>
          
          {isOwnMessage && <View style={styles.avatarPlaceholder} />}
        </View>
      </View>
    );
  };

  const handleBack = () => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    onBack?.();
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      {/* Header with channel tabs */}
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <View style={styles.headerTop}>
          {onBack && (
            <Pressable
              onPress={handleBack}
              style={({ pressed }) => [
                styles.backButton,
                { opacity: pressed ? 0.5 : 1 },
              ]}
            >
              <Ionicons name="chevron-back" size={28} color={colors.primary} />
            </Pressable>
          )}
          <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>
            Community
          </Text>
          <View style={styles.headerSpacer} />
        </View>
        
        <View style={[styles.channelTabs, { backgroundColor: colors.surfaceSecondary }]}>
          <Pressable
            onPress={() => {
              setSelectedChannel('general');
              if (Platform.OS !== 'web') {
                Haptics.selectionAsync();
              }
            }}
            style={[
              styles.channelTab,
              selectedChannel === 'general' && [
                styles.channelTabActive,
                { backgroundColor: colors.primary },
              ],
            ]}
          >
            <Text
              style={[
                styles.channelTabText,
                { color: selectedChannel === 'general' ? '#FFFFFF' : colors.textSecondary },
              ]}
            >
              General
            </Text>
          </Pressable>
          
          <Pressable
            onPress={() => {
              setSelectedChannel('support');
              if (Platform.OS !== 'web') {
                Haptics.selectionAsync();
              }
            }}
            style={[
              styles.channelTab,
              selectedChannel === 'support' && [
                styles.channelTabActive,
                { backgroundColor: colors.primary },
              ],
            ]}
          >
            <Text
              style={[
                styles.channelTabText,
                { color: selectedChannel === 'support' ? '#FFFFFF' : colors.textSecondary },
              ]}
            >
              Support
            </Text>
          </Pressable>
        </View>
      </View>

      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={90}
      >
        {isLoading ? (
          <LoadingSpinner fullScreen message="Loading messages..." />
        ) : messages.length === 0 ? (
          <EmptyState
            icon="chatbubbles-outline"
            title={`No Messages in ${selectedChannel === 'general' ? 'General' : 'Support'}`}
            message="Be the first to start a conversation!"
          />
        ) : (
          <FlatList
            ref={flatListRef}
            data={messages}
            renderItem={renderMessage}
            keyExtractor={(item) => item.id}
            contentContainerStyle={styles.messagesList}
            showsVerticalScrollIndicator={false}
            onContentSizeChange={() => flatListRef.current?.scrollToEnd({ animated: true })}
          />
        )}

        {/* Message input */}
        <View style={[styles.inputContainer, { backgroundColor: colors.background, borderTopColor: colors.border }]}>
          <View style={[styles.inputWrapper, { backgroundColor: colors.surfaceSecondary }]}>
            <TextInput
              style={[styles.input, { color: colors.textPrimary }]}
              placeholder={`Message #${selectedChannel}`}
              placeholderTextColor={colors.textTertiary}
              value={messageText}
              onChangeText={setMessageText}
              multiline
              maxLength={1000}
            />
            <Pressable
              onPress={handleSend}
              disabled={!messageText.trim() || isSending}
              style={({ pressed }) => [
                styles.sendButton,
                {
                  backgroundColor: messageText.trim() && !isSending ? colors.primary : colors.surfaceSecondary,
                  opacity: pressed ? 0.7 : 1,
                },
              ]}
            >
              <Ionicons
                name="send"
                size={20}
                color={messageText.trim() && !isSending ? '#FFFFFF' : colors.textTertiary}
              />
            </Pressable>
          </View>
        </View>
      </KeyboardAvoidingView>
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
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    gap: Spacing.md,
  },
  headerTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  backButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    marginLeft: -8,
  },
  headerTitle: {
    ...Typography.largeTitle,
    flex: 1,
    textAlign: 'center',
  },
  headerSpacer: {
    width: 40,
  },
  channelTabs: {
    flexDirection: 'row',
    borderRadius: BorderRadius.md,
    padding: 4,
  },
  channelTab: {
    flex: 1,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.md,
    borderRadius: BorderRadius.sm,
    alignItems: 'center',
  },
  channelTabActive: {
    ...Shadows.sm,
  },
  channelTabText: {
    ...Typography.subheadline,
    fontWeight: '600',
  },
  messagesList: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.lg,
    paddingBottom: Spacing.xl,
  },
  dateHeader: {
    alignItems: 'center',
    marginVertical: Spacing.lg,
  },
  dateHeaderText: {
    ...Typography.caption1,
    fontWeight: '600',
  },
  messageContainer: {
    flexDirection: 'row',
    marginBottom: Spacing.md,
    alignItems: 'flex-end',
  },
  ownMessageContainer: {
    justifyContent: 'flex-end',
  },
  otherMessageContainer: {
    justifyContent: 'flex-start',
  },
  avatarContainer: {
    marginRight: Spacing.sm,
    marginBottom: 2,
  },
  avatarPlaceholder: {
    width: 32,
  },
  messageBubble: {
    maxWidth: '70%',
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    gap: 2,
  },
  ownMessage: {
    borderBottomRightRadius: 4,
  },
  otherMessage: {
    borderBottomLeftRadius: 4,
  },
  senderName: {
    ...Typography.caption1,
    fontWeight: '600',
    marginBottom: 2,
  },
  messageText: {
    ...Typography.body,
    lineHeight: 20,
  },
  messageTime: {
    ...Typography.caption2,
    marginTop: 2,
  },
  inputContainer: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderTopWidth: 1,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    gap: Spacing.sm,
  },
  input: {
    flex: 1,
    ...Typography.body,
    maxHeight: 100,
    paddingVertical: Spacing.xs,
  },
  sendButton: {
    width: 36,
    height: 36,
    borderRadius: BorderRadius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
});

export default CommunityForumScreen;

