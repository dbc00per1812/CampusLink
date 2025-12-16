// Transaction Guide Screen - How Transactions Work
// Aligned with iOS TransactionGuideView.swift
import React, { useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Linking,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius } from '../../utils/spacing';

type Props = {
  navigation: any;
};

const TransactionGuideScreen: React.FC<Props> = ({ navigation }) => {
  const colors = useColors();

  const handleContactSupport = useCallback(() => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    Linking.openURL('mailto:darragh.b3272@gmail.com?subject=CampusLink%20Support%20Request');
  }, []);

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={[styles.header, { backgroundColor: colors.background, borderBottomColor: colors.border }]}>
        <View style={styles.headerContent}>
          <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>
            Transaction Guide
          </Text>
          <Pressable
            onPress={() => navigation.goBack()}
            style={({ pressed }) => [
              styles.closeButton,
              { opacity: pressed ? 0.5 : 1 },
            ]}
          >
            <Text style={[styles.closeText, { color: colors.primary }]}>Done</Text>
          </Pressable>
        </View>
      </View>

      <ScrollView 
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Title Section */}
        <View style={styles.titleSection}>
          <Text style={[styles.title, { color: colors.textPrimary }]}>
            How Transactions Work
          </Text>
          <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
            Everything you need to know about buying and selling safely on CampusLink
          </Text>
        </View>

        <View style={[styles.divider, { backgroundColor: colors.border }]} />

        {/* General Protection */}
        <SectionHeader 
          icon="shield-checkmark-outline" 
          title="Buyer & Seller Protection" 
          color={colors.primary}
          textColor={colors.textPrimary}
        />
        
        <Text style={[styles.sectionDescription, { color: colors.textSecondary }]}>
          At CampusLink we take necessary steps and precautions surrounding all transactions so that buyers and sellers should receive what they deserve.
        </Text>
        
        <InfoCard
          icon="lock-closed"
          title="Escrow Protection"
          description="All payments are held in secure escrow until both parties verify the transaction is complete. This protects buyers from not receiving items and sellers from not getting paid."
          colors={colors}
        />
        
        <InfoCard
          icon="checkmark-circle"
          title="Two-Way Verification"
          description="Both buyer and seller must confirm the transaction before funds are released. This ensures accountability on both sides."
          colors={colors}
        />
        
        <InfoCard
          icon="wallet-outline"
          title="CampusLink Wallet"
          description="Sellers receive funds in their CampusLink wallet after successful verification. Funds can be withdrawn to your bank account or used for purchases."
          colors={colors}
        />

        <View style={[styles.divider, { backgroundColor: colors.border }]} />

        {/* Product Transactions */}
        <SectionHeader 
          icon="cube-outline" 
          title="Product Transactions" 
          color="#007AFF"
          textColor={colors.textPrimary}
        />
        
        <Text style={[styles.sectionDescription, { color: colors.textSecondary }]}>
          For physical items like textbooks, electronics, furniture, etc.
        </Text>

        <View style={[styles.stepsCard, { backgroundColor: colors.accentBlue }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>As a Buyer:</Text>
          
          <TransactionStep
            number="1"
            title="Purchase & Escrow"
            description="When you click 'Buy Now', you pay the required amount and your money is held in escrow until both sides verify the transaction."
            colors={colors}
          />
          
          <TransactionStep
            number="2"
            title="Coordinate Meetup"
            description="Use the built-in messaging to coordinate pickup or delivery details with the seller."
            colors={colors}
          />
          
          <TransactionStep
            number="3"
            title="Receive Product"
            description="Meet the seller to receive your product. Inspect it to ensure it matches the listing description."
            colors={colors}
          />
          
          <TransactionStep
            number="4"
            title="Confirm Delivery"
            description="After receiving the product, click 'Confirm Delivery' in your order. This releases the payment to the seller."
            colors={colors}
          />
        </View>

        <View style={[styles.stepsCard, { backgroundColor: colors.accentGreen }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>As a Seller:</Text>
          
          <TransactionStep
            number="1"
            title="Receive Order"
            description="You'll be notified when someone purchases your item. The buyer's payment is held in escrow."
            colors={colors}
          />
          
          <TransactionStep
            number="2"
            title="Coordinate Delivery"
            description="Use messaging to arrange pickup or delivery with the buyer."
            colors={colors}
          />
          
          <TransactionStep
            number="3"
            title="Deliver & Document"
            description="Upon delivery, take a photo of the delivered product and submit it to CampusLink. Click 'Confirm Delivery'."
            colors={colors}
          />
          
          <TransactionStep
            number="4"
            title="Wait for Buyer Confirmation"
            description="Once the buyer confirms receipt by clicking 'Confirm Delivery', the money held in escrow is transferred to your wallet."
            colors={colors}
          />
        </View>

        <View style={[styles.divider, { backgroundColor: colors.border }]} />

        {/* Service Transactions */}
        <SectionHeader 
          icon="person-outline" 
          title="Service Transactions" 
          color="#34C759"
          textColor={colors.textPrimary}
        />
        
        <Text style={[styles.sectionDescription, { color: colors.textSecondary }]}>
          For services like tutoring, photography, moving help, etc.
        </Text>

        <View style={[styles.pinCard, { backgroundColor: 'rgba(52, 199, 89, 0.1)' }]}>
          <View style={styles.pinHeader}>
            <Ionicons name="keypad" size={30} color="#34C759" />
            <View style={styles.pinTextContainer}>
              <Text style={[styles.pinTitle, { color: colors.textPrimary }]}>4-Digit PIN System</Text>
              <Text style={[styles.pinSubtitle, { color: colors.textSecondary }]}>
                Services use a unique PIN code for verification instead of photo proof
              </Text>
            </View>
          </View>
        </View>

        <View style={[styles.stepsCard, { backgroundColor: colors.accentBlue }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>As a Buyer:</Text>
          
          <TransactionStep
            number="1"
            title="Purchase Service"
            description="Click 'Buy Now' and your payment is held in escrow until verification."
            colors={colors}
          />
          
          <TransactionStep
            number="2"
            title="Receive Your PIN"
            description="Upon purchase, you'll receive a unique 4-digit PIN code. Keep this secure."
            colors={colors}
          />
          
          <TransactionStep
            number="3"
            title="Receive Service"
            description="The seller provides the agreed-upon service. You can monitor their progress."
            colors={colors}
          />
          
          <TransactionStep
            number="4"
            title="Share PIN to Release Payment"
            description="Once you're satisfied with the service, give the 4-digit PIN to the seller. They'll enter it to receive payment from escrow."
            colors={colors}
          />
        </View>

        <View style={[styles.stepsCard, { backgroundColor: colors.accentGreen }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>As a Seller:</Text>
          
          <TransactionStep
            number="1"
            title="Receive Order"
            description="You'll be notified when someone books your service. Payment is held in escrow."
            colors={colors}
          />
          
          <TransactionStep
            number="2"
            title="Coordinate & Provide Service"
            description="Use messaging to coordinate timing and location. Provide the agreed service."
            colors={colors}
          />
          
          <TransactionStep
            number="3"
            title="Request PIN"
            description="You have the right to ask for the 4-digit PIN at any point to ensure payment before completing the full service."
            colors={colors}
          />
          
          <TransactionStep
            number="4"
            title="Enter PIN to Get Paid"
            description="Once the buyer gives you the PIN, enter it in the app. The money held in escrow will be transferred to your wallet."
            colors={colors}
          />
        </View>

        <View style={[styles.divider, { backgroundColor: colors.border }]} />

        {/* Ticket Transactions */}
        <SectionHeader 
          icon="ticket-outline" 
          title="Ticket Transactions" 
          color="#FF9500"
          textColor={colors.textPrimary}
        />
        
        <Text style={[styles.sectionDescription, { color: colors.textSecondary }]}>
          Special verification process for event tickets
        </Text>

        <View style={[styles.stepsCard, { backgroundColor: 'rgba(255, 149, 0, 0.05)' }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>Accepted Transfer Methods:</Text>
          
          <TransferMethodCard
            icon="phone-portrait-outline"
            title="Apple Wallet"
            description="Transfer via phone number using the share function"
            colors={colors}
          />
          
          <TransferMethodCard
            icon="ticket-outline"
            title="Ticketing Apps"
            description="Ticketmaster, SeatGeek, StubHub, and other major platforms"
            colors={colors}
          />
        </View>

        <View style={[styles.stepsCard, { backgroundColor: colors.accentBlue }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>As a Buyer:</Text>
          
          <TransactionStep
            number="1"
            title="Purchase Ticket"
            description="Click 'Buy Now' and your payment is held in escrow until both sides verify the transaction."
            colors={colors}
          />
          
          <TransactionStep
            number="2"
            title="Seller Transfers Ticket"
            description="The seller will transfer the ticket to you through Apple Wallet or their ticketing app."
            colors={colors}
          />
          
          <TransactionStep
            number="3"
            title="Receive Transfer"
            description="You'll receive an email or app notification with the ticket transfer."
            colors={colors}
          />
          
          <TransactionStep
            number="4"
            title="Seller Provides Proof"
            description="Seller will upload a screenshot of the transfer confirmation (email or app receipt)."
            colors={colors}
          />
          
          <TransactionStep
            number="5"
            title="Confirm Receipt"
            description="After verifying you received the ticket, click 'Confirm Delivery'. Funds are then released to the seller's wallet."
            colors={colors}
          />
        </View>

        <View style={[styles.stepsCard, { backgroundColor: colors.accentGreen }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>As a Seller:</Text>
          
          <TransactionStep
            number="1"
            title="Receive Order"
            description="You'll be notified when someone buys your ticket. Their payment is held in escrow."
            colors={colors}
          />
          
          <TransactionStep
            number="2"
            title="Transfer the Ticket"
            description="Transfer the ticket using Apple Wallet (via phone number) or your ticketing app (Ticketmaster, SeatGeek, etc.)."
            colors={colors}
          />
          
          <TransactionStep
            number="3"
            title="Screenshot Confirmation"
            description="Take a screenshot of the transfer confirmation email or app receipt showing the buyer's information."
            colors={colors}
          />
          
          <TransactionStep
            number="4"
            title="Submit Proof"
            description="Upload the screenshot to the 'Confirm Delivery' section (accessible through wallet or messages) and click 'Confirm Delivery'."
            colors={colors}
          />
          
          <TransactionStep
            number="5"
            title="Wait for Buyer Confirmation"
            description="Once the buyer confirms they received the ticket, funds held in escrow will be transferred to your wallet."
            colors={colors}
          />
        </View>

        <View style={[styles.divider, { backgroundColor: colors.border }]} />

        {/* Payments & Wallet */}
        <SectionHeader 
          icon="card-outline" 
          title="Payments & Wallet" 
          color="#AF52DE"
          textColor={colors.textPrimary}
        />
        
        <Text style={[styles.sectionDescription, { color: colors.textSecondary }]}>
          Understanding how payments work on CampusLink
        </Text>

        <InfoCard
          icon="card-outline"
          title="Payment Methods"
          description="Pay with your CampusLink wallet balance or add a debit/credit card for purchases."
          colors={colors}
        />
        
        <InfoCard
          icon="business-outline"
          title="Receiving Payments (Sellers)"
          description="Complete Stripe Connect onboarding in the Wallet tab to receive payments. This is required before you can post listings."
          colors={colors}
        />
        
        <InfoCard
          icon="arrow-down-circle-outline"
          title="Withdrawing Funds"
          description="Sellers can withdraw funds from their CampusLink wallet to their linked bank account through the Wallet tab."
          colors={colors}
        />
        
        <InfoCard
          icon="cash-outline"
          title="Wallet Balance"
          description="Keep funds in your wallet to make quick purchases or to accumulate earnings before withdrawing."
          colors={colors}
        />

        <View style={[styles.stepsCard, { backgroundColor: 'rgba(175, 82, 222, 0.05)' }]}>
          <Text style={[styles.roleTitle, { color: colors.textPrimary }]}>First Time Sellers:</Text>
          
          <View style={styles.onboardingStep}>
            <Text style={[styles.stepNumber, { color: colors.primary }]}>1.</Text>
            <Text style={[styles.stepText, { color: colors.textPrimary }]}>Go to the Wallet tab</Text>
          </View>
          
          <View style={styles.onboardingStep}>
            <Text style={[styles.stepNumber, { color: colors.primary }]}>2.</Text>
            <Text style={[styles.stepText, { color: colors.textPrimary }]}>Complete Stripe Connect onboarding</Text>
          </View>
          
          <View style={styles.onboardingStep}>
            <Text style={[styles.stepNumber, { color: colors.primary }]}>3.</Text>
            <Text style={[styles.stepText, { color: colors.textPrimary }]}>Return to Home to start posting!</Text>
          </View>
        </View>

        <View style={[styles.divider, { backgroundColor: colors.border }]} />

        {/* Contact Support */}
        <SectionHeader 
          icon="help-circle-outline" 
          title="Need Help?" 
          color={colors.primary}
          textColor={colors.textPrimary}
        />
        
        <Text style={[styles.sectionDescription, { color: colors.textSecondary }]}>
          Have questions or concerns about a transaction?
        </Text>
        
        <Text style={[styles.sectionDescription, { color: colors.textSecondary }]}>
          Our support team is here to help you with any issues related to buying, selling, payments, or disputes.
        </Text>

        <Pressable
          onPress={handleContactSupport}
          style={({ pressed }) => [
            styles.supportButton,
            { backgroundColor: colors.primary, opacity: pressed ? 0.8 : 1 },
          ]}
        >
          <Ionicons name="mail" size={18} color="#FFFFFF" />
          <Text style={styles.supportButtonText}>Contact Support</Text>
        </Pressable>

        <View style={styles.responseTime}>
          <Ionicons name="time" size={14} color="#34C759" />
          <Text style={[styles.responseTimeText, { color: colors.textSecondary }]}>
            We typically respond within 24 hours
          </Text>
        </View>

        <View style={{ height: Spacing['3xl'] }} />
      </ScrollView>
    </SafeAreaView>
  );
};

// Supporting Components

const SectionHeader: React.FC<{
  icon: string;
  title: string;
  color: string;
  textColor: string;
}> = ({ icon, title, color, textColor }) => (
  <View style={styles.sectionHeader}>
    <Ionicons name={icon as any} size={28} color={color} />
    <Text style={[styles.sectionTitle, { color: textColor }]}>{title}</Text>
  </View>
);

const TransactionStep: React.FC<{
  number: string;
  title: string;
  description: string;
  colors: any;
}> = ({ number, title, description, colors }) => (
  <View style={styles.transactionStep}>
    <View style={[styles.stepNumberCircle, { backgroundColor: colors.primary }]}>
      <Text style={styles.stepNumberText}>{number}</Text>
    </View>
    <View style={styles.stepContent}>
      <Text style={[styles.stepTitle, { color: colors.textPrimary }]}>{title}</Text>
      <Text style={[styles.stepDescription, { color: colors.textSecondary }]}>{description}</Text>
    </View>
  </View>
);

const InfoCard: React.FC<{
  icon: string;
  title: string;
  description: string;
  colors: any;
}> = ({ icon, title, description, colors }) => (
  <View style={[styles.infoCard, { backgroundColor: colors.backgroundSecondary }]}>
    <View style={styles.infoIconContainer}>
      <Ionicons name={icon as any} size={24} color={colors.primary} />
    </View>
    <View style={styles.infoContent}>
      <Text style={[styles.infoTitle, { color: colors.textPrimary }]}>{title}</Text>
      <Text style={[styles.infoDescription, { color: colors.textSecondary }]}>{description}</Text>
    </View>
  </View>
);

const TransferMethodCard: React.FC<{
  icon: string;
  title: string;
  description: string;
  colors: any;
}> = ({ icon, title, description, colors }) => (
  <View style={styles.transferMethod}>
    <View style={styles.transferIconContainer}>
      <Ionicons name={icon as any} size={20} color={colors.primary} />
    </View>
    <View style={styles.transferContent}>
      <Text style={[styles.transferTitle, { color: colors.textPrimary }]}>{title}</Text>
      <Text style={[styles.transferDescription, { color: colors.textSecondary }]}>{description}</Text>
    </View>
  </View>
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    borderBottomWidth: 1,
    paddingBottom: Spacing.md,
    paddingTop: Spacing.sm,
  },
  headerContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.lg,
    position: 'relative',
  },
  headerTitle: {
    ...Typography.headline,
  },
  closeButton: {
    position: 'absolute',
    right: Spacing.lg,
  },
  closeText: {
    ...Typography.body,
    fontWeight: '600',
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.xl,
    paddingBottom: Spacing['3xl'],
  },
  titleSection: {
    marginBottom: Spacing.lg,
  },
  title: {
    ...Typography.largeTitle,
    marginBottom: Spacing.xs,
  },
  subtitle: {
    ...Typography.subheadline,
  },
  divider: {
    height: 1,
    marginVertical: Spacing.xl,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  sectionTitle: {
    ...Typography.title2,
  },
  sectionDescription: {
    ...Typography.body,
    marginBottom: Spacing.md,
  },
  infoCard: {
    flexDirection: 'row',
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.md,
  },
  infoIconContainer: {
    width: 32,
    marginRight: Spacing.md,
  },
  infoContent: {
    flex: 1,
  },
  infoTitle: {
    ...Typography.subheadline,
    fontWeight: '600',
    marginBottom: Spacing.xs,
  },
  infoDescription: {
    ...Typography.caption,
    lineHeight: 18,
  },
  stepsCard: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
  },
  roleTitle: {
    ...Typography.headline,
    marginBottom: Spacing.md,
  },
  transactionStep: {
    flexDirection: 'row',
    marginBottom: Spacing.md,
  },
  stepNumberCircle: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  stepNumberText: {
    ...Typography.caption,
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  stepContent: {
    flex: 1,
  },
  stepTitle: {
    ...Typography.subheadline,
    fontWeight: '600',
    marginBottom: Spacing.xs,
  },
  stepDescription: {
    ...Typography.caption,
    lineHeight: 18,
  },
  pinCard: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
  },
  pinHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
  },
  pinTextContainer: {
    flex: 1,
  },
  pinTitle: {
    ...Typography.headline,
    marginBottom: Spacing.xs,
  },
  pinSubtitle: {
    ...Typography.caption,
  },
  transferMethod: {
    flexDirection: 'row',
    marginBottom: Spacing.md,
  },
  transferIconContainer: {
    width: 24,
    marginRight: Spacing.md,
  },
  transferContent: {
    flex: 1,
  },
  transferTitle: {
    ...Typography.caption,
    fontWeight: 'bold',
    marginBottom: 2,
  },
  transferDescription: {
    ...Typography.caption,
    lineHeight: 16,
  },
  onboardingStep: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: Spacing.sm,
  },
  stepNumber: {
    ...Typography.body,
    fontWeight: 'bold',
    marginRight: Spacing.sm,
  },
  stepText: {
    ...Typography.body,
    flex: 1,
  },
  supportButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.lg,
    marginTop: Spacing.md,
  },
  supportButtonText: {
    ...Typography.headline,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  responseTime: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    marginTop: Spacing.md,
  },
  responseTimeText: {
    ...Typography.caption,
  },
});

export default TransactionGuideScreen;

