// BlockedUsersScreen - View and manage blocked users
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  RefreshControl,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { supabase } from '../../config/supabase';
import { getCurrentUserId } from '../../services/authService';
import Colors from '../../utils/colors';

interface BlockedUserDisplay {
  id: string;
  blocked_id: string;
  created_at: string;
  user: {
    id: string;
    name: string;
    profile_pic: string | null;
    email: string;
  } | null;
}

const BlockedUsersScreen: React.FC = () => {
  const navigation = useNavigation();
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [blockedUsers, setBlockedUsers] = useState<BlockedUserDisplay[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [unblockingId, setUnblockingId] = useState<string | null>(null);

  useEffect(() => {
    getCurrentUserId().then(setCurrentUserId);
  }, []);

  const fetchBlockedUsers = useCallback(async () => {
    if (!currentUserId) return;

    try {
      const { data, error } = await supabase
        .from('blocked_users')
        .select(`
          id,
          blocked_id,
          created_at,
          user:users!blocked_users_blocked_id_fkey(id, name, profile_pic, email)
        `)
        .eq('blocker_id', currentUserId)
        .order('created_at', { ascending: false });

      if (error) throw error;

      setBlockedUsers(data || []);
    } catch (error) {
      console.error('Error fetching blocked users:', error);
      Alert.alert('Error', 'Failed to load blocked users');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [currentUserId]);

  useEffect(() => {
    fetchBlockedUsers();
  }, [fetchBlockedUsers]);

  const handleRefresh = useCallback(() => {
    setRefreshing(true);
    fetchBlockedUsers();
  }, [fetchBlockedUsers]);

  const handleUnblock = useCallback(async (blockedUser: BlockedUserDisplay) => {
    const userName = blockedUser.user?.name || 'this user';
    
    Alert.alert(
      'Unblock User',
      `Are you sure you want to unblock ${userName}? They will be able to see your listings and message you again.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Unblock',
          onPress: async () => {
            setUnblockingId(blockedUser.id);
            try {
              const { error } = await supabase
                .from('blocked_users')
                .delete()
                .eq('id', blockedUser.id);

              if (error) throw error;

              setBlockedUsers(prev => prev.filter(u => u.id !== blockedUser.id));
              Alert.alert('Success', `${userName} has been unblocked`);
            } catch (error) {
              console.error('Error unblocking user:', error);
              Alert.alert('Error', 'Failed to unblock user. Please try again.');
            } finally {
              setUnblockingId(null);
            }
          },
        },
      ]
    );
  }, []);

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const renderEmptyState = () => (
    <View style={styles.emptyContainer}>
      <Ionicons name="checkmark-circle-outline" size={64} color={Colors.textTertiary} />
      <Text style={styles.emptyTitle}>No Blocked Users</Text>
      <Text style={styles.emptyDescription}>
        You haven't blocked anyone yet. When you block a user, they'll appear here.
      </Text>
    </View>
  );

  const renderBlockedUser = ({ item }: { item: BlockedUserDisplay }) => {
    const isUnblocking = unblockingId === item.id;
    
    return (
      <View style={styles.userItem}>
        <View style={styles.userInfo}>
          {item.user?.profile_pic ? (
            <Image source={{ uri: item.user.profile_pic }} style={styles.avatar} />
          ) : (
            <View style={[styles.avatar, styles.avatarPlaceholder]}>
              <Ionicons name="person" size={20} color={Colors.textTertiary} />
            </View>
          )}
          <View style={styles.userDetails}>
            <Text style={styles.userName}>{item.user?.name || 'Unknown User'}</Text>
            <Text style={styles.blockedDate}>Blocked on {formatDate(item.created_at)}</Text>
          </View>
        </View>
        <TouchableOpacity
          style={[styles.unblockButton, isUnblocking && styles.unblockButtonDisabled]}
          onPress={() => handleUnblock(item)}
          disabled={isUnblocking}
        >
          {isUnblocking ? (
            <ActivityIndicator size="small" color={Colors.primary} />
          ) : (
            <Text style={styles.unblockButtonText}>Unblock</Text>
          )}
        </TouchableOpacity>
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="chevron-back" size={28} color={Colors.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Blocked Users</Text>
        <View style={{ width: 28 }} />
      </View>

      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={Colors.primary} />
        </View>
      ) : (
        <FlatList
          data={blockedUsers}
          keyExtractor={(item) => item.id}
          renderItem={renderBlockedUser}
          contentContainerStyle={blockedUsers.length === 0 ? styles.emptyListContent : styles.listContent}
          ListEmptyComponent={renderEmptyState}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={handleRefresh}
              tintColor={Colors.primary}
            />
          }
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
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  listContent: {
    paddingVertical: 16,
  },
  emptyListContent: {
    flex: 1,
    justifyContent: 'center',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 40,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginTop: 16,
  },
  emptyDescription: {
    fontSize: 14,
    color: Colors.textSecondary,
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 20,
  },
  userItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.surface,
    paddingVertical: 12,
    paddingHorizontal: 16,
    marginHorizontal: 16,
    marginBottom: 8,
    borderRadius: 12,
  },
  userInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  avatarPlaceholder: {
    backgroundColor: Colors.border,
    justifyContent: 'center',
    alignItems: 'center',
  },
  userDetails: {
    marginLeft: 12,
    flex: 1,
  },
  userName: {
    fontSize: 16,
    fontWeight: '500',
    color: Colors.textPrimary,
  },
  blockedDate: {
    fontSize: 13,
    color: Colors.textTertiary,
    marginTop: 2,
  },
  unblockButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.primary,
    minWidth: 80,
    alignItems: 'center',
  },
  unblockButtonDisabled: {
    opacity: 0.5,
  },
  unblockButtonText: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.primary,
  },
});

export default BlockedUsersScreen;

