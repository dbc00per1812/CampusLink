// Interest Selection Screen - Shown during signup
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  ScrollView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { AuthScreenProps } from '../../navigation/types';
import { saveUserInterests } from '../../services/userInterestService';
import Colors from '../../utils/colors';
import { ListingType } from '../../types/product';

type Props = AuthScreenProps<'InterestSelection'>;

interface InterestOption {
  category: string;
  icon: keyof typeof Ionicons.glyphMap;
  type: ListingType;
}

// Product categories - matching iOS
const PRODUCT_CATEGORIES: InterestOption[] = [
  { category: 'Electronics', icon: 'laptop-outline', type: 'product' },
  { category: 'Books', icon: 'book-outline', type: 'product' },
  { category: 'Furniture', icon: 'bed-outline', type: 'product' },
  { category: 'Clothing', icon: 'shirt-outline', type: 'product' },
  { category: 'Sports', icon: 'basketball-outline', type: 'product' },
  { category: 'Tickets', icon: 'ticket-outline', type: 'product' },
];

// Service categories - matching iOS
const SERVICE_CATEGORIES: InterestOption[] = [
  { category: 'Tutoring', icon: 'school-outline', type: 'service' },
  { category: 'Moving', icon: 'cube-outline', type: 'service' },
  { category: 'Cleaning', icon: 'sparkles-outline', type: 'service' },
];

const InterestSelectionScreen: React.FC<Props> = ({ navigation }) => {
  const [selectedInterests, setSelectedInterests] = useState<Set<string>>(new Set());
  const [isSaving, setIsSaving] = useState(false);

  const toggleInterest = (category: string, type: ListingType) => {
    const key = `${category}:${type}`;
    setSelectedInterests(prev => {
      const newSet = new Set(prev);
      if (newSet.has(key)) {
        newSet.delete(key);
      } else {
        newSet.add(key);
      }
      return newSet;
    });
  };

  const isSelected = (category: string, type: ListingType): boolean => {
    return selectedInterests.has(`${category}:${type}`);
  };

  const handleSkip = () => {
    // Skip to main app without saving interests
    console.log('🔄 User skipped interest selection');
    // Navigation will be handled by auth state change
  };

  const handleContinue = async () => {
    if (selectedInterests.size === 0) {
      // Allow continuing without selecting interests
      handleSkip();
      return;
    }

    setIsSaving(true);

    try {
      // Convert Set to array of interest objects
      const interests = Array.from(selectedInterests).map(key => {
        const [category, type] = key.split(':');
        return {
          category,
          listing_type: type as ListingType,
        };
      });

      await saveUserInterests(interests);
      console.log('✅ Interests saved successfully');
      
      // Navigation will be handled by auth state change
    } catch (error: any) {
      console.error('❌ Error saving interests:', error);
      Alert.alert(
        'Error',
        'Failed to save interests. You can set them later in Settings.',
        [
          {
            text: 'OK',
            onPress: handleSkip,
          },
        ]
      );
    } finally {
      setIsSaving(false);
    }
  };

  const renderCategorySection = (
    title: string,
    icon: keyof typeof Ionicons.glyphMap,
    categories: InterestOption[]
  ) => {
    return (
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Ionicons name={icon} size={24} color={Colors.primary} />
          <Text style={styles.sectionTitle}>{title}</Text>
        </View>
        <View style={styles.grid}>
          {categories.map(option => {
            const selected = isSelected(option.category, option.type);
            return (
              <TouchableOpacity
                key={`${option.category}:${option.type}`}
                style={[styles.card, selected && styles.cardSelected]}
                onPress={() => toggleInterest(option.category, option.type)}
                activeOpacity={0.7}
              >
                <View style={[styles.iconContainer, selected && styles.iconContainerSelected]}>
                  <Ionicons
                    name={option.icon}
                    size={28}
                    color={selected ? Colors.textInverse : Colors.primary}
                  />
                </View>
                <Text style={[styles.cardText, selected && styles.cardTextSelected]}>
                  {option.category}
                </Text>
                {selected && (
                  <View style={styles.checkmark}>
                    <Ionicons name="checkmark-circle" size={24} color={Colors.primary} />
                  </View>
                )}
              </TouchableOpacity>
            );
          })}
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>What are you interested in?</Text>
          <Text style={styles.subtitle}>
            Select categories to personalize your feed. You can always change these later in Settings.
          </Text>
        </View>

        {/* Content */}
        <ScrollView
          style={styles.scrollView}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.scrollContent}
        >
          {/* Products Section */}
          {renderCategorySection('Products', 'bag-outline', PRODUCT_CATEGORIES)}

          {/* Services Section */}
          {renderCategorySection('Services', 'construct-outline', SERVICE_CATEGORIES)}
        </ScrollView>

        {/* Selection Count */}
        {selectedInterests.size > 0 && (
          <View style={styles.selectionCount}>
            <Text style={styles.selectionCountText}>
              {selectedInterests.size} {selectedInterests.size === 1 ? 'interest' : 'interests'} selected
            </Text>
          </View>
        )}

        {/* Action Buttons */}
        <View style={styles.actionButtons}>
          <TouchableOpacity
            style={styles.skipButton}
            onPress={handleSkip}
            disabled={isSaving}
          >
            <Text style={styles.skipButtonText}>Skip for now</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.continueButton,
              selectedInterests.size === 0 && styles.continueButtonDisabled,
            ]}
            onPress={handleContinue}
            disabled={isSaving}
          >
            {isSaving ? (
              <ActivityIndicator color={Colors.textInverse} />
            ) : (
              <Text style={styles.continueButtonText}>
                {selectedInterests.size > 0 ? 'Continue' : 'Skip for now'}
              </Text>
            )}
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  content: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 24,
    paddingTop: 16,
    paddingBottom: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginBottom: 12,
  },
  subtitle: {
    fontSize: 16,
    color: Colors.textSecondary,
    lineHeight: 24,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingBottom: 120,
  },
  section: {
    marginBottom: 32,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginLeft: 12,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -6,
  },
  card: {
    width: '47%',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 16,
    padding: 16,
    marginHorizontal: '1.5%',
    marginBottom: 12,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  cardSelected: {
    borderColor: Colors.primary,
    backgroundColor: Colors.primaryMuted,
  },
  iconContainer: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: Colors.primaryMuted,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  iconContainerSelected: {
    backgroundColor: Colors.primary,
  },
  cardText: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.textPrimary,
    textAlign: 'center',
  },
  cardTextSelected: {
    color: Colors.primary,
  },
  checkmark: {
    position: 'absolute',
    top: 8,
    right: 8,
  },
  selectionCount: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: Colors.surfaceSecondary,
  },
  selectionCountText: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textSecondary,
    textAlign: 'center',
  },
  actionButtons: {
    paddingHorizontal: 24,
    paddingVertical: 16,
    backgroundColor: Colors.background,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
  },
  skipButton: {
    paddingVertical: 12,
    alignItems: 'center',
    marginBottom: 12,
  },
  skipButtonText: {
    fontSize: 16,
    color: Colors.textSecondary,
    fontWeight: '600',
  },
  continueButton: {
    backgroundColor: Colors.primary,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  continueButtonDisabled: {
    backgroundColor: Colors.textSecondary,
  },
  continueButtonText: {
    color: Colors.textInverse,
    fontSize: 17,
    fontWeight: '600',
  },
});

export default InterestSelectionScreen;

