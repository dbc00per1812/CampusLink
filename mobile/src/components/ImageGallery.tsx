// Image Gallery Component - Full-featured image viewer
// OPTIMIZED FOR LIGHTNING-FAST PERFORMANCE
import React, { memo, useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Dimensions,
  Pressable,
  Modal,
  StatusBar,
  Platform,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius } from '../utils/spacing';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

interface ImageGalleryProps {
  images: string[];
  initialIndex?: number;
  onImagePress?: (index: number) => void;
  showThumbnails?: boolean;
  aspectRatio?: number;
}

const ImageGallery: React.FC<ImageGalleryProps> = memo(({
  images,
  initialIndex = 0,
  onImagePress,
  showThumbnails = true,
  aspectRatio = 1,
}) => {
  const colors = useColors();
  const scrollRef = useRef<ScrollView>(null);
  const [activeIndex, setActiveIndex] = useState(initialIndex);
  const [isFullScreen, setIsFullScreen] = useState(false);

  const handleScroll = useCallback((event: any) => {
    const contentOffset = event.nativeEvent.contentOffset.x;
    const index = Math.round(contentOffset / SCREEN_WIDTH);
    if (index !== activeIndex && index >= 0 && index < images.length) {
      setActiveIndex(index);
    }
  }, [activeIndex, images.length]);

  const handleImagePress = useCallback((index: number) => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    if (onImagePress) {
      onImagePress(index);
    } else {
      setIsFullScreen(true);
    }
  }, [onImagePress]);

  const handleThumbnailPress = useCallback((index: number) => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    setActiveIndex(index);
    scrollRef.current?.scrollTo({ x: index * SCREEN_WIDTH, animated: true });
  }, []);

  const closeFullScreen = useCallback(() => {
    setIsFullScreen(false);
  }, []);

  if (images.length === 0) {
    return (
      <View
        style={[
          styles.placeholder,
          {
            backgroundColor: colors.surfaceSecondary,
            aspectRatio,
          },
        ]}
      >
        <Ionicons name="image-outline" size={64} color={colors.textTertiary} />
        <Text style={[styles.placeholderText, { color: colors.textTertiary }]}>
          No photos
        </Text>
      </View>
    );
  }

  return (
    <View>
      {/* Main Gallery */}
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={handleScroll}
        scrollEventThrottle={16}
      >
        {images.map((uri, index) => (
          <Pressable
            key={`image-${index}`}
            onPress={() => handleImagePress(index)}
          >
            <Image
              source={{ uri }}
              style={[styles.image, { aspectRatio }]}
              contentFit="cover"
              transition={200}
              cachePolicy="memory-disk"
              priority={index === 0 ? 'high' : 'normal'}
              placeholder={{ blurhash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4' }}
            />
          </Pressable>
        ))}
      </ScrollView>

      {/* Page Indicators */}
      {images.length > 1 && (
        <View style={styles.indicators}>
          {images.map((_, index) => (
            <View
              key={`indicator-${index}`}
              style={[
                styles.indicator,
                {
                  backgroundColor: index === activeIndex
                    ? colors.textInverse
                    : `${colors.textInverse}80`,
                },
              ]}
            />
          ))}
        </View>
      )}

      {/* Image Counter */}
      {images.length > 1 && (
        <View style={[styles.counter, { backgroundColor: colors.overlay }]}>
          <Text style={styles.counterText}>
            {activeIndex + 1} / {images.length}
          </Text>
        </View>
      )}

      {/* Thumbnails */}
      {showThumbnails && images.length > 1 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.thumbnailContainer}
        >
          {images.map((uri, index) => (
            <Pressable
              key={`thumb-${index}`}
              onPress={() => handleThumbnailPress(index)}
            >
              <Image
                source={{ uri }}
                style={[
                  styles.thumbnail,
                  {
                    borderColor: index === activeIndex
                      ? colors.primary
                      : 'transparent',
                  },
                ]}
                contentFit="cover"
                cachePolicy="memory-disk"
                transition={100}
              />
            </Pressable>
          ))}
        </ScrollView>
      )}

      {/* Full Screen Modal */}
      <Modal
        visible={isFullScreen}
        transparent
        animationType="fade"
        onRequestClose={closeFullScreen}
      >
        <StatusBar hidden />
        <View style={styles.fullScreenContainer}>
          {/* Close Button */}
          <Pressable
            style={styles.closeButton}
            onPress={closeFullScreen}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons name="close-circle" size={32} color={colors.textInverse} />
          </Pressable>

          {/* Full Screen Image */}
          <ScrollView
            horizontal
            pagingEnabled
            showsHorizontalScrollIndicator={false}
            contentOffset={{ x: activeIndex * SCREEN_WIDTH, y: 0 }}
            onMomentumScrollEnd={handleScroll}
          >
            {images.map((uri, index) => (
              <View key={`full-${index}`} style={styles.fullScreenImageContainer}>
                <Image
                  source={{ uri }}
                  style={styles.fullScreenImage}
                  contentFit="contain"
                  cachePolicy="memory-disk"
                  transition={150}
                  priority="high"
                />
              </View>
            ))}
          </ScrollView>

          {/* Full Screen Counter */}
          <View style={[styles.fullScreenCounter, { backgroundColor: colors.overlay }]}>
            <Text style={styles.counterText}>
              {activeIndex + 1} / {images.length}
            </Text>
          </View>
        </View>
      </Modal>
    </View>
  );
});

const styles = StyleSheet.create({
  placeholder: {
    width: SCREEN_WIDTH,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  placeholderText: {
    ...Typography.headline,
  },
  image: {
    width: SCREEN_WIDTH,
  },
  indicators: {
    position: 'absolute',
    bottom: Spacing.lg,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
  },
  indicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  counter: {
    position: 'absolute',
    bottom: Spacing.md,
    right: Spacing.md,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.lg,
  },
  counterText: {
    ...Typography.caption1,
    color: '#FFFFFF',
  },
  thumbnailContainer: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    gap: Spacing.sm,
    flexDirection: 'row',
  },
  thumbnail: {
    width: 60,
    height: 60,
    borderRadius: BorderRadius.md,
    borderWidth: 2,
  },
  fullScreenContainer: {
    flex: 1,
    backgroundColor: '#000000',
  },
  closeButton: {
    position: 'absolute',
    top: Platform.OS === 'ios' ? 50 : 20,
    right: 20,
    zIndex: 10,
  },
  fullScreenImageContainer: {
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
    justifyContent: 'center',
    alignItems: 'center',
  },
  fullScreenImage: {
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT * 0.8,
  },
  fullScreenCounter: {
    position: 'absolute',
    bottom: 50,
    right: 20,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.lg,
  },
});

ImageGallery.displayName = 'ImageGallery';

export default ImageGallery;

