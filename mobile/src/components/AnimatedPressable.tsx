// Animated Pressable - Scale animation on press
import React, { useCallback } from 'react';
import {
  Pressable,
  PressableProps,
  ViewStyle,
  StyleProp,
  Platform,
  Animated,
} from 'react-native';
import * as Haptics from 'expo-haptics';

interface AnimatedPressableProps extends Omit<PressableProps, 'style'> {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  scaleValue?: number;
  haptic?: boolean;
  hapticStyle?: 'light' | 'medium' | 'heavy';
}

const AnimatedPressable: React.FC<AnimatedPressableProps> = ({
  children,
  style,
  scaleValue = 0.97,
  haptic = true,
  hapticStyle = 'light',
  onPressIn,
  onPressOut,
  onPress,
  disabled,
  ...props
}) => {
  const scaleAnim = React.useRef(new Animated.Value(1)).current;

  const handlePressIn = useCallback((e: any) => {
    Animated.spring(scaleAnim, {
      toValue: scaleValue,
      useNativeDriver: true,
      speed: 50,
      bounciness: 4,
    }).start();
    onPressIn?.(e);
  }, [scaleAnim, scaleValue, onPressIn]);

  const handlePressOut = useCallback((e: any) => {
    Animated.spring(scaleAnim, {
      toValue: 1,
      useNativeDriver: true,
      speed: 50,
      bounciness: 4,
    }).start();
    onPressOut?.(e);
  }, [scaleAnim, onPressOut]);

  const handlePress = useCallback((e: any) => {
    if (haptic && Platform.OS !== 'web') {
      const impactStyle = hapticStyle === 'light'
        ? Haptics.ImpactFeedbackStyle.Light
        : hapticStyle === 'medium'
        ? Haptics.ImpactFeedbackStyle.Medium
        : Haptics.ImpactFeedbackStyle.Heavy;
      Haptics.impactAsync(impactStyle);
    }
    onPress?.(e);
  }, [haptic, hapticStyle, onPress]);

  return (
    <Pressable
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      onPress={handlePress}
      disabled={disabled}
      {...props}
    >
      <Animated.View
        style={[
          style,
          {
            transform: [{ scale: scaleAnim }],
            opacity: disabled ? 0.5 : 1,
          },
        ]}
      >
        {children}
      </Animated.View>
    </Pressable>
  );
};

export default AnimatedPressable;

