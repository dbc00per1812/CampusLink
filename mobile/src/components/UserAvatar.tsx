// UserAvatar Component - Profile picture with initials fallback
import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { User } from '../types';

interface UserAvatarProps {
  user: User | null;
  size?: number;
  showBorder?: boolean;
}

// Color palette for avatar backgrounds
const AVATAR_COLORS = [
  '#4285F4', // Blue
  '#66B566', // Green
  '#F57D49', // Orange
  '#9C59B6', // Purple
  '#E84C65', // Red
  '#00ABC2', // Cyan
  '#F5C230', // Yellow
  '#785447', // Brown
  '#E81E64', // Pink
  '#3399DB', // Light Blue
  '#8FB043', // Lime
  '#D95E02', // Deep Orange
];

const UserAvatar: React.FC<UserAvatarProps> = ({
  user,
  size = 40,
  showBorder = false,
}) => {
  const getInitials = (): string => {
    if (!user) return '?';
    const name = user.name || user.email || '?';
    const firstChar = name.charAt(0);
    return firstChar.toUpperCase();
  };

  const getAvatarColor = (): string => {
    if (!user) return AVATAR_COLORS[0];
    // Use user ID to generate consistent color
    let hash = 0;
    const id = user.id;
    for (let i = 0; i < id.length; i++) {
      hash = id.charCodeAt(i) + ((hash << 5) - hash);
    }
    const index = Math.abs(hash) % AVATAR_COLORS.length;
    return AVATAR_COLORS[index];
  };

  const hasProfilePic = user?.profile_pic && user.profile_pic.length > 0;

  return (
    <View
      style={[
        styles.container,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: hasProfilePic ? Colors.surfaceSecondary : getAvatarColor(),
        },
        showBorder && styles.border,
      ]}
    >
      {hasProfilePic ? (
        <Image
          source={{ uri: user!.profile_pic! }}
          style={[styles.image, { width: size, height: size, borderRadius: size / 2 }]}
          resizeMode="cover"
        />
      ) : (
        <Text
          style={[
            styles.initials,
            { fontSize: size * 0.45 },
          ]}
        >
          {getInitials()}
        </Text>
      )}
    </View>
  );
};

// Import Colors for fallback
import Colors from '../utils/colors';

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  border: {
    borderWidth: 2,
    borderColor: Colors.background,
  },
  image: {
    width: '100%',
    height: '100%',
  },
  initials: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
});

export default UserAvatar;

