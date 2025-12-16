// Staggered List - Animated list with staggered item entrance
import React, { memo } from 'react';
import {
  View,
  StyleSheet,
  ViewStyle,
  StyleProp,
} from 'react-native';
import FadeInView from './FadeInView';

interface StaggeredListProps<T> {
  data: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T, index: number) => string;
  staggerDelay?: number;
  itemDuration?: number;
  from?: 'bottom' | 'top' | 'left' | 'right' | 'none';
  distance?: number;
  style?: StyleProp<ViewStyle>;
  itemStyle?: StyleProp<ViewStyle>;
}

function StaggeredListInner<T>({
  data,
  renderItem,
  keyExtractor,
  staggerDelay = 50,
  itemDuration = 300,
  from = 'bottom',
  distance = 20,
  style,
  itemStyle,
}: StaggeredListProps<T>) {
  return (
    <View style={style}>
      {data.map((item, index) => (
        <FadeInView
          key={keyExtractor(item, index)}
          delay={index * staggerDelay}
          duration={itemDuration}
          from={from}
          distance={distance}
          style={itemStyle}
        >
          {renderItem(item, index)}
        </FadeInView>
      ))}
    </View>
  );
}

// Memoized version
const StaggeredList = memo(StaggeredListInner) as typeof StaggeredListInner;

export default StaggeredList;

