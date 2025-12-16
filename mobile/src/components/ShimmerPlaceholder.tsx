// Shimmer Placeholder - Animated loading effect
import React, { useEffect, useRef, memo } from 'react';
import {
  View,
  StyleSheet,
  Animated,
  ViewStyle,
  Dimensions,
  StyleProp,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useColors } from '../context/ThemeContext';
import { BorderRadius } from '../utils/spacing';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface ShimmerPlaceholderProps {
  width?: number | string;
  height?: number;
  borderRadius?: number;
  style?: StyleProp<ViewStyle>;
  isLoading?: boolean;
  children?: React.ReactNode;
}

const ShimmerPlaceholder: React.FC<ShimmerPlaceholderProps> = memo(({
  width = '100%',
  height = 20,
  borderRadius = BorderRadius.sm,
  style,
  isLoading = true,
  children,
}) => {
  const colors = useColors();
  const translateX = useRef(new Animated.Value(-SCREEN_WIDTH)).current;

  useEffect(() => {
    if (!isLoading) return;

    const shimmerAnimation = Animated.loop(
      Animated.timing(translateX, {
        toValue: SCREEN_WIDTH,
        duration: 1500,
        useNativeDriver: true,
      })
    );
    
    shimmerAnimation.start();
    
    return () => {
      shimmerAnimation.stop();
    };
  }, [isLoading, translateX]);

  if (!isLoading && children) {
    return <>{children}</>;
  }

  return (
    <View
      style={[
        styles.container,
        {
          width: width as any,
          height,
          borderRadius,
          backgroundColor: colors.skeletonBase,
        },
        style,
      ]}
    >
      <Animated.View
        style={[
          styles.shimmer,
          {
            transform: [{ translateX }],
          },
        ]}
      >
        <LinearGradient
          colors={[
            'transparent',
            `${colors.skeletonHighlight}80`,
            'transparent',
          ]}
          start={{ x: 0, y: 0.5 }}
          end={{ x: 1, y: 0.5 }}
          style={styles.gradient}
        />
      </Animated.View>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
  },
  shimmer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    width: SCREEN_WIDTH,
  },
  gradient: {
    flex: 1,
    width: '100%',
  },
});

ShimmerPlaceholder.displayName = 'ShimmerPlaceholder';

export default ShimmerPlaceholder;

