// Edit Interests Screen - Allow users to update their interests from Settings
import React, { useState, useEffect } from 'react';
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
import { useNavigation } from '@react-navigation/native';
import { getUserInterests, updateUserInterests } from '../../services/userInterestService';
import Colors from '../../utils/colors';
import { ListingType } from '../../types/product';

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

const EditInterestsScreen: React.FC = () => {
  const navigation = useNavigation();
  const [selectedInterests, setSelectedInterests] = useState<Set<string>>(new Set());
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadCurrentInterests();
  }, []);

  const loadCurrentInterests = async () => {
    try {
      setIsLoading(true);
      const interests = await getUserInterests();
      
      const interestKeys = new Set(
        interests.map(interest => `${interest.category}:${interest.listing_type}`)
      );
      
      setSelectedInterests(interestKeys);
      console.log('✅ Loaded user interests:', interestKeys.size);
    } catch (error) {
      console.error('❌ Error loading interests:', error);
      Alert.alert('Error', 'Failed to load your interests');
    } finally {
      setIsLoading(false);
    }
  };

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

  const handleSave = async () => {
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

      await updateUserInterests(interests);
      console.log('✅ Interests updated successfully');
      
      Alert.alert('Success', 'Your interests have been updated!', [
        {
          text: 'OK',
          onPress: () => navigation.goBack(),
        },
      ]);
    } catch (error: any) {
      console.error('❌ Error saving interests:', error);
      Alert.alert('Error', 'Failed to save interests. Please try again.');
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

  if (isLoading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Ionicons name="chevron-back" size={28} color={Colors.primary} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Edit Interests</Text>
          <View style={{ width: 28 }} />
        </View>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={Colors.primary} />
          <Text style={styles.loadingText}>Loading interests...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="chevron-back" size={28} color={Colors.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Edit Interests</Text>
        <TouchableOpacity onPress={handleSave} disabled={isSaving}>
          <Text style={[styles.saveButton, isSaving && styles.saveButtonDisabled]}>
            {isSaving ? 'Saving...' : 'Save'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Content */}
      <ScrollView
        style={styles.scrollView}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        <View style={styles.infoBox}>
          <Ionicons name="information-circle-outline" size={20} color={Colors.primary} />
          <Text style={styles.infoText}>
            Select categories to personalize your feed and discover relevant listings
          </Text>
        </View>

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
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  saveButton: {
    fontSize: 17,
    color: Colors.primary,
    fontWeight: '600',
  },
  saveButtonDisabled: {
    color: Colors.textTertiary,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: Colors.textSecondary,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingVertical: 16,
    paddingBottom: 100,
  },
  infoBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.primaryMuted,
    padding: 16,
    borderRadius: 12,
    marginBottom: 24,
    gap: 12,
  },
  infoText: {
    flex: 1,
    fontSize: 14,
    color: Colors.textPrimary,
    lineHeight: 20,
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
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: Colors.surfaceSecondary,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
  },
  selectionCountText: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.textSecondary,
    textAlign: 'center',
  },
});

export default EditInterestsScreen;

