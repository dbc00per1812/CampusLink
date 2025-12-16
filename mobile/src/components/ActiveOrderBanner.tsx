// Active Order Banner - Alert banner for pending orders
import React, { memo, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Animated,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius } from '../utils/spacing';

interface ActiveOrderBannerProps {
  orderCount: number;
  onPress: () => void;
}

const ActiveOrderBanner: React.FC<ActiveOrderBannerProps> = memo(({
  orderCount,
  onPress,
}) => {
  const colors = useColors();
  const pulseAnim = useRef(new Animated.Value(1)).current;

  // Pulsing animation for the indicator dot
  useEffect(() => {
    const pulse = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 0.4,
          duration: 800,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 800,
          useNativeDriver: true,
        }),
      ])
    );
    pulse.start();
    return () => pulse.stop();
  }, [pulseAnim]);

  const handlePress = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    onPress();
  };

  if (orderCount === 0) return null;

  const title = orderCount === 1 ? 'Active Order' : 'Active Orders';
  const subtitle = orderCount === 1
    ? 'You have 1 order requiring action'
    : `Tap to view ${orderCount} orders`;

  return (
    <Pressable
      style={({ pressed }) => [
        styles.container,
        {
          backgroundColor: colors.errorLight,
          borderColor: `${colors.error}4D`, // 30% opacity
          transform: [{ scale: pressed ? 0.98 : 1 }],
        },
      ]}
      onPress={handlePress}
    >
      {/* Pulsing red indicator */}
      <Animated.View
        style={[
          styles.indicator,
          {
            backgroundColor: colors.error,
            opacity: pulseAnim,
          },
        ]}
      />

      {/* Content */}
      <View style={styles.content}>
        <Text style={[styles.title, { color: colors.textPrimary }]}>
          {title}
        </Text>
        <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
          {subtitle}
        </Text>
      </View>

      {/* Chevron */}
      <Ionicons
        name="chevron-forward"
        size={18}
        color={colors.textSecondary}
      />
    </Pressable>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: Spacing.lg,
    marginTop: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
  },
  indicator: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: Spacing.md,
  },
  content: {
    flex: 1,
  },
  title: {
    ...Typography.subheadlineBold,
  },
  subtitle: {
    ...Typography.caption1,
    marginTop: 2,
  },
});

ActiveOrderBanner.displayName = 'ActiveOrderBanner';

export default ActiveOrderBanner;

