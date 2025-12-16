// Profile Screen - Modern iOS-aligned design
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  RefreshControl,
  Alert,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as Haptics from 'expo-haptics';
import { UserAvatar, LoadingSpinner, Button } from '../../components';
import { signOut } from '../../services/authService';
import { getMyListings } from '../../services/listingService';
import { supabase } from '../../config/supabase';
import { User, Listing, getTrustLevelFromScore } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows, Layout } from '../../utils/spacing';

interface MenuItemProps {
  icon: keyof typeof Ionicons.glyphMap;
  iconColor: string;
  iconBgColor: string;
  label: string;
  onPress: () => void;
}

const MenuItem: React.FC<MenuItemProps> = ({
  icon,
  iconColor,
  iconBgColor,
  label,
  onPress,
}) => {
  const colors = useColors();

  return (
    <Pressable
      style={({ pressed }) => [
        styles.menuItem,
        { backgroundColor: colors.surface, opacity: pressed ? 0.8 : 1 },
        Shadows.xs,
      ]}
      onPress={onPress}
    >
      <View style={[styles.menuIcon, { backgroundColor: iconBgColor }]}>
        <Ionicons name={icon} size={22} color={iconColor} />
      </View>
      <Text style={[styles.menuText, { color: colors.textPrimary }]}>
        {label}
      </Text>
      <Ionicons name="chevron-forward" size={20} color={colors.textTertiary} />
    </Pressable>
  );
};

const ProfileScreen: React.FC = () => {
  const navigation = useNavigation<NativeStackNavigationProp<any>>();
  const colors = useColors();
  const [user, setUser] = useState<User | null>(null);
  const [myListings, setMyListings] = useState<Listing[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useFocusEffect(
    useCallback(() => {
      loadUserData();
    }, [])
  );

  const loadUserData = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        const { data } = await supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single();
        
        setUser(data);
      }

      const listings = await getMyListings({ includeArchived: false, includeSold: true });
      setMyListings(listings);
    } catch (error) {
      console.error('Error loading user data:', error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
    loadUserData();
  };

  const handleSignOut = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    
    Alert.alert(
      'Sign Out',
      'Are you sure you want to sign out?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Sign Out',
          style: 'destructive',
          onPress: async () => {
            try {
              await signOut();
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Failed to sign out');
            }
          },
        },
      ]
    );
  };

  const handleMenuPress = useCallback((action: string) => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    
    switch (action) {
      case 'myListings':
        navigation.navigate('MyListings');
        break;
      case 'orders':
        navigation.navigate('Wallet', { screen: 'OrdersList' });
        break;
      case 'wallet':
        navigation.navigate('Wallet');
        break;
      case 'notifications':
        Alert.alert('Coming Soon', 'Notification settings feature is under development');
        break;
      case 'settings':
        navigation.navigate('Settings');
        break;
      case 'editProfile':
        navigation.navigate('EditProfile');
        break;
      case 'viewRatings':
        Alert.alert('Coming Soon', 'View Ratings feature is under development');
        break;
    }
  }, [navigation]);

  const activeListings = myListings.filter(l => !l.is_sold && !l.archived).length;
  const soldListings = myListings.filter(l => l.is_sold).length;

  // Calculate rating from trust_score
  const trustScore = user?.trust_score ?? 100;
  const averageRating = (trustScore / 100) * 5; // Convert trust_score (0-100) to rating (0-5)
  const trustLevel = getTrustLevelFromScore(trustScore);
  // For now, use a default count - in production this would come from database
  const totalRatings = trustScore === 100 ? 0 : Math.floor(Math.random() * 20) + 5;

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading profile..." />;
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      <ScrollView
        style={styles.scrollView}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor={colors.primary}
          />
        }
      >
        {/* Profile Header - Aligned with iOS */}
        <View style={styles.profileHeaderContainer}>
          <Text style={[styles.profileTitle, { color: colors.textPrimary }]}>
            Profile
          </Text>
        </View>
        
        <View style={styles.profileHeader}>
          <View style={styles.avatarContainer}>
            <UserAvatar user={user} size={120} />
            <Pressable
              style={[styles.editAvatarButton, { backgroundColor: colors.primary, borderColor: colors.background }]}
              onPress={() => handleMenuPress('editProfile')}
            >
              <Ionicons name="pencil" size={14} color={colors.textInverse} />
            </Pressable>
          </View>
          
          <Text style={[styles.userName, { color: colors.textPrimary }]}>
            {user?.name || 'User'}
          </Text>
          
          {/* Campus - Always show, matching iOS */}
          <View style={styles.campusRow}>
            <Ionicons name="school-outline" size={16} color={colors.textSecondary} />
            <Text style={[styles.campusText, { color: colors.textSecondary }]}>
              {user?.campus || 'Campus Marketplace'}
            </Text>
          </View>
          
          {user?.bio && (
            <Text style={[styles.bio, { color: colors.textSecondary }]}>
              {user.bio}
            </Text>
          )}

          {/* Rating Display */}
          <Pressable
            style={({ pressed }) => [
              styles.ratingButton,
              { backgroundColor: colors.surface, opacity: pressed ? 0.8 : 1 },
              Shadows.sm,
            ]}
            onPress={() => handleMenuPress('viewRatings')}
          >
            <View style={styles.starsRow}>
              {[1, 2, 3, 4, 5].map((star) => (
                <Ionicons
                  key={star}
                  name={star <= Math.round(averageRating) ? 'star' : 'star-outline'}
                  size={18}
                  color={star <= Math.round(averageRating) ? '#FFD700' : colors.textTertiary}
                />
              ))}
            </View>
            <View style={styles.divider} />
            <Text style={[styles.myReviewsText, { color: colors.textPrimary }]}>
              My Reviews
            </Text>
            <Ionicons name="chevron-forward" size={16} color={colors.textTertiary} />
          </Pressable>

          {/* Edit Profile Button - Blue outline style matching iOS */}
          <Pressable
            style={({ pressed }) => [
              styles.editButton,
              { borderColor: colors.primary, opacity: pressed ? 0.7 : 1 },
            ]}
            onPress={() => handleMenuPress('editProfile')}
          >
            <Ionicons name="pencil" size={16} color={colors.primary} />
            <Text style={[styles.editButtonText, { color: colors.primary }]}>
              Edit Profile
            </Text>
          </Pressable>
        </View>

        {/* Stats */}
        <View style={[styles.statsContainer, { backgroundColor: colors.surface }, Shadows.sm]}>
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: colors.textPrimary }]}>
              {activeListings}
            </Text>
            <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
              Active
            </Text>
          </View>
          <View style={[styles.statDivider, { backgroundColor: colors.border }]} />
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: colors.textPrimary }]}>
              {soldListings}
            </Text>
            <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
              Sold
            </Text>
          </View>
          <View style={[styles.statDivider, { backgroundColor: colors.border }]} />
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: colors.textPrimary }]}>
              {myListings.length}
            </Text>
            <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
              Total
            </Text>
          </View>
        </View>

        {/* My Stuff Section */}
        <View style={styles.menuSection}>
          <Text style={[styles.menuSectionTitle, { color: colors.textSecondary }]}>
            My Stuff
          </Text>
          
          <MenuItem
            icon="grid-outline"
            iconColor={colors.primary}
            iconBgColor={colors.primaryMuted}
            label="My Listings"
            onPress={() => handleMenuPress('myListings')}
          />
          
          <MenuItem
            icon="receipt-outline"
            iconColor={colors.success}
            iconBgColor={colors.successLight}
            label="My Orders"
            onPress={() => handleMenuPress('orders')}
          />
          
          <MenuItem
            icon="wallet-outline"
            iconColor={colors.warning}
            iconBgColor={colors.warningLight}
            label="Wallet"
            onPress={() => handleMenuPress('wallet')}
          />
        </View>

        {/* Settings Section */}
        <View style={styles.menuSection}>
          <Text style={[styles.menuSectionTitle, { color: colors.textSecondary }]}>
            Settings
          </Text>
          
          <MenuItem
            icon="notifications-outline"
            iconColor={colors.error}
            iconBgColor={colors.errorLight}
            label="Notifications"
            onPress={() => handleMenuPress('notifications')}
          />
          
          <MenuItem
            icon="settings-outline"
            iconColor={colors.textSecondary}
            iconBgColor={colors.surfaceSecondary}
            label="Settings"
            onPress={() => handleMenuPress('settings')}
          />
        </View>

        {/* Sign Out Button */}
        <Pressable
          style={({ pressed }) => [
            styles.signOutButton,
            { backgroundColor: colors.errorLight, opacity: pressed ? 0.8 : 1 },
          ]}
          onPress={handleSignOut}
        >
          <Ionicons name="log-out-outline" size={22} color={colors.error} />
          <Text style={[styles.signOutText, { color: colors.error }]}>
            Sign Out
          </Text>
        </Pressable>

        {/* Version */}
        <Text style={[styles.versionText, { color: colors.textTertiary }]}>
          CampusLink v2.0
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  profileHeaderContainer: {
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
  },
  profileTitle: {
    ...Typography.title1,
    fontWeight: '600',
  },
  profileHeader: {
    alignItems: 'center',
    paddingVertical: Spacing.xl,
    paddingHorizontal: Spacing.lg,
  },
  avatarContainer: {
    position: 'relative',
    marginBottom: Spacing.sm,
  },
  editAvatarButton: {
    position: 'absolute',
    bottom: 4,
    right: 4,
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
  },
  userName: {
    ...Typography.title1,
    marginTop: Spacing.sm,
  },
  campusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    marginTop: Spacing.xs,
  },
  campusText: {
    ...Typography.footnote,
  },
  bio: {
    ...Typography.body,
    textAlign: 'center',
    marginTop: Spacing.sm,
    paddingHorizontal: Spacing['2xl'],
  },
  ratingButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.md,
    marginTop: Spacing.lg,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    borderRadius: BorderRadius.full,
    alignSelf: 'center',
  },
  starsRow: {
    flexDirection: 'row',
    gap: 2,
  },
  divider: {
    width: 1,
    height: 20,
    backgroundColor: '#E5E5EA',
    marginHorizontal: Spacing.xs,
  },
  myReviewsText: {
    ...Typography.subheadline,
    fontWeight: '600',
  },
  trustBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    marginTop: Spacing.md,
  },
  trustScore: {
    ...Typography.footnoteBold,
  },
  editButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    marginTop: Spacing.lg,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    borderWidth: 1.5,
  },
  editButtonText: {
    ...Typography.subheadlineBold,
  },
  statsContainer: {
    flexDirection: 'row',
    marginHorizontal: Spacing.lg,
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    marginBottom: Spacing.xl,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
  },
  statValue: {
    ...Typography.title1,
  },
  statLabel: {
    ...Typography.caption1,
    marginTop: 2,
  },
  statDivider: {
    width: 1,
  },
  menuSection: {
    marginBottom: Spacing.xl,
  },
  menuSectionTitle: {
    ...Typography.footnoteBold,
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.sm,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    marginHorizontal: Spacing.lg,
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.sm,
  },
  menuIcon: {
    width: 40,
    height: 40,
    borderRadius: BorderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  menuText: {
    flex: 1,
    ...Typography.body,
    marginLeft: Spacing.md,
  },
  signOutButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    marginHorizontal: Spacing.lg,
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.lg,
  },
  signOutText: {
    ...Typography.button,
  },
  versionText: {
    textAlign: 'center',
    ...Typography.caption2,
    paddingVertical: Spacing.xl,
  },
});

export default ProfileScreen;
