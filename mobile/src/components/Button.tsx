// Button Component - Enhanced with haptic feedback and press animations
import React, { useCallback } from 'react';
import {
  TouchableOpacity,
  Text,
  StyleSheet,
  ActivityIndicator,
  ViewStyle,
  TextStyle,
  Platform,
  Pressable,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius, Shadows, Layout } from '../utils/spacing';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger' | 'success';
export type ButtonSize = 'small' | 'medium' | 'large';

interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: ButtonVariant;
  size?: ButtonSize;
  icon?: keyof typeof Ionicons.glyphMap;
  iconPosition?: 'left' | 'right';
  loading?: boolean;
  disabled?: boolean;
  fullWidth?: boolean;
  haptic?: boolean;
  style?: ViewStyle;
  textStyle?: TextStyle;
}

const Button: React.FC<ButtonProps> = ({
  title,
  onPress,
  variant = 'primary',
  size = 'medium',
  icon,
  iconPosition = 'left',
  loading = false,
  disabled = false,
  fullWidth = true,
  haptic = true,
  style,
  textStyle,
}) => {
  const colors = useColors();
  const isDisabled = disabled || loading;

  const handlePress = useCallback(() => {
    if (haptic && Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    onPress();
  }, [haptic, onPress]);

  const getBackgroundColor = (): string => {
    if (isDisabled) return colors.surfaceSecondary;
    switch (variant) {
      case 'primary':
        return colors.primary;
      case 'secondary':
        return colors.surfaceSecondary;
      case 'outline':
      case 'ghost':
        return 'transparent';
      case 'danger':
        return colors.error;
      case 'success':
        return colors.success;
      default:
        return colors.primary;
    }
  };

  const getPressedBackgroundColor = (): string => {
    if (isDisabled) return colors.surfaceSecondary;
    switch (variant) {
      case 'primary':
        return colors.primaryDark;
      case 'secondary':
        return colors.surfaceTertiary;
      case 'outline':
      case 'ghost':
        return colors.primaryMuted;
      case 'danger':
        return '#CC2F26';
      case 'success':
        return '#2BA34A';
      default:
        return colors.primaryDark;
    }
  };

  const getTextColor = (): string => {
    if (isDisabled) return colors.textTertiary;
    switch (variant) {
      case 'primary':
      case 'danger':
      case 'success':
        return colors.textInverse;
      case 'secondary':
        return colors.textPrimary;
      case 'outline':
      case 'ghost':
        return colors.primary;
      default:
        return colors.textInverse;
    }
  };

  const getBorderColor = (): string => {
    if (variant === 'outline') {
      return isDisabled ? colors.border : colors.primary;
    }
    return 'transparent';
  };

  const getHeight = (): number => {
    switch (size) {
      case 'small':
        return Layout.buttonHeightSmall;
      case 'medium':
        return Layout.buttonHeight;
      case 'large':
        return Layout.buttonHeightLarge;
      default:
        return Layout.buttonHeight;
    }
  };

  const getPadding = (): number => {
    switch (size) {
      case 'small':
        return Spacing.md;
      case 'medium':
        return Spacing.lg;
      case 'large':
        return Spacing.xl;
      default:
        return Spacing.lg;
    }
  };

  const getIconSize = (): number => {
    switch (size) {
      case 'small':
        return Layout.iconSm;
      case 'medium':
        return Layout.iconMd;
      case 'large':
        return Layout.iconLg;
      default:
        return Layout.iconMd;
    }
  };

  const getTypography = () => {
    switch (size) {
      case 'small':
        return Typography.buttonSmall;
      case 'medium':
      case 'large':
        return Typography.button;
      default:
        return Typography.button;
    }
  };

  const textColor = getTextColor();

  return (
    <Pressable
      style={({ pressed }) => [
        styles.button,
        {
          height: getHeight(),
          paddingHorizontal: getPadding(),
          backgroundColor: pressed ? getPressedBackgroundColor() : getBackgroundColor(),
          borderColor: getBorderColor(),
          borderWidth: variant === 'outline' ? 2 : 0,
          transform: [{ scale: pressed && !isDisabled ? 0.98 : 1 }],
        },
        variant !== 'ghost' && variant !== 'outline' && Shadows.sm,
        fullWidth && styles.fullWidth,
        isDisabled && styles.disabled,
        style,
      ]}
      onPress={handlePress}
      disabled={isDisabled}
    >
      {loading ? (
        <ActivityIndicator color={textColor} size="small" />
      ) : (
        <View style={styles.content}>
          {icon && iconPosition === 'left' && (
            <Ionicons
              name={icon}
              size={getIconSize()}
              color={textColor}
              style={styles.iconLeft}
            />
          )}
          <Text
            style={[
              getTypography(),
              { color: textColor },
              textStyle,
            ]}
          >
            {title}
          </Text>
          {icon && iconPosition === 'right' && (
            <Ionicons
              name={icon}
              size={getIconSize()}
              color={textColor}
              style={styles.iconRight}
            />
          )}
        </View>
      )}
    </Pressable>
  );
};

const styles = StyleSheet.create({
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: BorderRadius.lg,
  },
  fullWidth: {
    width: '100%',
  },
  disabled: {
    opacity: 0.6,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconLeft: {
    marginRight: Spacing.sm,
  },
  iconRight: {
    marginLeft: Spacing.sm,
  },
});

export default Button;
