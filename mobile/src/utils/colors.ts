// App Color Theme - Converted from Color+Extensions.swift

export const Colors = {
  // Primary brand colors
  primary: '#3B82F6', // blue-500
  primaryDark: '#2563EB', // blue-600
  primaryLight: '#60A5FA', // blue-400

  // Status colors
  success: '#22C55E', // green-500
  warning: '#F97316', // orange-500
  error: '#EF4444', // red-500
  info: '#3B82F6', // blue-500

  // Neutral colors
  background: '#FFFFFF',
  backgroundSecondary: '#F9FAFB', // gray-50
  surface: '#FFFFFF',
  surfaceSecondary: '#F3F4F6', // gray-100

  // Text colors
  textPrimary: '#111827', // gray-900
  textSecondary: '#6B7280', // gray-500
  textTertiary: '#9CA3AF', // gray-400
  textInverse: '#FFFFFF',

  // Border colors
  border: '#E5E7EB', // gray-200
  borderFocus: '#3B82F6', // blue-500

  // Order status colors
  orderPlaced: '#3B82F6', // blue
  orderConfirmed: '#F97316', // orange
  orderInProgress: '#EAB308', // yellow
  orderCompleted: '#22C55E', // green
  orderDisputed: '#EF4444', // red
  orderCancelled: '#6B7280', // gray
  orderRefunded: '#A855F7', // purple

  // Trust level colors
  trustTrusted: '#FFD700', // gold
  trustReliable: '#C0C0C0', // silver
  trustNew: '#CD7F32', // bronze
  trustCaution: '#F97316', // orange
  trustRisk: '#EF4444', // red

  // Payout status colors
  payoutPending: '#F97316', // orange
  payoutProcessing: '#F97316', // orange
  payoutInTransit: '#F97316', // orange
  payoutCompleted: '#22C55E', // green
  payoutPaid: '#22C55E', // green
  payoutFailed: '#EF4444', // red
  payoutCancelled: '#EF4444', // red

  // Tab bar
  tabActive: '#3B82F6',
  tabInactive: '#9CA3AF',

  // Shadows (for React Native shadow props)
  shadow: '#000000',
} as const;

// Dark mode colors (for future use)
export const DarkColors = {
  ...Colors,
  background: '#111827', // gray-900
  backgroundSecondary: '#1F2937', // gray-800
  surface: '#1F2937', // gray-800
  surfaceSecondary: '#374151', // gray-700
  textPrimary: '#F9FAFB', // gray-50
  textSecondary: '#D1D5DB', // gray-300
  textTertiary: '#9CA3AF', // gray-400
  border: '#374151', // gray-700
} as const;

export type ColorScheme = typeof Colors;

export default Colors;

