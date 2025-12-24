// UnifiedHeader - Consistent header component across the app
import React from 'react';
import { View, Text, StyleSheet, Pressable, Platform } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing } from '../utils/spacing';
import Colors from '../utils/colors';

interface UnifiedHeaderProps {
  title: string;
  subtitle?: string;
  showBackButton?: boolean;
  showMenu?: boolean;
  onBackPress?: () => void;
  onMenuPress?: () => void;
  leftComponent?: React.ReactNode;
  rightComponent?: React.ReactNode;
  centerComponent?: React.ReactNode;
}

export const UnifiedHeader: React.FC<UnifiedHeaderProps> = ({
  title,
  subtitle,
  showBackButton = true,
  showMenu = false,
  onBackPress,
  onMenuPress,
  leftComponent,
  rightComponent,
  centerComponent,
}) => {
  const navigation = useNavigation();
  const colors = useColors();

  const handleBackPress = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    if (onBackPress) {
      onBackPress();
    } else if (navigation.canGoBack()) {
      navigation.goBack();
    }
  };

  const handleMenuPress = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    if (onMenuPress) {
      onMenuPress();
    }
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Left Side - Back Button or Custom Component */}
      <View style={styles.leftContainer}>
        {leftComponent ? (
          leftComponent
        ) : showBackButton ? (
          <Pressable
            onPress={handleBackPress}
            style={({ pressed }) => [
              styles.backButton,
              { opacity: pressed ? 0.5 : 1 },
            ]}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons name="chevron-back" size={28} color={Colors.primary} />
          </Pressable>
        ) : (
          <View style={styles.backButton} />
        )}
      </View>

      {/* Center - Title/Custom Component */}
      <View style={styles.centerContainer}>
        {centerComponent ? (
          centerComponent
        ) : (
          <View style={styles.titleContainer}>
            <Text
              style={[styles.title, { color: colors.textPrimary }]}
              numberOfLines={1}
            >
              {title}
            </Text>
            {subtitle && (
              <Text
                style={[styles.subtitle, { color: colors.textSecondary }]}
                numberOfLines={1}
              >
                {subtitle}
              </Text>
            )}
          </View>
        )}
      </View>

      {/* Right Side - Menu or Custom Component */}
      <View style={styles.rightContainer}>
        {rightComponent ? (
          rightComponent
        ) : showMenu ? (
          <Pressable
            onPress={handleMenuPress}
            style={({ pressed }) => [
              styles.menuButton,
              { opacity: pressed ? 0.5 : 1 },
            ]}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons name="ellipsis-horizontal" size={24} color={colors.textPrimary} />
          </Pressable>
        ) : (
          <View style={styles.menuButton} />
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    height: 56,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.border,
  },
  leftContainer: {
    flex: 0,
    minWidth: 44,
    alignItems: 'flex-start',
    justifyContent: 'center',
  },
  centerContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.sm,
  },
  rightContainer: {
    flex: 0,
    minWidth: 44,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  backButton: {
    width: 44,
    height: 44,
    alignItems: 'flex-start',
    justifyContent: 'center',
  },
  menuButton: {
    width: 44,
    height: 44,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  titleContainer: {
    alignItems: 'center',
    maxWidth: '100%',
  },
  title: {
    ...Typography.headline,
    fontWeight: '600',
  },
  subtitle: {
    ...Typography.caption1,
    marginTop: 2,
  },
});

export default UnifiedHeader;

