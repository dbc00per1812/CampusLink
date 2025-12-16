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

interface TicketGuaranteeInfoProps {
  isOwnListing: boolean;
}

const TicketGuaranteeInfo: React.FC<TicketGuaranteeInfoProps> = ({ isOwnListing }) => {
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
    <View style={styles.container}>
      {/* Header Button */}
      <Pressable
        onPress={toggleExpanded}
        style={({ pressed }) => [
          styles.header,
          { 
            backgroundColor: `${colors.primary}1A`, // 10% opacity
            opacity: pressed ? 0.8 : 1 
          },
        ]}
      >
        <Ionicons name="information-circle" size={16} color={colors.primary} />
        <Text style={[styles.headerText, { color: colors.textPrimary }]}>
          Ticket Transaction Protection
        </Text>
        <Ionicons 
          name={isExpanded ? 'chevron-up' : 'chevron-down'} 
          size={16} 
          color={colors.textSecondary} 
        />
      </Pressable>

      {/* Expandable Content */}
      {isExpanded && (
        <View style={[styles.content, { backgroundColor: colors.surfaceSecondary }]}>
          {/* Section 1: Guarantee question */}
          <View style={styles.section}>
            <Text style={[styles.questionText, { color: colors.primary }]}>
              {isOwnListing 
                ? 'How do I guarantee I get paid for the ticket?'
                : 'How do I guarantee I receive the ticket?'}
            </Text>
            <Text style={[styles.bodyText, { color: colors.textSecondary }]}>
              At CampusLink we take necessary steps and precautions surrounding all transactions 
              so that buyers and sellers should receive what they deserve.
            </Text>
          </View>

          <View style={[styles.divider, { backgroundColor: colors.border }]} />

          {/* Section 2: The verification process */}
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              The verification process:
            </Text>
            
            {isOwnListing ? (
              // Seller view
              <View style={styles.stepsList}>
                <StepRow 
                  number="1" 
                  text="When the buyer clicks 'Buy Now' on your offered ticket, they pay the required amount and their money is held in escrow until both sides verify the transaction."
                  colors={colors}
                />
                <StepRow 
                  number="2" 
                  text="You will then be required to transfer the ticket to the buyer using one of the methods below."
                  colors={colors}
                />
                <StepRow 
                  number="3" 
                  text="Screenshot the transfer confirmation (email for Apple Wallet, or receipt from Ticketmaster, SeatGeek, Stubhub, etc.)."
                  colors={colors}
                />
                <StepRow 
                  number="4" 
                  text="Submit the photo to the confirm delivery section of the original posting (accessible through wallet or messages) and click 'Confirm Delivery'."
                  colors={colors}
                />
                <StepRow 
                  number="5" 
                  text="Buyer will then click confirm delivery on their end, acknowledging the ticket has been transferred. Funds held in escrow will then be transferred to your CampusLink wallet."
                  colors={colors}
                />
              </View>
            ) : (
              // Buyer view
              <View style={styles.stepsList}>
                <StepRow 
                  number="1" 
                  text="When you click 'Buy Now' on an offered ticket, you pay the required amount and your money is held in escrow until both sides verify the transaction."
                  colors={colors}
                />
                <StepRow 
                  number="2" 
                  text="The seller will then be required to transfer the ticket to you using one of the methods below."
                  colors={colors}
                />
                <StepRow 
                  number="3" 
                  text="Seller will screenshot the transfer confirmation (email for Apple Wallet, or receipt from Ticketmaster, SeatGeek, Stubhub, etc.)."
                  colors={colors}
                />
                <StepRow 
                  number="4" 
                  text="Seller will submit the photo to the confirm delivery section of the original posting (accessible through wallet or messages) and click 'Confirm Delivery'."
                  colors={colors}
                />
                <StepRow 
                  number="5" 
                  text="You can then click confirm delivery on your end, acknowledging the ticket has been transferred. Funds held in escrow will then be transferred to seller's CampusLink wallet."
                  colors={colors}
                />
              </View>
            )}
          </View>

          <View style={[styles.divider, { backgroundColor: colors.border }]} />

          {/* Section 3: Ticket transfer options */}
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Options for ticket transfer:
            </Text>
            
            {isOwnListing ? (
              // Seller view
              <View style={styles.transferMethodsList}>
                <TransferMethodRow
                  icon="phone-portrait"
                  title="Apple Wallet"
                  description="Click the 'more' or 'share' icons and follow the given steps to transfer the ticket using the buyer's phone number. An email should be sent including buyer information, screenshot this email and submit it when confirming delivery."
                  colors={colors}
                />
                <TransferMethodRow
                  icon="ticket"
                  title="Ticketmaster, SeatGeek, Stubhub, etc."
                  description="Transfer tickets according to the steps provided within each respective app. An email should be sent including buyer information, if not transfer should be recorded on the respective app, screenshot this and submit it to 'Confirm Delivery'."
                  colors={colors}
                />
              </View>
            ) : (
              // Buyer view
              <View style={styles.transferMethodsList}>
                <TransferMethodRow
                  icon="phone-portrait"
                  title="Apple Wallet"
                  description="Seller will use the 'more' or 'share' icons to transfer the ticket to your phone number. You'll receive an email with the ticket transfer."
                  colors={colors}
                />
                <TransferMethodRow
                  icon="ticket"
                  title="Ticketmaster, SeatGeek, Stubhub, etc."
                  description="Seller will transfer the ticket through the respective app. You'll receive an email or app notification with the ticket transfer."
                  colors={colors}
                />
              </View>
            )}
          </View>
        </View>
      )}
    </View>
  );
};

// Step Row Component
interface StepRowProps {
  number: string;
  text: string;
  colors: any;
}

const StepRow: React.FC<StepRowProps> = ({ number, text, colors }) => (
  <View style={styles.stepRow}>
    <View style={[styles.stepNumber, { backgroundColor: `${colors.primary}33` }]}>
      <Text style={[styles.stepNumberText, { color: colors.primary }]}>
        {number}
      </Text>
    </View>
    <Text style={[styles.stepText, { color: colors.textSecondary }]}>
      {text}
    </Text>
  </View>
);

// Transfer Method Row Component
interface TransferMethodRowProps {
  icon: string;
  title: string;
  description: string;
  colors: any;
}

const TransferMethodRow: React.FC<TransferMethodRowProps> = ({ icon, title, description, colors }) => (
  <View style={styles.transferMethodRow}>
    <Ionicons name={icon as any} size={20} color={colors.primary} style={styles.transferIcon} />
    <View style={styles.transferContent}>
      <Text style={[styles.transferTitle, { color: colors.textPrimary }]}>
        {title}
      </Text>
      <Text style={[styles.transferDescription, { color: colors.textSecondary }]}>
        {description}
      </Text>
    </View>
  </View>
);

const styles = StyleSheet.create({
  container: {
    marginVertical: Spacing.sm,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
    gap: Spacing.sm,
  },
  headerText: {
    ...Typography.headline,
    fontWeight: '600',
    flex: 1,
  },
  content: {
    marginTop: Spacing.sm,
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
  },
  section: {
    gap: Spacing.sm,
  },
  questionText: {
    ...Typography.subheadline,
    fontWeight: '700',
  },
  bodyText: {
    ...Typography.subheadline,
    lineHeight: 20,
  },
  divider: {
    height: 1,
    marginVertical: Spacing.md,
  },
  sectionTitle: {
    ...Typography.subheadline,
    fontWeight: '700',
    marginBottom: Spacing.xs,
  },
  stepsList: {
    gap: Spacing.sm,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
  },
  stepNumber: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepNumberText: {
    ...Typography.caption1,
    fontWeight: '700',
    fontSize: 11,
  },
  stepText: {
    ...Typography.caption1,
    flex: 1,
    lineHeight: 16,
  },
  transferMethodsList: {
    gap: Spacing.md,
  },
  transferMethodRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.md,
  },
  transferIcon: {
    width: 24,
    marginTop: 2,
  },
  transferContent: {
    flex: 1,
    gap: 4,
  },
  transferTitle: {
    ...Typography.caption1,
    fontWeight: '700',
  },
  transferDescription: {
    ...Typography.caption1,
    lineHeight: 16,
  },
});

export default TicketGuaranteeInfo;
