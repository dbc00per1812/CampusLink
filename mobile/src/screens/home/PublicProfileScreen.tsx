// Public Profile Screen - View another user's profile
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  ActivityIndicator,
  Alert,
  RefreshControl,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { HomeScreenProps } from '../../navigation/types';
import { getUserById, getUserListings } from '../../services/userService';
import { getRatingsSummary } from '../../services/ratingService';
import { getCurrentUserId } from '../../services/authService';
import { User, ListingWithUser, UserRatingsSummary, getTrustLevelFromScore, TrustLevelEmoji } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows } from '../../utils/spacing';
import { UserAvatar, ListingCard, ReportUserModal } from '../../components';

type Props = HomeScreenProps<'PublicProfile'>;

const PublicProfileScreen: React.FC<Props> = ({ navigation, route }) => {
  const { userId } = route.params;
  const colors = useColors();
  
  const [user, setUser] = useState<User | null>(null);
  const [listings, setListings] = useState<ListingWithUser[]>([]);
  const [ratingsSummary, setRatingsSummary] = useState<UserRatingsSummary | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isLoadingRatings, setIsLoadingRatings] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);

  const isOwnProfile = currentUserId === userId;

  const loadData = useCallback(async () => {
    try {
      const [userData, listingsData, currentUser] = await Promise.all([
        getUserById(userId),
        getUserListings(userId, { includeArchived: false, includeSold: false }),
        getCurrentUserId(),
      ]);

      setUser(userData);
      setListings(listingsData);
      setCurrentUserId(currentUser);

      // Load ratings
      setIsLoadingRatings(true);
      try {
        const ratingsData = await getRatingsSummary(userId);
        setRatingsSummary(ratingsData);
      } catch (error) {
        console.error('Failed to load ratings:', error);
      } finally {
        setIsLoadingRatings(false);
      }
    } catch (error) {
      console.error('Failed to load user profile:', error);
      Alert.alert('Error', 'Failed to load user profile');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, [userId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadData();
  };

  const handleListingPress = (listing: ListingWithUser) => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    navigation.navigate('ListingDetail', { listingId: listing.id });
  };

  const handleReport = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    setShowReportModal(true);
  }, []);

  const handleBlock = useCallback(() => {
    if (!user) return;
    
    Alert.alert(
      'Block User',
      `Are you sure you want to block ${user.name || 'this user'}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Block',
          style: 'destructive',
          onPress: () => {
            if (Platform.OS !== 'web') {
              Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
            }
            Alert.alert('Success', 'User blocked successfully');
          },
        },
      ]
    );
  }, [user]);

  const formatMemberSince = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'long',
      year: 'numeric',
    });
  };

  // Set header with three-dot menu for non-own profiles
  useEffect(() => {
    if (!isOwnProfile && user) {
      navigation.setOptions({
        headerRight: () => (
          <Pressable
            onPress={() => {
              if (Platform.OS !== 'web') {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              }
              Alert.alert('Profile Actions', '', [
                { text: 'Report User', onPress: handleReport, style: 'destructive' },
                { text: 'Block User', onPress: handleBlock, style: 'destructive' },
                { text: 'Cancel', style: 'cancel' },
              ]);
            }}
            style={({ pressed }) => ({ opacity: pressed ? 0.5 : 1 })}
          >
            <Ionicons name="ellipsis-horizontal-circle-outline" size={24} color={colors.primary} />
          </Pressable>
        ),
      });
    }
  }, [isOwnProfile, user, colors, navigation, handleReport, handleBlock]);

  if (isLoading) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  if (!user) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: colors.background }]}>
        <Text style={[styles.errorText, { color: colors.textSecondary }]}>
          User not found
        </Text>
      </View>
    );
  }

  const trustScore = user.trust_score ?? 100;
  const averageRating = (trustScore / 100) * 5;
  const trustLevel = getTrustLevelFromScore(trustScore);
  const trustEmoji = TrustLevelEmoji[trustLevel];

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['bottom']}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor={colors.primary}
          />
        }
      >
        {/* Profile Header */}
        <View style={styles.profileHeader}>
          {/* Avatar */}
          <UserAvatar user={user} size={100} />

          {/* Name */}
          <Text style={[styles.name, { color: colors.textPrimary }]}>
            {user.name || 'Unknown User'}
          </Text>

          {/* Bio */}
          {user.bio && (
            <Text style={[styles.bio, { color: colors.textSecondary }]}>
              {user.bio}
            </Text>
          )}

          {/* Campus */}
          {user.campus && (
            <View style={styles.campusRow}>
              <Ionicons name="school-outline" size={16} color={colors.textSecondary} />
              <Text style={[styles.campusText, { color: colors.textSecondary }]}>
                {user.campus}
              </Text>
            </View>
          )}

          {/* Verified Student Badge */}
          {user.verification_status === 'verified' && (
            <View style={[styles.verifiedBadge, { backgroundColor: colors.primaryMuted }]}>
              <Ionicons name="checkmark-circle" size={16} color={colors.primary} />
              <Text style={[styles.verifiedText, { color: colors.primary }]}>
                Verified Student
              </Text>
            </View>
          )}

          {/* Member Since */}
          <Text style={[styles.memberSince, { color: colors.textTertiary }]}>
            Member since {formatMemberSince(user.created_at)}
          </Text>

          {/* Ratings Summary */}
          {isLoadingRatings ? (
            <ActivityIndicator size="small" color={colors.primary} style={styles.ratingsLoader} />
          ) : ratingsSummary && ratingsSummary.total_ratings > 0 ? (
            <View style={styles.ratingContainer}>
              <View style={styles.starsRow}>
                {[...Array(5)].map((_, i) => {
                  const fullStars = Math.floor(averageRating);
                  const hasHalfStar = averageRating % 1 >= 0.5;
                  
                  if (i < fullStars) {
                    return <Ionicons key={i} name="star" size={18} color="#FFD700" />;
                  } else if (i === fullStars && hasHalfStar) {
                    return <Ionicons key={i} name="star-half" size={18} color="#FFD700" />;
                  } else {
                    return <Ionicons key={i} name="star-outline" size={18} color={colors.textTertiary} />;
                  }
                })}
              </View>
              <Text style={[styles.ratingText, { color: colors.textPrimary }]}>
                {averageRating.toFixed(1)} ({ratingsSummary.total_ratings})
              </Text>
              <Text style={styles.trustEmoji}>{trustEmoji}</Text>
            </View>
          ) : (
            <View style={styles.ratingContainer}>
              <View style={styles.starsRow}>
                {[...Array(5)].map((_, i) => (
                  <Ionicons key={i} name="star" size={18} color="#FFD700" />
                ))}
              </View>
              <Text style={[styles.ratingText, { color: colors.textSecondary }]}>
                New Seller
              </Text>
            </View>
          )}
        </View>

        {/* Stats Row */}
        <View style={[styles.statsRow, { backgroundColor: colors.surfaceSecondary }]}>
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: colors.textPrimary }]}>
              {listings.length}
            </Text>
            <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
              Listings
            </Text>
          </View>

          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: colors.textPrimary }]}>
              {trustScore}
            </Text>
            <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
              Trust Score
            </Text>
          </View>

          {ratingsSummary && ratingsSummary.total_ratings > 0 && (
            <View style={styles.statItem}>
              <Text style={[styles.statValue, { color: colors.textPrimary }]}>
                {ratingsSummary.total_ratings}
              </Text>
              <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
                Ratings
              </Text>
            </View>
          )}
        </View>

        {/* Active Listings Section */}
        <View style={styles.listingsSection}>
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            Active Listings
          </Text>

          {listings.length === 0 ? (
            <View style={styles.emptyState}>
              <Ionicons name="cube-outline" size={48} color={colors.textTertiary} />
              <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
                No active listings
              </Text>
            </View>
          ) : (
            <View style={styles.listingsGrid}>
              {listings.map((listing) => (
                <View key={listing.id} style={styles.listingCardWrapper}>
                  <ListingCard
                    listing={listing}
                    onPress={() => handleListingPress(listing)}
                    showSeller={false}
                  />
                </View>
              ))}
            </View>
          )}
        </View>
      </ScrollView>

      {/* Report User Modal */}
      <ReportUserModal
        visible={showReportModal}
        onClose={() => setShowReportModal(false)}
        reportedUserId={userId}
        reportedUserName={user?.name}
        onBlockUser={handleBlock}
      />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorText: {
    ...Typography.body,
  },
  profileHeader: {
    alignItems: 'center',
    paddingVertical: Spacing.xl,
    paddingHorizontal: Spacing.lg,
  },
  name: {
    ...Typography.title2,
    fontWeight: '600',
    marginTop: Spacing.md,
    textAlign: 'center',
  },
  bio: {
    ...Typography.subheadline,
    marginTop: Spacing.sm,
    textAlign: 'center',
    paddingHorizontal: Spacing.lg,
  },
  campusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: Spacing.sm,
  },
  campusText: {
    ...Typography.subheadline,
  },
  verifiedBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.lg,
    marginTop: Spacing.sm,
  },
  verifiedText: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  memberSince: {
    ...Typography.caption1,
    marginTop: Spacing.sm,
  },
  ratingsLoader: {
    marginTop: Spacing.sm,
  },
  ratingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    marginTop: Spacing.sm,
  },
  starsRow: {
    flexDirection: 'row',
    gap: 2,
  },
  ratingText: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  trustEmoji: {
    fontSize: 14,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: Spacing.lg,
    marginHorizontal: Spacing.lg,
    borderRadius: BorderRadius.md,
    marginBottom: Spacing.lg,
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    ...Typography.title3,
    fontWeight: '700',
  },
  statLabel: {
    ...Typography.caption1,
    marginTop: 4,
  },
  listingsSection: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xl,
  },
  sectionTitle: {
    ...Typography.headline,
    fontWeight: '600',
    marginBottom: Spacing.md,
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: Spacing.xxl * 2,
  },
  emptyText: {
    ...Typography.subheadline,
    marginTop: Spacing.md,
  },
  listingsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.md,
  },
  listingCardWrapper: {
    width: '48%',
  },
});

export default PublicProfileScreen;
