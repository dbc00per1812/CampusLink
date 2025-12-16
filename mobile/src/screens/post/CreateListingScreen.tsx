// CreateListingScreen - Full listing creation form
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Switch,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import DateTimePicker from '@react-native-community/datetimepicker';
import { Button, ImagePickerComponent, LoadingSpinner } from '../../components';
import { createListing } from '../../services/listingService';
import { uploadMultipleImages } from '../../services/imageUploadService';
import { ListingType, ListingIntent, DeliveryMethod, ServiceLocation, ListingCreate } from '../../types';
import { AppConfig } from '../../config/appConfig';
import Colors from '../../utils/colors';

// Categories
const PRODUCT_CATEGORIES = ['Electronics', 'Books', 'Furniture', 'Clothing', 'Sports', 'Tickets', 'Other'];
const SERVICE_CATEGORIES = ['Tutoring', 'Moving', 'Cleaning', 'Other'];

const CreateListingScreen: React.FC = () => {
  const navigation = useNavigation();

  // Form state
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [price, setPrice] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [customCategory, setCustomCategory] = useState('');
  const [listingType, setListingType] = useState<ListingType>('product');
  const [intent, setIntent] = useState<ListingIntent>('offer');
  
  // Service fields
  const [serviceDuration, setServiceDuration] = useState('');
  const [serviceLocation, setServiceLocation] = useState<ServiceLocation>('on_campus');
  const [serviceAvailability, setServiceAvailability] = useState('');
  
  // Product fields
  const [deliveryMethod, setDeliveryMethod] = useState<DeliveryMethod>('pickup');
  const [quantity, setQuantity] = useState(1);
  const [acceptsOffers, setAcceptsOffers] = useState(false);
  
  // Seek mode fields
  const [budgetMin, setBudgetMin] = useState('');
  const [budgetMax, setBudgetMax] = useState('');
  
  // Date fields
  const [eventDate, setEventDate] = useState(new Date(Date.now() + 24 * 60 * 60 * 1000)); // Tomorrow
  const [expiresDate, setExpiresDate] = useState(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)); // 7 days
  const [showEventDatePicker, setShowEventDatePicker] = useState(false);
  const [showExpiresDatePicker, setShowExpiresDatePicker] = useState(false);
  
  // Images
  const [images, setImages] = useState<string[]>([]);
  
  // UI state
  const [isLoading, setIsLoading] = useState(false);
  const [showCategoryPicker, setShowCategoryPicker] = useState(false);

  // Get current categories based on listing type
  const currentCategories = listingType === 'product' ? PRODUCT_CATEGORIES : SERVICE_CATEGORIES;

  // Placeholders based on intent
  const titlePlaceholder = intent === 'seek'
    ? listingType === 'product' ? 'What do you want to buy?' : 'What service do you need?'
    : listingType === 'product' ? 'What are you selling?' : 'What service are you offering?';

  const descriptionPlaceholder = intent === 'seek'
    ? listingType === 'product' ? 'Describe what you\'re looking for...' : 'Describe the service you need...'
    : listingType === 'product' ? 'Describe your item...' : 'Describe your service...';

  // Validation
  const isFormValid = (): boolean => {
    if (!title.trim() || !description.trim()) return false;
    if (!selectedCategory) return false;
    if (selectedCategory === 'Other' && !customCategory.trim()) return false;
    
    if (intent === 'seek') {
      if (!budgetMax.trim()) return false;
    } else {
      if (!price.trim()) return false;
    }
    
    // Event date is required for tickets
    if (selectedCategory === 'Tickets' && !eventDate) return false;
    
    return true;
  };

  const handleSubmit = async () => {
    if (!isFormValid()) {
      Alert.alert('Missing Information', 'Please fill in all required fields.');
      return;
    }

    // Validate budget for seek
    if (intent === 'seek') {
      const min = budgetMin ? parseFloat(budgetMin) : 0;
      const max = parseFloat(budgetMax);
      if (min > max) {
        Alert.alert('Invalid Budget', 'Minimum budget cannot be greater than maximum budget.');
        return;
      }
    }

    setIsLoading(true);

    try {
      // Upload images first
      let photoUrls: string[] = [];
      if (images.length > 0) {
        const uploadResults = await uploadMultipleImages(images);
        photoUrls = uploadResults.map(r => r.url);
      }

      // Determine expiration date based on listing type
      let expirationDate: string | null = null;
      if (intent === 'seek') {
        expirationDate = expiresDate.toISOString();
      } else if (selectedCategory === 'Tickets') {
        // Tickets expire at the event date
        expirationDate = eventDate.toISOString();
      }

      // Build listing data
      const listingData: ListingCreate = {
        title: title.trim(),
        description: description.trim(),
        category: selectedCategory === 'Other' ? customCategory.trim() : selectedCategory,
        listing_type: listingType,
        intent,
        photo: photoUrls[0] || null,
        photos: photoUrls,
        price: intent === 'offer' ? parseFloat(price) : null,
        budget_min: intent === 'seek' && budgetMin ? parseFloat(budgetMin) : null,
        budget_max: intent === 'seek' ? parseFloat(budgetMax) : null,
        expires_at: expirationDate,
        delivery_method: listingType === 'product' ? deliveryMethod : null,
        quantity_available: listingType === 'product' ? quantity : null,
        accepts_offers: intent === 'offer' ? acceptsOffers : null,
        service_duration: listingType === 'service' ? serviceDuration || null : null,
        service_location: listingType === 'service' ? serviceLocation : null,
        service_availability: listingType === 'service' ? serviceAvailability || null : null,
      };

      await createListing(listingData);

      Alert.alert(
        'Success!',
        intent === 'seek' ? 'Your wanted post has been created.' : 'Your listing has been posted.',
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    } catch (error: any) {
      console.error('Create listing error:', error);
      Alert.alert('Error', error.message || 'Failed to create listing. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Creating listing..." />;
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <KeyboardAvoidingView 
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.flex}
      >
        <ScrollView 
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps="handled"
        >
          {/* Header */}
          <View style={styles.header}>
            <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
              <Ionicons name="chevron-back" size={28} color={Colors.primary} />
            </TouchableOpacity>
            <Text style={styles.headerTitle}>Create Listing</Text>
            <View style={styles.backButton} />
          </View>

          {/* Intent Picker (Seek Mode) */}
          {AppConfig.enableSeekMode && (
            <View style={styles.section}>
              <View style={styles.segmentedControl}>
                <TouchableOpacity
                  style={[styles.segment, intent === 'offer' && styles.segmentActive]}
                  onPress={() => setIntent('offer')}
                >
                  <Text style={[styles.segmentText, intent === 'offer' && styles.segmentTextActive]}>
                    I'm Selling
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.segment, intent === 'seek' && styles.segmentActive]}
                  onPress={() => setIntent('seek')}
                >
                  <Text style={[styles.segmentText, intent === 'seek' && styles.segmentTextActive]}>
                    I'm Looking For
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {/* Images */}
          <View style={styles.section}>
            <Text style={styles.label}>
              Photos <Text style={{color: '#FF0000'}}>*</Text>
            </Text>
            <ImagePickerComponent
              images={images}
              onImagesChange={setImages}
              maxImages={5}
            />
          </View>

          {/* Title */}
          <View style={styles.section}>
            <Text style={styles.label}>Title</Text>
            <TextInput
              style={styles.input}
              value={title}
              onChangeText={setTitle}
              placeholder={titlePlaceholder}
              placeholderTextColor={Colors.textTertiary}
              maxLength={100}
            />
          </View>

          {/* Description */}
          <View style={styles.section}>
            <Text style={styles.label}>Description</Text>
            <TextInput
              style={[styles.input, styles.textArea]}
              value={description}
              onChangeText={setDescription}
              placeholder={descriptionPlaceholder}
              placeholderTextColor={Colors.textTertiary}
              multiline
              numberOfLines={4}
              maxLength={1000}
              textAlignVertical="top"
            />
          </View>

          {/* Listing Type */}
          <View style={styles.section}>
            <Text style={styles.label}>Type</Text>
            <View style={styles.segmentedControl}>
              <TouchableOpacity
                style={[styles.segment, listingType === 'product' && styles.segmentActive]}
                onPress={() => {
                  setListingType('product');
                  setSelectedCategory('');
                }}
              >
                <Ionicons 
                  name="cube-outline" 
                  size={18} 
                  color={listingType === 'product' ? Colors.textInverse : Colors.textSecondary} 
                />
                <Text style={[styles.segmentText, listingType === 'product' && styles.segmentTextActive]}>
                  Product
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.segment, listingType === 'service' && styles.segmentActive]}
                onPress={() => {
                  setListingType('service');
                  setSelectedCategory('');
                }}
              >
                <Ionicons 
                  name="construct-outline" 
                  size={18} 
                  color={listingType === 'service' ? Colors.textInverse : Colors.textSecondary} 
                />
                <Text style={[styles.segmentText, listingType === 'service' && styles.segmentTextActive]}>
                  Service
                </Text>
              </TouchableOpacity>
            </View>
          </View>

          {/* Category */}
          <View style={styles.section}>
            <Text style={styles.label}>
              Category <Text style={{color: '#FF0000'}}>*</Text>
            </Text>
            <View style={styles.categoryGrid}>
              {currentCategories.map((cat) => (
                <TouchableOpacity
                  key={cat}
                  style={[
                    styles.categoryChip,
                    selectedCategory === cat && styles.categoryChipActive,
                  ]}
                  onPress={() => setSelectedCategory(cat)}
                >
                  <Text
                    style={[
                      styles.categoryChipText,
                      selectedCategory === cat && styles.categoryChipTextActive,
                    ]}
                  >
                    {cat}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
            {selectedCategory === 'Other' && (
              <TextInput
                style={[styles.input, styles.customCategoryInput]}
                value={customCategory}
                onChangeText={setCustomCategory}
                placeholder="Enter custom category"
                placeholderTextColor={Colors.textTertiary}
              />
            )}
          </View>

          {/* Price or Budget */}
          {intent === 'offer' ? (
            <View style={styles.section}>
              <Text style={styles.label}>Price</Text>
              <View style={styles.priceInputContainer}>
                <Text style={styles.currencySymbol}>$</Text>
                <TextInput
                  style={styles.priceInput}
                  value={price}
                  onChangeText={setPrice}
                  placeholder="0.00"
                  placeholderTextColor={Colors.textTertiary}
                  keyboardType="decimal-pad"
                />
              </View>
              <Text style={styles.helperText}>Amount you'll receive</Text>
            </View>
          ) : (
            <View style={styles.section}>
              <Text style={styles.label}>Budget Range</Text>
              <View style={styles.budgetRow}>
                <View style={styles.budgetField}>
                  <Text style={styles.subLabel}>Min (optional)</Text>
                  <View style={styles.priceInputContainer}>
                    <Text style={styles.currencySymbol}>$</Text>
                    <TextInput
                      style={styles.priceInput}
                      value={budgetMin}
                      onChangeText={setBudgetMin}
                      placeholder="0"
                      placeholderTextColor={Colors.textTertiary}
                      keyboardType="decimal-pad"
                    />
                  </View>
                </View>
                <View style={styles.budgetField}>
                  <Text style={styles.subLabel}>Max</Text>
                  <View style={styles.priceInputContainer}>
                    <Text style={styles.currencySymbol}>$</Text>
                    <TextInput
                      style={styles.priceInput}
                      value={budgetMax}
                      onChangeText={setBudgetMax}
                      placeholder="0"
                      placeholderTextColor={Colors.textTertiary}
                      keyboardType="decimal-pad"
                    />
                  </View>
                </View>
              </View>
            </View>
          )}

          {/* Accept Offers Toggle (for sell mode only) */}
          {intent === 'offer' && (
            <View style={styles.section}>
              <View style={styles.toggleRow}>
                <View style={styles.toggleLabel}>
                  <Text style={styles.label}>Accept Offers</Text>
                  <Text style={styles.helperText}>Allow buyers to negotiate</Text>
                </View>
                <Switch
                  value={acceptsOffers}
                  onValueChange={setAcceptsOffers}
                  trackColor={{ false: Colors.border, true: Colors.primary }}
                  thumbColor={Colors.background}
                />
              </View>
            </View>
          )}

          {/* Event Date Picker (for Tickets only) */}
          {selectedCategory === 'Tickets' && (
            <View style={styles.section}>
              <Text style={styles.label}>
                Event Date <Text style={{color: '#FF0000'}}>*</Text>
              </Text>
              <TouchableOpacity
                style={styles.dateButton}
                onPress={() => setShowEventDatePicker(true)}
              >
                <Ionicons name="calendar-outline" size={20} color={Colors.textSecondary} />
                <Text style={styles.dateButtonText}>
                  {eventDate.toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric',
                    hour: 'numeric',
                    minute: '2-digit',
                  })}
                </Text>
              </TouchableOpacity>
              {showEventDatePicker && (
                <DateTimePicker
                  value={eventDate}
                  mode="datetime"
                  display={Platform.OS === 'ios' ? 'spinner' : 'default'}
                  onChange={(event, selectedDate) => {
                    setShowEventDatePicker(Platform.OS === 'ios');
                    if (selectedDate) setEventDate(selectedDate);
                  }}
                  minimumDate={new Date()}
                />
              )}
              <Text style={styles.helperText}>
                Ticket will auto-archive after this date
              </Text>
            </View>
          )}

          {/* Delivery Method (products only) */}
          {listingType === 'product' && (
            <View style={styles.section}>
              <Text style={styles.label}>Delivery Method</Text>
              <View style={styles.segmentedControl}>
                <TouchableOpacity
                  style={[styles.segment, deliveryMethod === 'pickup' && styles.segmentActive]}
                  onPress={() => setDeliveryMethod('pickup')}
                >
                  <Text style={[styles.segmentText, deliveryMethod === 'pickup' && styles.segmentTextActive]}>
                    Pickup
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.segment, deliveryMethod === 'delivery' && styles.segmentActive]}
                  onPress={() => setDeliveryMethod('delivery')}
                >
                  <Text style={[styles.segmentText, deliveryMethod === 'delivery' && styles.segmentTextActive]}>
                    Delivery
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.segment, deliveryMethod === 'both' && styles.segmentActive]}
                  onPress={() => setDeliveryMethod('both')}
                >
                  <Text style={[styles.segmentText, deliveryMethod === 'both' && styles.segmentTextActive]}>
                    Both
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {/* Quantity (products only) */}
          {listingType === 'product' && intent === 'offer' && (
            <View style={styles.section}>
              <Text style={styles.label}>Quantity Available</Text>
              <View style={styles.quantityContainer}>
                <TouchableOpacity
                  style={styles.quantityButton}
                  onPress={() => quantity > 1 && setQuantity(quantity - 1)}
                  disabled={quantity <= 1}
                >
                  <Ionicons 
                    name="remove-circle" 
                    size={32} 
                    color={quantity > 1 ? Colors.primary : Colors.textTertiary} 
                  />
                </TouchableOpacity>
                <Text style={styles.quantityText}>{quantity}</Text>
                <TouchableOpacity
                  style={styles.quantityButton}
                  onPress={() => setQuantity(quantity + 1)}
                >
                  <Ionicons name="add-circle" size={32} color={Colors.primary} />
                </TouchableOpacity>
              </View>
            </View>
          )}

          {/* Service-specific fields */}
          {listingType === 'service' && (
            <>
              <View style={styles.section}>
                <Text style={styles.label}>Service Duration</Text>
                <TextInput
                  style={styles.input}
                  value={serviceDuration}
                  onChangeText={setServiceDuration}
                  placeholder="e.g., 1 hour, 2-3 hours, Half day"
                  placeholderTextColor={Colors.textTertiary}
                />
              </View>

              <View style={styles.section}>
                <Text style={styles.label}>Service Location</Text>
                <View style={styles.segmentedControl}>
                  <TouchableOpacity
                    style={[styles.segment, serviceLocation === 'on_campus' && styles.segmentActive]}
                    onPress={() => setServiceLocation('on_campus')}
                  >
                    <Text style={[styles.segmentText, serviceLocation === 'on_campus' && styles.segmentTextActive]}>
                      On Campus
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.segment, serviceLocation === 'off_campus' && styles.segmentActive]}
                    onPress={() => setServiceLocation('off_campus')}
                  >
                    <Text style={[styles.segmentText, serviceLocation === 'off_campus' && styles.segmentTextActive]}>
                      Off Campus
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.segment, serviceLocation === 'remote' && styles.segmentActive]}
                    onPress={() => setServiceLocation('remote')}
                  >
                    <Text style={[styles.segmentText, serviceLocation === 'remote' && styles.segmentTextActive]}>
                      Remote
                    </Text>
                  </TouchableOpacity>
                </View>
              </View>

              <View style={styles.section}>
                <Text style={styles.label}>Availability</Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  value={serviceAvailability}
                  onChangeText={setServiceAvailability}
                  placeholder="e.g., Mon-Fri 9AM-5PM, Weekends only"
                  placeholderTextColor={Colors.textTertiary}
                  multiline
                  numberOfLines={2}
                />
              </View>
            </>
          )}

          {/* Submit Button */}
          <View style={styles.submitSection}>
            <Button
              title={intent === 'seek' ? 'Post Wanted' : 'Post Listing'}
              onPress={handleSubmit}
              disabled={!isFormValid()}
              icon="checkmark-circle"
            />
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  flex: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 40,
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
  backButton: {
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backButtonText: {
    fontSize: 17,
    color: Colors.primary,
    fontWeight: '400',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  section: {
    paddingHorizontal: 16,
    paddingTop: 20,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: Colors.textPrimary,
    marginBottom: 8,
  },
  subLabel: {
    fontSize: 13,
    color: Colors.textSecondary,
    marginBottom: 6,
  },
  input: {
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 16,
    color: Colors.textPrimary,
  },
  textArea: {
    minHeight: 100,
    paddingTop: 14,
  },
  customCategoryInput: {
    marginTop: 12,
  },
  segmentedControl: {
    flexDirection: 'row',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    padding: 4,
  },
  segment: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 10,
    gap: 6,
  },
  segmentActive: {
    backgroundColor: Colors.primary,
  },
  segmentText: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.textSecondary,
  },
  segmentTextActive: {
    color: Colors.textInverse,
  },
  categoryGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  categoryChip: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  categoryChipActive: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  categoryChipText: {
    fontSize: 14,
    color: Colors.textSecondary,
  },
  categoryChipTextActive: {
    color: Colors.textInverse,
    fontWeight: '500',
  },
  priceInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    paddingHorizontal: 16,
  },
  currencySymbol: {
    fontSize: 20,
    color: Colors.textSecondary,
    marginRight: 4,
  },
  priceInput: {
    flex: 1,
    paddingVertical: 14,
    fontSize: 20,
    fontWeight: '600',
    color: Colors.textPrimary,
  },
  helperText: {
    fontSize: 13,
    color: Colors.textTertiary,
    marginTop: 6,
  },
  budgetRow: {
    flexDirection: 'row',
    gap: 12,
  },
  budgetField: {
    flex: 1,
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    padding: 16,
  },
  toggleLabel: {
    flex: 1,
  },
  quantityContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    padding: 16,
    gap: 24,
  },
  quantityButton: {
    padding: 4,
  },
  quantityText: {
    fontSize: 24,
    fontWeight: '700',
    color: Colors.textPrimary,
    minWidth: 50,
    textAlign: 'center',
  },
  submitSection: {
    paddingHorizontal: 16,
    paddingTop: 32,
    paddingBottom: 16,
  },
  dateButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 12,
  },
  dateButtonText: {
    fontSize: 16,
    color: Colors.textPrimary,
    fontWeight: '500',
  },
});

export default CreateListingScreen;
