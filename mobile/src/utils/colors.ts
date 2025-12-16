// App Color Theme - Enhanced Design System
// Aligned with iOS CampusLink app design language

// Theme color from iOS app - the branded blue
const THEME_COLOR = '#007AFF';

export const Colors = {
  // Primary brand colors (matching iOS ThemeColor)
  primary: THEME_COLOR,
  primaryDark: '#0056B3',
  primaryLight: '#4DA3FF',
  primaryMuted: `${THEME_COLOR}1A`, // 10% opacity

  // Accent colors
  accent: '#5856D6', // Purple accent
  accentLight: '#7A79E0',
  accentBlue: 'rgba(0, 122, 255, 0.05)', // Light blue background for info cards
  accentGreen: 'rgba(52, 199, 89, 0.05)', // Light green background for success cards

  // Status colors
  success: '#34C759', // iOS green
  successLight: '#34C75920',
  warning: '#FF9500', // iOS orange
  warningLight: '#FF950020',
  error: '#FF3B30', // iOS red
  errorLight: '#FF3B3020',
  info: THEME_COLOR,
  infoLight: `${THEME_COLOR}20`,

  // Neutral colors - Light mode
  background: '#FFFFFF',
  backgroundSecondary: '#F2F2F7', // iOS system gray 6
  surface: '#FFFFFF',
  surfaceSecondary: '#F2F2F7',
  surfaceTertiary: '#E5E5EA', // iOS system gray 5

  // Text colors - Light mode
  textPrimary: '#000000',
  textSecondary: '#3C3C4399', // 60% opacity
  textTertiary: '#3C3C434D', // 30% opacity
  textInverse: '#FFFFFF',
  textLink: THEME_COLOR,

  // Border colors
  border: '#3C3C4333', // iOS separator color
  borderLight: '#3C3C431A',
  borderFocus: THEME_COLOR,

  // Card and overlay
  cardBackground: '#FFFFFF',
  cardShadow: '#00000019',
  overlay: '#00000066',
  overlayLight: '#00000033',

  // Badge colors
  badgeBlue: THEME_COLOR,
  badgeGreen: '#34C759',
  badgeOrange: '#FF9500',
  badgeRed: '#FF3B30',
  badgePurple: '#5856D6',
  badgeGray: '#8E8E93',

  // Order status colors
  orderPlaced: THEME_COLOR,
  orderConfirmed: '#FF9500',
  orderInProgress: '#FFCC00',
  orderCompleted: '#34C759',
  orderDisputed: '#FF3B30',
  orderCancelled: '#8E8E93',
  orderRefunded: '#5856D6',

  // Trust level colors
  trustTrusted: '#FFD700',
  trustReliable: '#C0C0C0',
  trustNew: '#CD7F32',
  trustCaution: '#FF9500',
  trustRisk: '#FF3B30',

  // Payout status colors
  payoutPending: '#FF9500',
  payoutProcessing: '#FF9500',
  payoutInTransit: '#FF9500',
  payoutCompleted: '#34C759',
  payoutPaid: '#34C759',
  payoutFailed: '#FF3B30',
  payoutCancelled: '#FF3B30',

  // Tab bar
  tabActive: THEME_COLOR,
  tabInactive: '#8E8E93',

  // Skeleton loading
  skeletonBase: '#E5E5EA',
  skeletonHighlight: '#F2F2F7',

  // Shadows
  shadow: '#000000',
  shadowLight: '#00000010',

  // Gradients (as color stops)
  gradientPrimary: [THEME_COLOR, '#0056B3'] as const,
  gradientSuccess: ['#34C759', '#30B350'] as const,
  gradientWarm: ['#FF9500', '#FF6B00'] as const,
  gradientCool: ['#5856D6', '#007AFF'] as const,
  gradientMesh: ['#F2F2F7', '#E5E5EA', '#F2F2F7'] as const,
} as const;

// Dark mode colors
export const DarkColors: typeof Colors = {
  ...Colors,
  
  // Backgrounds - Dark mode
  background: '#000000',
  backgroundSecondary: '#1C1C1E',
  surface: '#1C1C1E',
  surfaceSecondary: '#2C2C2E',
  surfaceTertiary: '#3A3A3C',

  // Text colors - Dark mode
  textPrimary: '#FFFFFF',
  textSecondary: '#EBEBF599',
  textTertiary: '#EBEBF54D',
  textInverse: '#000000',

  // Border colors - Dark mode
  border: '#54545899',
  borderLight: '#5454581A',

  // Card - Dark mode
  cardBackground: '#1C1C1E',
  cardShadow: '#00000066',

  // Skeleton - Dark mode
  skeletonBase: '#2C2C2E',
  skeletonHighlight: '#3A3A3C',

  // Gradients - Dark mode
  gradientMesh: ['#1C1C1E', '#2C2C2E', '#1C1C1E'] as const,
};

// Helper to get color with opacity
export const withOpacity = (color: string, opacity: number): string => {
  const hex = Math.round(opacity * 255).toString(16).padStart(2, '0');
  return `${color}${hex}`;
};

// Semantic color aliases
export const SemanticColors = {
  // Listing states
  listingActive: Colors.success,
  listingSold: Colors.badgeGray,
  listingWanted: Colors.warning,
  
  // Price colors
  priceOwn: Colors.primary,
  priceOther: Colors.success,
  
  // Interactive states
  buttonPrimary: Colors.primary,
  buttonSecondary: Colors.surfaceSecondary,
  buttonDanger: Colors.error,
  buttonDisabled: Colors.textTertiary,
  
  // Form states
  inputBorder: Colors.border,
  inputBorderFocus: Colors.primary,
  inputBorderError: Colors.error,
  inputPlaceholder: Colors.textTertiary,
} as const;

export type ColorScheme = typeof Colors;
export type SemanticColorScheme = typeof SemanticColors;

export default Colors;
