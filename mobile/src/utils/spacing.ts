// Spacing and Layout System
// Aligned with iOS CampusLink app design language

import { ViewStyle, Platform } from 'react-native';

// Base spacing unit (4px grid)
const BASE_UNIT = 4;

// Spacing scale
export const Spacing = {
  none: 0,
  xs: BASE_UNIT, // 4
  sm: BASE_UNIT * 2, // 8
  md: BASE_UNIT * 3, // 12
  lg: BASE_UNIT * 4, // 16
  xl: BASE_UNIT * 5, // 20
  '2xl': BASE_UNIT * 6, // 24
  '3xl': BASE_UNIT * 8, // 32
  '4xl': BASE_UNIT * 10, // 40
  '5xl': BASE_UNIT * 12, // 48
  '6xl': BASE_UNIT * 16, // 64
} as const;

// Border radius tokens matching iOS
export const BorderRadius = {
  none: 0,
  xs: 4,
  sm: 6,
  md: 8,
  lg: 12,
  xl: 16,
  '2xl': 20,
  '3xl': 24,
  full: 9999,
} as const;

// Shadow presets for cards and overlays
export const Shadows = {
  none: {
    shadowColor: 'transparent',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0,
    shadowRadius: 0,
    elevation: 0,
  } as ViewStyle,

  xs: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  } as ViewStyle,

  sm: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  } as ViewStyle,

  md: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 6,
    elevation: 4,
  } as ViewStyle,

  lg: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.15,
    shadowRadius: 10,
    elevation: 6,
  } as ViewStyle,

  xl: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 10,
  } as ViewStyle,

  // Card shadow - iOS style
  card: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.12,
    shadowRadius: 8,
    elevation: 3,
  } as ViewStyle,

  // Floating element shadow
  floating: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.18,
    shadowRadius: 12,
    elevation: 8,
  } as ViewStyle,

  // Bottom sheet shadow
  sheet: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.1,
    shadowRadius: 12,
    elevation: 16,
  } as ViewStyle,
} as const;

// Layout helpers
export const Layout = {
  // Screen padding
  screenPadding: Spacing.lg,
  
  // Card padding
  cardPadding: Spacing.md,
  cardPaddingLarge: Spacing.lg,
  
  // List item spacing
  listItemSpacing: Spacing.sm,
  listSectionSpacing: Spacing['2xl'],
  
  // Grid gap
  gridGap: Spacing.md,
  
  // Button heights
  buttonHeight: 48,
  buttonHeightSmall: 36,
  buttonHeightLarge: 56,
  
  // Input heights
  inputHeight: 48,
  inputHeightLarge: 56,
  
  // Avatar sizes
  avatarSm: 32,
  avatarMd: 48,
  avatarLg: 64,
  avatarXl: 80,
  avatarXxl: 120,
  
  // Icon sizes
  iconSm: 16,
  iconMd: 20,
  iconLg: 24,
  iconXl: 32,
  
  // Tab bar
  tabBarHeight: Platform.OS === 'ios' ? 84 : 64,
  
  // Header heights
  headerHeight: Platform.OS === 'ios' ? 44 : 56,
  
  // Bottom safe area (approximate)
  bottomSafeArea: Platform.OS === 'ios' ? 34 : 0,
} as const;

// Z-index levels
export const ZIndex = {
  base: 0,
  dropdown: 10,
  sticky: 20,
  fixed: 30,
  modal: 40,
  overlay: 50,
  toast: 60,
} as const;

// Animation durations (in ms)
export const Duration = {
  instant: 0,
  fastest: 100,
  fast: 150,
  normal: 250,
  slow: 350,
  slower: 500,
  slowest: 700,
} as const;

// Animation easing curves
export const Easing = {
  // Standard curves
  linear: 'linear',
  easeIn: 'ease-in',
  easeOut: 'ease-out',
  easeInOut: 'ease-in-out',
  
  // iOS-style spring config for react-native-reanimated
  spring: {
    damping: 15,
    mass: 1,
    stiffness: 150,
  },
  springBouncy: {
    damping: 10,
    mass: 1,
    stiffness: 180,
  },
  springGentle: {
    damping: 20,
    mass: 1,
    stiffness: 120,
  },
} as const;

// Hit slop for touch targets (minimum 44x44 as per iOS HIG)
export const HitSlop = {
  sm: { top: 8, bottom: 8, left: 8, right: 8 },
  md: { top: 12, bottom: 12, left: 12, right: 12 },
  lg: { top: 16, bottom: 16, left: 16, right: 16 },
} as const;

export type SpacingValue = keyof typeof Spacing;
export type BorderRadiusValue = keyof typeof BorderRadius;
export type ShadowValue = keyof typeof Shadows;

export default Spacing;

