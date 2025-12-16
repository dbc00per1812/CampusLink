// Typography System - iOS SF Pro inspired
// Aligned with iOS CampusLink app design language

import { Platform, TextStyle } from 'react-native';

// Font family - uses system fonts which are SF Pro on iOS
const fontFamily = Platform.select({
  ios: 'System',
  android: 'Roboto',
  default: 'System',
});

// Font weights mapping
export const FontWeight = {
  regular: '400' as TextStyle['fontWeight'],
  medium: '500' as TextStyle['fontWeight'],
  semibold: '600' as TextStyle['fontWeight'],
  bold: '700' as TextStyle['fontWeight'],
  heavy: '800' as TextStyle['fontWeight'],
} as const;

// Font sizes following iOS Human Interface Guidelines
export const FontSize = {
  xs: 11,
  sm: 13,
  base: 15,
  md: 17,
  lg: 20,
  xl: 22,
  '2xl': 28,
  '3xl': 34,
  '4xl': 40,
} as const;

// Line heights optimized for readability
export const LineHeight = {
  tight: 1.2,
  normal: 1.4,
  relaxed: 1.5,
  loose: 1.75,
} as const;

// Letter spacing
export const LetterSpacing = {
  tight: -0.5,
  normal: 0,
  wide: 0.5,
  wider: 1,
} as const;

// Pre-defined text styles matching iOS typography
export const Typography = {
  // Large titles
  largeTitle: {
    fontFamily,
    fontSize: FontSize['3xl'],
    fontWeight: FontWeight.bold,
    lineHeight: FontSize['3xl'] * LineHeight.tight,
    letterSpacing: LetterSpacing.tight,
  } as TextStyle,

  // Title styles
  title1: {
    fontFamily,
    fontSize: FontSize['2xl'],
    fontWeight: FontWeight.bold,
    lineHeight: FontSize['2xl'] * LineHeight.tight,
    letterSpacing: LetterSpacing.tight,
  } as TextStyle,

  title2: {
    fontFamily,
    fontSize: FontSize.xl,
    fontWeight: FontWeight.bold,
    lineHeight: FontSize.xl * LineHeight.tight,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  title3: {
    fontFamily,
    fontSize: FontSize.lg,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.lg * LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  // Headline
  headline: {
    fontFamily,
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.md * LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  // Body styles
  body: {
    fontFamily,
    fontSize: FontSize.md,
    fontWeight: FontWeight.regular,
    lineHeight: FontSize.md * LineHeight.relaxed,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  bodyBold: {
    fontFamily,
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.md * LineHeight.relaxed,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  // Callout
  callout: {
    fontFamily,
    fontSize: FontSize.base,
    fontWeight: FontWeight.regular,
    lineHeight: FontSize.base * LineHeight.relaxed,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  // Subheadline
  subheadline: {
    fontFamily,
    fontSize: FontSize.base,
    fontWeight: FontWeight.regular,
    lineHeight: FontSize.base * LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  subheadlineBold: {
    fontFamily,
    fontSize: FontSize.base,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.base * LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  // Footnote
  footnote: {
    fontFamily,
    fontSize: FontSize.sm,
    fontWeight: FontWeight.regular,
    lineHeight: FontSize.sm * LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  footnoteBold: {
    fontFamily,
    fontSize: FontSize.sm,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.sm * LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  // Caption styles
  caption1: {
    fontFamily,
    fontSize: FontSize.sm,
    fontWeight: FontWeight.regular,
    lineHeight: FontSize.sm * LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  caption2: {
    fontFamily,
    fontSize: FontSize.xs,
    fontWeight: FontWeight.regular,
    lineHeight: FontSize.xs * LineHeight.normal,
    letterSpacing: LetterSpacing.wide,
  } as TextStyle,

  captionBold: {
    fontFamily,
    fontSize: FontSize.xs,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.xs * LineHeight.normal,
    letterSpacing: LetterSpacing.wide,
  } as TextStyle,

  // Price styling
  price: {
    fontFamily,
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    lineHeight: FontSize.lg * LineHeight.tight,
    letterSpacing: LetterSpacing.tight,
  } as TextStyle,

  priceLarge: {
    fontFamily,
    fontSize: FontSize['2xl'],
    fontWeight: FontWeight.bold,
    lineHeight: FontSize['2xl'] * LineHeight.tight,
    letterSpacing: LetterSpacing.tight,
  } as TextStyle,

  // Button text
  button: {
    fontFamily,
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.md * LineHeight.tight,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  buttonSmall: {
    fontFamily,
    fontSize: FontSize.base,
    fontWeight: FontWeight.semibold,
    lineHeight: FontSize.base * LineHeight.tight,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,

  // Badge text
  badge: {
    fontFamily,
    fontSize: FontSize.xs,
    fontWeight: FontWeight.bold,
    lineHeight: FontSize.xs * LineHeight.tight,
    letterSpacing: LetterSpacing.wide,
    textTransform: 'uppercase',
  } as TextStyle,

  // Tab bar
  tabLabel: {
    fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.medium,
    lineHeight: 12,
    letterSpacing: LetterSpacing.normal,
  } as TextStyle,
} as const;

export type TypographyStyle = keyof typeof Typography;

export default Typography;

