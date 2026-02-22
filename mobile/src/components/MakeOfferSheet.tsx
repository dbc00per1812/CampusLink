// MakeOfferSheet - Modal for making offers on listings
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  ScrollView,
  Platform,
  ActivityIndicator,
  Alert,
  Keyboard,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius } from '../utils/spacing';
import { ListingWithUser } from '../types';

interface MakeOfferSheetProps {
  visible: boolean;
  listing: ListingWithUser | null;
  onClose: () => void;
  onSubmit: (offerAmount: number, message: string) => Promise<void>;
}

const MakeOfferSheet: React.FC<MakeOfferSheetProps> = ({
  visible,
  listing,
  onClose,
  onSubmit,
}) => {
  const colors = useColors();
  const [offerAmount, setOfferAmount] = useState('');
  const [message, setMessage] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Calculate fees (matches iOS implementation)
  const calculateFees = useCallback((amount: number) => {
    // Stripe fee: 2.9% + $0.30, rounded up to the nearest cent
    const stripeFee = Math.ceil((amount * 0.029 + 0.30) * 100) / 100;
    const totalAmount = amount + stripeFee;
    return { stripeFee, totalAmount };
  }, []);

  const MINIMUM_OFFER = 0.50; // Stripe minimum
  const numericAmount = parseFloat(offerAmount) || 0;
  const { stripeFee, totalAmount } = calculateFees(numericAmount);
  const isValidOffer = numericAmount >= MINIMUM_OFFER;

  const handleSubmit = async () => {
    if (!isValidOffer || !listing) return;

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }

    setIsSubmitting(true);
    try {
      await onSubmit(numericAmount, message.trim());
      // Reset form
      setOfferAmount('');
      setMessage('');
      onClose();
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to submit offer');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleClose = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setOfferAmount('');
    setMessage('');
    onClose();
  };

  if (!listing) return null;

  const listingPrice = listing.price ?? 0;
  const isSeek = listing.intent === 'seek';

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={handleClose}
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={[styles.container, { backgroundColor: colors.background }]}
      >
        {/* Header */}
        <View style={[styles.header, { borderBottomColor: colors.border }]}>
          <TouchableOpacity onPress={handleClose} style={styles.closeButton}>
            <Ionicons name="close" size={28} color={colors.textSecondary} />
          </TouchableOpacity>
          <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>
            Make an Offer
          </Text>
          <View style={styles.placeholder} />
        </View>

        {/* Content */}
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          onScrollBeginDrag={Keyboard.dismiss}
        >
          {/* Listing Info */}
          <View style={[styles.listingInfo, { backgroundColor: colors.surfaceSecondary }]}>
            <Text style={[styles.listingTitle, { color: colors.textPrimary }]} numberOfLines={2}>
              {listing.title}
            </Text>
            {!isSeek && listingPrice > 0 && (
              <Text style={[styles.listingPrice, { color: colors.textSecondary }]}>
                Listed at ${listingPrice.toFixed(2)}
              </Text>
            )}
            {isSeek && listing.budget_max && (
              <Text style={[styles.listingPrice, { color: colors.textSecondary }]}>
                Budget: up to ${listing.budget_max.toFixed(0)}
              </Text>
            )}
          </View>

          {/* Offer Amount Input */}
          <View style={styles.inputSection}>
            <Text style={[styles.label, { color: colors.textSecondary }]}>
              Your Offer
            </Text>
            <View style={[styles.amountInputContainer, { backgroundColor: colors.surfaceSecondary, borderColor: colors.border }]}>
              <Text style={[styles.currencySymbol, { color: colors.textSecondary }]}>$</Text>
              <TextInput
                style={[styles.amountInput, { color: colors.textPrimary }]}
                value={offerAmount}
                onChangeText={setOfferAmount}
                placeholder="0.50"
                placeholderTextColor={colors.textTertiary}
                keyboardType="decimal-pad"
                autoFocus
              />
            </View>
            <Text style={[styles.minimumNote, { color: colors.textTertiary }]}>
              Minimum offer: $0.50
            </Text>
          </View>

          {/* Fee Preview */}
          {isValidOffer && (
            <View style={[styles.feePreview, { backgroundColor: colors.infoLight }]}>
              <View style={styles.feeRow}>
                <Text style={[styles.feeLabel, { color: colors.textSecondary }]}>
                  Your offer
                </Text>
                <Text style={[styles.feeValue, { color: colors.textPrimary }]}>
                  ${numericAmount.toFixed(2)}
                </Text>
              </View>
              <View style={styles.feeRow}>
                <Text style={[styles.feeLabel, { color: colors.textSecondary }]}>
                  Service fee
                </Text>
                <Text style={[styles.feeValue, { color: colors.textPrimary }]}>
                  ${stripeFee.toFixed(2)}
                </Text>
              </View>
              <View style={[styles.divider, { backgroundColor: colors.border }]} />
              <View style={styles.feeRow}>
                <Text style={[styles.totalLabel, { color: colors.textPrimary }]}>
                  You'll pay
                </Text>
                <Text style={[styles.totalValue, { color: colors.primary }]}>
                  ${totalAmount.toFixed(2)}
                </Text>
              </View>
              <Text style={[styles.feeNote, { color: colors.textTertiary }]}>
                Seller receives ${numericAmount.toFixed(2)}
              </Text>
            </View>
          )}

          {/* Message Input */}
          <View style={styles.inputSection}>
            <Text style={[styles.label, { color: colors.textSecondary }]}>
              Message (optional)
            </Text>
            <TextInput
              style={[
                styles.messageInput,
                { 
                  backgroundColor: colors.surfaceSecondary, 
                  borderColor: colors.border,
                  color: colors.textPrimary,
                }
              ]}
              value={message}
              onChangeText={setMessage}
              placeholder="Add a message to your offer..."
              placeholderTextColor={colors.textTertiary}
              multiline
              numberOfLines={3}
              textAlignVertical="top"
            />
          </View>

          {/* Submit Button */}
          <TouchableOpacity
            style={[
              styles.submitButton,
              { backgroundColor: isValidOffer ? colors.primary : colors.border },
            ]}
            onPress={handleSubmit}
            disabled={!isValidOffer || isSubmitting}
          >
            {isSubmitting ? (
              <ActivityIndicator color={colors.textInverse} />
            ) : (
              <>
                <Ionicons name="pricetag" size={20} color={colors.textInverse} />
                <Text style={[styles.submitButtonText, { color: colors.textInverse }]}>
                  Send Offer
                </Text>
              </>
            )}
          </TouchableOpacity>

          {/* Info Note */}
          <View style={styles.infoNote}>
            <Ionicons name="information-circle-outline" size={16} color={colors.textTertiary} />
            <Text style={[styles.infoNoteText, { color: colors.textTertiary }]}>
              The seller can accept, decline, or counter your offer. You'll be notified of their response.
            </Text>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
  },
  closeButton: {
    padding: Spacing.xs,
  },
  headerTitle: {
    ...Typography.headline,
    fontSize: 18,
  },
  placeholder: {
    width: 36,
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: Spacing.lg,
    gap: Spacing.lg,
  },
  listingInfo: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
  },
  listingTitle: {
    ...Typography.headline,
    marginBottom: Spacing.xs,
  },
  listingPrice: {
    ...Typography.subheadline,
  },
  inputSection: {
    gap: Spacing.sm,
  },
  label: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  amountInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
  },
  currencySymbol: {
    fontSize: 24,
    fontWeight: '600',
    marginRight: Spacing.sm,
  },
  amountInput: {
    flex: 1,
    fontSize: 24,
    fontWeight: '600',
  },
  minimumNote: {
    ...Typography.caption1,
    marginTop: Spacing.xs,
  },
  feePreview: {
    padding: Spacing.lg,
    borderRadius: BorderRadius.lg,
    gap: Spacing.sm,
  },
  feeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  feeLabel: {
    ...Typography.subheadline,
  },
  feeValue: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  divider: {
    height: 1,
    marginVertical: Spacing.xs,
  },
  totalLabel: {
    ...Typography.headline,
  },
  totalValue: {
    ...Typography.headline,
    fontWeight: '700',
  },
  feeNote: {
    ...Typography.caption1,
    textAlign: 'center',
    marginTop: Spacing.xs,
  },
  messageInput: {
    borderWidth: 1,
    borderRadius: BorderRadius.lg,
    padding: Spacing.md,
    minHeight: 80,
    ...Typography.body,
  },
  submitButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md + 2,
    borderRadius: BorderRadius.lg,
    gap: Spacing.sm,
  },
  submitButtonText: {
    ...Typography.button,
    fontSize: 17,
    fontWeight: '600',
  },
  infoNote: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.sm,
  },
  infoNoteText: {
    ...Typography.caption1,
    flex: 1,
    lineHeight: 18,
  },
});

export default MakeOfferSheet;

