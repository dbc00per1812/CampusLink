// Fade In View - Entrance animation component
import React, { useEffect, useRef, memo } from 'react';
import {
  Animated,
  ViewStyle,
  StyleProp,
} from 'react-native';

interface FadeInViewProps {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  delay?: number;
  duration?: number;
  from?: 'bottom' | 'top' | 'left' | 'right' | 'none';
  distance?: number;
}

const FadeInView: React.FC<FadeInViewProps> = memo(({
  children,
  style,
  delay = 0,
  duration = 300,
  from = 'bottom',
  distance = 20,
}) => {
  const opacity = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(
    from === 'bottom' ? distance : from === 'top' ? -distance : 0
  )).current;
  const translateX = useRef(new Animated.Value(
    from === 'right' ? distance : from === 'left' ? -distance : 0
  )).current;

  useEffect(() => {
    const animations: Animated.CompositeAnimation[] = [
      Animated.timing(opacity, {
        toValue: 1,
        duration,
        delay,
        useNativeDriver: true,
      }),
    ];

    if (from === 'bottom' || from === 'top') {
      animations.push(
        Animated.timing(translateY, {
          toValue: 0,
          duration,
          delay,
          useNativeDriver: true,
        })
      );
    }

    if (from === 'left' || from === 'right') {
      animations.push(
        Animated.timing(translateX, {
          toValue: 0,
          duration,
          delay,
          useNativeDriver: true,
        })
      );
    }

    Animated.parallel(animations).start();
  }, [opacity, translateY, translateX, delay, duration, from]);

  const transform: any[] = [];
  if (from === 'bottom' || from === 'top') {
    transform.push({ translateY });
  }
  if (from === 'left' || from === 'right') {
    transform.push({ translateX });
  }

  return (
    <Animated.View
      style={[
        style,
        {
          opacity,
          transform: transform.length > 0 ? transform : undefined,
        },
      ]}
    >
      {children}
    </Animated.View>
  );
});

FadeInView.displayName = 'FadeInView';

export default FadeInView;

