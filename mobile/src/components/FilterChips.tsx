// Filter Chips Component - Horizontal scrollable chip row
import React, { memo, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius } from '../utils/spacing';

export interface FilterChip {
  id: string;
  label: string;
  icon?: keyof typeof Ionicons.glyphMap;
}

interface FilterChipsProps {
  chips: FilterChip[];
  selectedId: string;
  onSelect: (id: string) => void;
  scrollEnabled?: boolean;
}

const FilterChips: React.FC<FilterChipsProps> = memo(({
  chips,
  selectedId,
  onSelect,
  scrollEnabled = true,
}) => {
  const colors = useColors();

  const handlePress = useCallback((id: string) => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    onSelect(id);
  }, [onSelect]);

  const renderChip = (chip: FilterChip) => {
    const isSelected = chip.id === selectedId;

    return (
      <Pressable
        key={chip.id}
        style={({ pressed }) => [
          styles.chip,
          {
            backgroundColor: isSelected ? colors.primary : colors.primaryMuted,
            transform: [{ scale: pressed ? 0.95 : 1 }],
          },
        ]}
        onPress={() => handlePress(chip.id)}
      >
        {chip.icon && (
          <Ionicons
            name={chip.icon}
            size={14}
            color={isSelected ? colors.textInverse : colors.primary}
            style={styles.chipIcon}
          />
        )}
        <Text
          style={[
            styles.chipText,
            {
              color: isSelected ? colors.textInverse : colors.primary,
              fontWeight: isSelected ? '600' : '400',
            },
          ]}
        >
          {chip.label}
        </Text>
      </Pressable>
    );
  };

  if (scrollEnabled) {
    return (
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
        style={styles.scrollView}
      >
        {chips.map(renderChip)}
      </ScrollView>
    );
  }

  return (
    <View style={styles.container}>
      {chips.map(renderChip)}
    </View>
  );
});

// Preset filter chips for home screen
export const HOME_FILTER_CHIPS: FilterChip[] = [
  { id: 'forYou', label: 'For you', icon: 'star' },
  { id: 'all', label: 'All' },
  { id: 'selling', label: 'Selling' },
  { id: 'wanted', label: 'Wanted' },
  { id: 'more', label: 'More', icon: 'grid' },
];

// Category chips
export const CATEGORY_CHIPS: FilterChip[] = [
  { id: 'all', label: 'All' },
  { id: 'electronics', label: 'Electronics' },
  { id: 'clothing', label: 'Clothing' },
  { id: 'books', label: 'Books' },
  { id: 'furniture', label: 'Furniture' },
  { id: 'tickets', label: 'Tickets' },
  { id: 'services', label: 'Services' },
  { id: 'other', label: 'Other' },
];

const styles = StyleSheet.create({
  scrollView: {
    flexGrow: 0,
  },
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
    gap: Spacing.sm,
    flexDirection: 'row',
  },
  container: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
  },
  chipIcon: {
    marginRight: Spacing.xs,
  },
  chipText: {
    ...Typography.footnote,
  },
});

FilterChips.displayName = 'FilterChips';

export default FilterChips;

