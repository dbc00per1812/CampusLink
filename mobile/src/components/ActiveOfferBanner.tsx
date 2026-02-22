// Active Offer Banner - Alert banner for pending offers
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

interface ActiveOfferBannerProps {
  receivedCount: number;
  sentCount: number;
  onPress: () => void;
}

const ActiveOfferBanner: React.FC<ActiveOfferBannerProps> = memo(({
  receivedCount,
  sentCount,
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

  const totalCount = receivedCount + sentCount;
  if (totalCount === 0) return null;

  // Prioritize received offers (require action)
  let title: string;
  let subtitle: string;

  if (receivedCount > 0 && sentCount > 0) {
    title = 'Pending Offers';
    subtitle = `${receivedCount} to review, ${sentCount} awaiting response`;
  } else if (receivedCount > 0) {
    title = receivedCount === 1 ? 'Offer Received' : 'Offers Received';
    subtitle = receivedCount === 1
      ? 'You have 1 offer to review'
      : `You have ${receivedCount} offers to review`;
  } else {
    title = sentCount === 1 ? 'Offer Sent' : 'Offers Sent';
    subtitle = sentCount === 1
      ? '1 offer awaiting response'
      : `${sentCount} offers awaiting response`;
  }

  // Use purple/violet color for offers (distinct from orders which use red)
  const accentColor = '#8B5CF6'; // Purple
  const bgColor = '#EDE9FE'; // Light purple

  return (
    <Pressable
      style={({ pressed }) => [
        styles.container,
        {
          backgroundColor: bgColor,
          borderColor: `${accentColor}4D`, // 30% opacity
          transform: [{ scale: pressed ? 0.98 : 1 }],
        },
      ]}
      onPress={handlePress}
    >
      {/* Pulsing purple indicator */}
      <Animated.View
        style={[
          styles.indicator,
          {
            backgroundColor: accentColor,
            opacity: pulseAnim,
          },
        ]}
      />

      {/* Content */}
      <View style={styles.content}>
        <View style={styles.titleRow}>
          <Ionicons name="pricetag" size={16} color={accentColor} style={styles.icon} />
          <Text style={[styles.title, { color: colors.textPrimary }]}>
            {title}
          </Text>
        </View>
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
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  icon: {
    marginRight: 6,
  },
  title: {
    ...Typography.subheadlineBold,
  },
  subtitle: {
    ...Typography.caption1,
    marginTop: 2,
  },
});

ActiveOfferBanner.displayName = 'ActiveOfferBanner';

export default ActiveOfferBanner;
