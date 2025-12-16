// Report User Modal - Report users or listings
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  ScrollView,
  TextInput,
  Pressable,
  ActivityIndicator,
  Alert,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useColors } from '../context/ThemeContext';
import { Typography } from '../utils/typography';
import { Spacing, BorderRadius } from '../utils/spacing';
import { submitReport } from '../services/reportService';
import { ReportType, ReportTypeDisplay, ReportTypeDescription, REPORT_TYPES } from '../types/report';

interface ReportUserModalProps {
  visible: boolean;
  onClose: () => void;
  reportedUserId?: string | null;
  reportedUserName?: string | null;
  reportedListingId?: string | null;
  reportedListingTitle?: string | null;
  onBlockUser?: () => void;
}

export const ReportUserModal: React.FC<ReportUserModalProps> = ({
  visible,
  onClose,
  reportedUserId,
  reportedUserName,
  reportedListingId,
  reportedListingTitle,
  onBlockUser,
}) => {
  const colors = useColors();
  const [selectedType, setSelectedType] = useState<ReportType>('inappropriate_content');
  const [description, setDescription] = useState('');
  const [alsoBlock, setAlsoBlock] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showTypePicker, setShowTypePicker] = useState(false);

  const handleClose = () => {
    if (!isSubmitting) {
      setDescription('');
      setSelectedType('inappropriate_content');
      setAlsoBlock(false);
      onClose();
    }
  };

  const handleSubmit = async () => {
    if (description.trim().length < 10) {
      Alert.alert('More Details Needed', 'Please provide at least 10 characters describing the issue.');
      return;
    }

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }

    setIsSubmitting(true);

    try {
      await submitReport({
        reported_user_id: reportedUserId,
        reported_listing_id: reportedListingId,
        report_type: selectedType,
        description: description.trim(),
      });

      // If user also wants to block
      if (alsoBlock && reportedUserId && onBlockUser) {
        onBlockUser();
      }

      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }

      const message = alsoBlock && reportedUserId
        ? 'Thank you for your report. We will review it within 24-48 hours. The user has also been blocked.'
        : 'Thank you for your report. We will review it within 24-48 hours and take appropriate action.';

      Alert.alert('Report Submitted', message, [
        {
          text: 'OK',
          onPress: handleClose,
        },
      ]);
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to submit report');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={handleClose}
    >
      <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
        {/* Header */}
        <View style={[styles.header, { borderBottomColor: colors.border }]}>
          <Pressable
            onPress={handleClose}
            disabled={isSubmitting}
            style={({ pressed }) => ({ opacity: pressed ? 0.5 : 1 })}
          >
            <Text style={[styles.cancelButton, { color: colors.primary }]}>Cancel</Text>
          </Pressable>
          <Text style={[styles.title, { color: colors.textPrimary }]}>Report</Text>
          <Pressable
            onPress={handleSubmit}
            disabled={description.trim().length < 10 || isSubmitting}
            style={({ pressed }) => ({ opacity: pressed ? 0.5 : 1 })}
          >
            <Text
              style={[
                styles.submitButton,
                {
                  color: description.trim().length < 10 || isSubmitting ? colors.textTertiary : colors.primary,
                },
              ]}
            >
              Submit
            </Text>
          </Pressable>
        </View>

        <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
          {/* What's being reported */}
          <View style={[styles.section, { backgroundColor: colors.surfaceSecondary }]}>
            <Text style={[styles.sectionHeader, { color: colors.textSecondary }]}>REPORTING</Text>
            <View style={styles.reportingInfo}>
              {reportedListingTitle && (
                <View style={styles.infoRow}>
                  <Ionicons name="pricetag" size={20} color={colors.primary} />
                  <View style={styles.infoText}>
                    <Text style={[styles.infoLabel, { color: colors.textSecondary }]}>Listing</Text>
                    <Text style={[styles.infoValue, { color: colors.textPrimary }]}>
                      {reportedListingTitle}
                    </Text>
                  </View>
                </View>
              )}
              {reportedUserName && (
                <View style={styles.infoRow}>
                  <Ionicons name="person" size={20} color={colors.primary} />
                  <View style={styles.infoText}>
                    <Text style={[styles.infoLabel, { color: colors.textSecondary }]}>User</Text>
                    <Text style={[styles.infoValue, { color: colors.textPrimary }]}>
                      {reportedUserName}
                    </Text>
                  </View>
                </View>
              )}
            </View>
          </View>

          {/* Report Type */}
          <View style={[styles.section, { backgroundColor: colors.surfaceSecondary }]}>
            <Text style={[styles.sectionHeader, { color: colors.textSecondary }]}>REASON FOR REPORT</Text>
            <Pressable
              style={[styles.picker, { borderColor: colors.border }]}
              onPress={() => setShowTypePicker(!showTypePicker)}
            >
              <Text style={[styles.pickerText, { color: colors.textPrimary }]}>
                {ReportTypeDisplay[selectedType]}
              </Text>
              <Ionicons
                name={showTypePicker ? 'chevron-up' : 'chevron-down'}
                size={20}
                color={colors.textTertiary}
              />
            </Pressable>

            {showTypePicker && (
              <View style={[styles.typeList, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                {REPORT_TYPES.map((type) => (
                  <Pressable
                    key={type}
                    style={[
                      styles.typeItem,
                      selectedType === type && { backgroundColor: colors.primaryMuted },
                    ]}
                    onPress={() => {
                      setSelectedType(type);
                      setShowTypePicker(false);
                      if (Platform.OS !== 'web') {
                        Haptics.selectionAsync();
                      }
                    }}
                  >
                    <Text
                      style={[
                        styles.typeText,
                        {
                          color: selectedType === type ? colors.primary : colors.textPrimary,
                          fontWeight: selectedType === type ? '600' : '400',
                        },
                      ]}
                    >
                      {ReportTypeDisplay[type]}
                    </Text>
                    {selectedType === type && (
                      <Ionicons name="checkmark" size={20} color={colors.primary} />
                    )}
                  </Pressable>
                ))}
              </View>
            )}

            <Text style={[styles.typeDescription, { color: colors.textTertiary }]}>
              {ReportTypeDescription[selectedType]}
            </Text>
            <Text style={[styles.sectionFooter, { color: colors.textTertiary }]}>
              Please select the option that best describes the issue
            </Text>
          </View>

          {/* Description */}
          <View style={[styles.section, { backgroundColor: colors.surfaceSecondary }]}>
            <Text style={[styles.sectionHeader, { color: colors.textSecondary }]}>
              ADDITIONAL INFORMATION
            </Text>
            <TextInput
              style={[
                styles.textArea,
                { backgroundColor: colors.surface, borderColor: colors.border, color: colors.textPrimary },
              ]}
              multiline
              numberOfLines={6}
              value={description}
              onChangeText={setDescription}
              placeholder="Please provide specific details about the issue..."
              placeholderTextColor={colors.textTertiary}
              textAlignVertical="top"
            />
            <Text style={[styles.sectionFooter, { color: colors.textTertiary }]}>
              The more details you provide, the better we can investigate this report
            </Text>
          </View>

          {/* Block User Option */}
          {reportedUserId && (
            <View style={[styles.section, { backgroundColor: colors.surfaceSecondary }]}>
              <Pressable
                style={styles.toggleRow}
                onPress={() => {
                  setAlsoBlock(!alsoBlock);
                  if (Platform.OS !== 'web') {
                    Haptics.selectionAsync();
                  }
                }}
              >
                <View style={styles.toggleText}>
                  <Text style={[styles.toggleLabel, { color: colors.textPrimary }]}>
                    Also block this user
                  </Text>
                  <Text style={[styles.toggleDescription, { color: colors.textSecondary }]}>
                    You won't see each other's content or be able to message
                  </Text>
                </View>
                <View
                  style={[
                    styles.toggle,
                    { backgroundColor: alsoBlock ? colors.error : colors.border },
                  ]}
                >
                  <View
                    style={[
                      styles.toggleThumb,
                      { backgroundColor: colors.surface },
                      alsoBlock && styles.toggleThumbActive,
                    ]}
                  />
                </View>
              </Pressable>
              <Text style={[styles.sectionFooter, { color: colors.textTertiary }]}>
                Blocking is mutual and prevents all interactions
              </Text>
            </View>
          )}

          {/* Important Info */}
          <View style={[styles.section, { backgroundColor: colors.surfaceSecondary }]}>
            <Text style={[styles.sectionHeader, { color: colors.textSecondary }]}>
              IMPORTANT INFORMATION
            </Text>
            <View style={styles.infoList}>
              <View style={styles.infoItem}>
                <Ionicons name="warning" size={16} color={colors.warning} />
                <Text style={[styles.infoItemText, { color: colors.textSecondary }]}>
                  False reports may result in account suspension
                </Text>
              </View>
              <View style={styles.infoItem}>
                <Ionicons name="time" size={16} color={colors.info} />
                <Text style={[styles.infoItemText, { color: colors.textSecondary }]}>
                  All reports are reviewed within 24-48 hours
                </Text>
              </View>
              <View style={styles.infoItem}>
                <Ionicons name="lock-closed" size={16} color={colors.success} />
                <Text style={[styles.infoItemText, { color: colors.textSecondary }]}>
                  Your identity will remain anonymous
                </Text>
              </View>
            </View>
          </View>
        </ScrollView>

        {/* Loading Overlay */}
        {isSubmitting && (
          <View style={styles.loadingOverlay}>
            <View style={[styles.loadingBox, { backgroundColor: colors.surface }]}>
              <ActivityIndicator size="large" color={colors.primary} />
              <Text style={[styles.loadingText, { color: colors.textPrimary }]}>
                Submitting report...
              </Text>
            </View>
          </View>
        )}
      </SafeAreaView>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
  },
  cancelButton: {
    ...Typography.body,
    width: 60,
  },
  title: {
    ...Typography.headline,
    fontWeight: '600',
  },
  submitButton: {
    ...Typography.body,
    fontWeight: '600',
    width: 60,
    textAlign: 'right',
  },
  scrollView: {
    flex: 1,
  },
  section: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    marginBottom: Spacing.xs,
  },
  sectionHeader: {
    ...Typography.caption1,
    fontWeight: '600',
    marginBottom: Spacing.sm,
  },
  sectionFooter: {
    ...Typography.caption2,
    marginTop: Spacing.sm,
  },
  reportingInfo: {
    gap: Spacing.md,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
  },
  infoText: {
    flex: 1,
  },
  infoLabel: {
    ...Typography.caption1,
  },
  infoValue: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  picker: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.md,
    borderWidth: 1,
    borderRadius: BorderRadius.md,
  },
  pickerText: {
    ...Typography.body,
  },
  typeList: {
    marginTop: Spacing.sm,
    borderWidth: 1,
    borderRadius: BorderRadius.md,
    overflow: 'hidden',
  },
  typeItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.md,
  },
  typeText: {
    ...Typography.body,
  },
  typeDescription: {
    ...Typography.caption1,
    marginTop: Spacing.sm,
  },
  textArea: {
    minHeight: 120,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    borderWidth: 1,
    borderRadius: BorderRadius.md,
    ...Typography.body,
  },
  toggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  toggleText: {
    flex: 1,
    marginRight: Spacing.md,
  },
  toggleLabel: {
    ...Typography.subheadline,
    fontWeight: '500',
  },
  toggleDescription: {
    ...Typography.caption1,
    marginTop: 4,
  },
  toggle: {
    width: 50,
    height: 30,
    borderRadius: 15,
    padding: 2,
    justifyContent: 'center',
  },
  toggleThumb: {
    width: 26,
    height: 26,
    borderRadius: 13,
  },
  toggleThumbActive: {
    alignSelf: 'flex-end',
  },
  infoList: {
    gap: Spacing.sm,
  },
  infoItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
  },
  infoItemText: {
    ...Typography.caption1,
    flex: 1,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingBox: {
    padding: Spacing.xl,
    borderRadius: BorderRadius.lg,
    alignItems: 'center',
    gap: Spacing.md,
  },
  loadingText: {
    ...Typography.subheadline,
  },
});

export default ReportUserModal;
