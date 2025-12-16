import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  LayoutAnimation,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius } from '../utils/spacing';

interface ProductVerificationInfoProps {
  isForSeller: boolean; // true for sellers, false for buyers
}

const ProductVerificationInfo: React.FC<ProductVerificationInfoProps> = ({ isForSeller }) => {
  const colors = useColors();
  const [isExpanded, setIsExpanded] = useState(false);

  const toggleExpanded = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    }
    setIsExpanded(!isExpanded);
  };

  return (
    <View style={[
      styles.container,
      { 
        backgroundColor: `${colors.primary}0D`, // ~5% opacity
        borderColor: `${colors.primary}4D`, // ~30% opacity
      }
    ]}>
      {/* Header Button */}
      <Pressable
        onPress={toggleExpanded}
        style={({ pressed }) => [
          styles.header,
          { opacity: pressed ? 0.8 : 1 }
        ]}
      >
        <Ionicons name="information-circle" size={16} color={colors.primary} />
        <Text style={[styles.headerText, { color: colors.primary }]}>
          {isForSeller 
            ? 'How do I make sure I get paid for my product?'
            : 'How do I make sure I receive the product?'}
        </Text>
        <Ionicons 
          name={isExpanded ? 'chevron-up' : 'chevron-down'} 
          size={14} 
          color={colors.primary} 
        />
      </Pressable>

      {/* Expandable Content */}
      {isExpanded && (
        <View style={[styles.content, { backgroundColor: colors.surfaceSecondary }]}>
          <Text style={[styles.bodyText, { color: colors.textSecondary }]}>
            At CampusLink we take necessary steps and precautions surrounding all transactions 
            so that buyers and sellers should receive what they deserve.
          </Text>

          <Text style={[styles.processTitle, { color: colors.textPrimary }]}>
            The process for verifying a product transaction:
          </Text>

          <View style={styles.bulletList}>
            <BulletPoint
              icon="shield-checkmark"
              text="When the buyer clicks 'Buy Now' on an offered product, they pay the required amount and their money is held in escrow until both sides verify the transaction."
              colors={colors}
            />
            <BulletPoint
              icon="camera"
              text="Upon the moment of the product's delivery, whether the buyer picks up or the seller delivers, the seller must take a photo of the delivered product and submit it to CampusLink and click 'Confirm Delivery'."
              colors={colors}
            />
            <BulletPoint
              icon="checkmark-done-circle"
              text="Once the buyer receives the product, they then click 'Confirm Delivery' on their end and the money held in escrow is transferred into the seller's wallet."
              colors={colors}
            />
          </View>
        </View>
      )}
    </View>
  );
};

// Bullet Point Component
interface BulletPointProps {
  icon: string;
  text: string;
  colors: any;
}

const BulletPoint: React.FC<BulletPointProps> = ({ icon, text, colors }) => (
  <View style={styles.bulletPoint}>
    <Ionicons 
      name={icon as any} 
      size={16} 
      color={colors.primary} 
      style={styles.bulletIcon}
    />
    <Text style={[styles.bulletText, { color: colors.textSecondary }]}>
      {text}
    </Text>
  </View>
);

const styles = StyleSheet.create({
  container: {
    marginVertical: Spacing.sm,
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  headerText: {
    ...Typography.subheadline,
    fontWeight: '500',
    flex: 1,
  },
  content: {
    marginTop: Spacing.md,
    padding: Spacing.md,
    borderRadius: BorderRadius.md,
    gap: Spacing.md,
  },
  bodyText: {
    ...Typography.caption1,
    lineHeight: 16,
  },
  processTitle: {
    ...Typography.caption1,
    fontWeight: '600',
  },
  bulletList: {
    gap: Spacing.sm,
  },
  bulletPoint: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
  },
  bulletIcon: {
    width: 16,
    marginTop: 2,
  },
  bulletText: {
    ...Typography.caption1,
    flex: 1,
    lineHeight: 16,
  },
});

export default ProductVerificationInfo;
