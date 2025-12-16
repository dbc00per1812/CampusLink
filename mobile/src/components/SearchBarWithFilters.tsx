// Search Bar with Filters - iOS-style search input
import React, { memo, useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  Pressable,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius, Layout } from '../utils/spacing';

interface SearchBarWithFiltersProps {
  value: string;
  onChangeText: (text: string) => void;
  onSubmit?: () => void;
  onFilterPress?: () => void;
  placeholder?: string;
  showFilterButton?: boolean;
  autoFocus?: boolean;
  onFocusChange?: (focused: boolean) => void;
}

const SearchBarWithFilters: React.FC<SearchBarWithFiltersProps> = memo(({
  value,
  onChangeText,
  onSubmit,
  onFilterPress,
  placeholder = 'Search listings...',
  showFilterButton = true,
  autoFocus = false,
  onFocusChange,
}) => {
  const colors = useColors();
  const inputRef = useRef<TextInput>(null);
  const [isFocused, setIsFocused] = useState(false);

  const handleFocus = useCallback(() => {
    setIsFocused(true);
    onFocusChange?.(true);
  }, [onFocusChange]);

  const handleBlur = useCallback(() => {
    setIsFocused(false);
    onFocusChange?.(false);
  }, [onFocusChange]);

  const handleClear = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    onChangeText('');
    inputRef.current?.focus();
  }, [onChangeText]);

  const handleFilterPress = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    onFilterPress?.();
  }, [onFilterPress]);

  return (
    <View style={styles.container}>
      <View
        style={[
          styles.searchContainer,
          {
            backgroundColor: colors.surfaceSecondary,
            borderColor: isFocused ? colors.primary : 'transparent',
          },
        ]}
      >
        <Ionicons
          name="search"
          size={Layout.iconMd}
          color={colors.textTertiary}
          style={styles.searchIcon}
        />
        <TextInput
          ref={inputRef}
          style={[
            styles.input,
            { color: colors.textPrimary },
          ]}
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={colors.textTertiary}
          onFocus={handleFocus}
          onBlur={handleBlur}
          onSubmitEditing={onSubmit}
          returnKeyType="search"
          autoFocus={autoFocus}
          autoCapitalize="none"
          autoCorrect={false}
        />
        {value.length > 0 && (
          <Pressable
            onPress={handleClear}
            style={({ pressed }) => [
              styles.clearButton,
              { opacity: pressed ? 0.5 : 1 },
            ]}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <View style={[styles.clearIcon, { backgroundColor: colors.textTertiary }]}>
              <Ionicons name="close" size={12} color={colors.surface} />
            </View>
          </Pressable>
        )}
      </View>

      {showFilterButton && (
        <Pressable
          onPress={handleFilterPress}
          style={({ pressed }) => [
            styles.filterButton,
            {
              backgroundColor: colors.primaryMuted,
              transform: [{ scale: pressed ? 0.95 : 1 }],
            },
          ]}
        >
          <Ionicons name="options-outline" size={Layout.iconMd} color={colors.primary} />
        </Pressable>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  searchContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    height: Layout.inputHeight,
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.md,
    borderWidth: 2,
  },
  searchIcon: {
    marginRight: Spacing.sm,
  },
  input: {
    flex: 1,
    ...Typography.body,
    paddingVertical: 0,
  },
  clearButton: {
    padding: Spacing.xs,
  },
  clearIcon: {
    width: 18,
    height: 18,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
  },
  filterButton: {
    width: Layout.inputHeight,
    height: Layout.inputHeight,
    borderRadius: BorderRadius.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
});

SearchBarWithFilters.displayName = 'SearchBarWithFilters';

export default SearchBarWithFilters;

