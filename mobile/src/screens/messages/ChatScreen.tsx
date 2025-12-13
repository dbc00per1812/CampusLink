// ChatScreen - Full chat with real-time messages
import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Image,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, RouteProp, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { UserAvatar, LoadingSpinner } from '../../components';
import {
  getConversation,
  getMessages,
  sendMessage,
  markMessagesAsRead,
  subscribeToMessages,
} from '../../services/messagingService';
import { supabase } from '../../config/supabase';
import { Conversation, Message, User } from '../../types';
import Colors from '../../utils/colors';

type RouteParams = {
  Chat: { conversationId: string };
};

const ChatScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const route = useRoute<RouteProp<RouteParams, 'Chat'>>();
  const { conversationId } = route.params;
  const flatListRef = useRef<FlatList>(null);

  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [messageText, setMessageText] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  useEffect(() => {
    loadUserId();
    loadConversation();
    loadMessages();
  }, [conversationId]);

  useEffect(() => {
    // Subscribe to new messages
    const unsubscribe = subscribeToMessages(conversationId, (newMessage) => {
      setMessages(prev => {
        // Check if message already exists
        if (prev.some(m => m.id === newMessage.id)) return prev;
        return [...prev, newMessage];
      });
      // Mark as read if from other user
      if (currentUserId && newMessage.sender_id !== currentUserId) {
        markMessagesAsRead(conversationId);
      }
    });

    return () => unsubscribe();
  }, [conversationId, currentUserId]);

  useFocusEffect(
    useCallback(() => {
      // Mark messages as read when screen is focused
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

    const text = messageText.trim();
    setMessageText('');
    setIsSending(true);

    try {
      const newMessage = await sendMessage(conversationId, text);
      setMessages(prev => [...prev, newMessage]);
      
      // Scroll to bottom
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    } catch (error: any) {
      console.error('Error sending message:', error);
      Alert.alert('Error', 'Failed to send message. Please try again.');
      setMessageText(text); // Restore text
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

  const renderMessage = ({ item, index }: { item: Message; index: number }) => {
    const isMe = item.sender_id === currentUserId;
    const showAvatar = !isMe && (index === 0 || messages[index - 1].sender_id !== item.sender_id);

    return (
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
        
        <View style={[styles.messageBubble, isMe ? styles.bubbleMe : styles.bubbleOther]}>
          <Text style={[styles.messageText, isMe ? styles.textMe : styles.textOther]}>
            {item.content}
          </Text>
        </View>
      </View>
    );
  };

  const otherUser = getOtherUser();

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading chat..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <KeyboardAvoidingView 
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.flex}
        keyboardVerticalOffset={0}
      >
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
            <Ionicons name="chevron-back" size={28} color={Colors.textPrimary} />
          </TouchableOpacity>
          
          <View style={styles.headerCenter}>
            <Text style={styles.headerTitle} numberOfLines={1}>
              {otherUser?.name || 'Chat'}
            </Text>
          </View>
          
          <TouchableOpacity 
            onPress={() => Alert.alert('Report', 'Report this user?')} 
            style={styles.headerButton}
          >
            <Ionicons name="flag-outline" size={22} color={Colors.error} />
          </TouchableOpacity>
        </View>

        {/* Listing Info Bar */}
        {conversation?.listing && (
          <TouchableOpacity 
            style={styles.listingBar}
            onPress={() => navigation.navigate('ListingDetail', { 
              listingId: conversation.listing!.id 
            })}
          >
            {conversation.listing.photo && (
              <Image 
                source={{ uri: conversation.listing.photo }} 
                style={styles.listingImage} 
              />
            )}
            <View style={styles.listingInfo}>
              <Text style={styles.listingTitle} numberOfLines={1}>
                {conversation.listing.title}
              </Text>
              <Text style={styles.listingPrice}>
                ${conversation.listing.price?.toFixed(2)}
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={16} color={Colors.textTertiary} />
          </TouchableOpacity>
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
        />

        {/* Input Bar */}
        <View style={styles.inputBar}>
          <TextInput
            style={styles.textInput}
            value={messageText}
            onChangeText={setMessageText}
            placeholder="Type a message..."
            placeholderTextColor={Colors.textTertiary}
            multiline
            maxLength={1000}
            editable={!isSending}
            onSubmitEditing={handleSend}
          />
          <TouchableOpacity
            style={[
              styles.sendButton,
              (!messageText.trim() || isSending) && styles.sendButtonDisabled
            ]}
            onPress={handleSend}
            disabled={!messageText.trim() || isSending}
          >
            {isSending ? (
              <LoadingSpinner size="small" color={Colors.textInverse} />
            ) : (
              <Ionicons 
                name="arrow-up-circle" 
                size={32} 
                color={messageText.trim() ? Colors.primary : Colors.textTertiary} 
              />
            )}
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  flex: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  backButton: {
    padding: 4,
  },
  headerCenter: {
    flex: 1,
    alignItems: 'center',
    paddingHorizontal: 8,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  headerButton: {
    padding: 8,
  },
  listingBar: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 8,
    backgroundColor: Colors.surfaceSecondary,
    gap: 12,
  },
  listingImage: {
    width: 40,
    height: 40,
    borderRadius: 8,
  },
  listingInfo: {
    flex: 1,
  },
  listingTitle: {
    fontSize: 13,
    fontWeight: '500',
    color: Colors.textPrimary,
  },
  listingPrice: {
    fontSize: 12,
    color: Colors.textSecondary,
  },
  messagesList: {
    padding: 12,
    paddingBottom: 20,
  },
  messageRow: {
    flexDirection: 'row',
    marginVertical: 4,
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
    marginRight: 8,
    alignSelf: 'flex-end',
  },
  avatarPlaceholder: {
    width: 28,
    height: 28,
  },
  messageBubble: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 18,
    maxWidth: '100%',
  },
  bubbleMe: {
    backgroundColor: Colors.primary,
    borderBottomRightRadius: 4,
  },
  bubbleOther: {
    backgroundColor: Colors.surfaceSecondary,
    borderBottomLeftRadius: 4,
  },
  messageText: {
    fontSize: 16,
    lineHeight: 22,
  },
  textMe: {
    color: Colors.textInverse,
  },
  textOther: {
    color: Colors.textPrimary,
  },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    backgroundColor: Colors.background,
  },
  textInput: {
    flex: 1,
    minHeight: 40,
    maxHeight: 100,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 10,
    fontSize: 16,
    color: Colors.textPrimary,
    marginRight: 8,
  },
  sendButton: {
    padding: 4,
  },
  sendButtonDisabled: {
    opacity: 0.5,
  },
});

export default ChatScreen;
