// Edit Profile Screen - Modern iOS-aligned design
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ScrollView,
  Image,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import * as ImagePicker from 'expo-image-picker';
import { ProfileScreenProps } from '../../navigation/types';
import { supabase } from '../../config/supabase';
import { updateUserProfile } from '../../services/userService';
import { uploadProfilePicture } from '../../services/imageUploadService';
import { User } from '../../types';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows, Layout } from '../../utils/spacing';
import { Button, UserAvatar } from '../../components';

type Props = ProfileScreenProps<'EditProfile'>;

const MAX_NAME_LENGTH = 50;
const MAX_BIO_LENGTH = 150;

const EditProfileScreen: React.FC<Props> = ({ navigation }) => {
  const colors = useColors();
  const [user, setUser] = useState<User | null>(null);
  const [name, setName] = useState('');
  const [bio, setBio] = useState('');
  const [newProfilePic, setNewProfilePic] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);

  // Focus states
  const [focusedField, setFocusedField] = useState<string | null>(null);

  // Load current user data
  useEffect(() => {
    loadUserData();
  }, []);

  // Track changes
  useEffect(() => {
    if (user) {
      const nameChanged = name !== (user.name || '');
      const bioChanged = bio !== (user.bio || '');
      const picChanged = newProfilePic !== null;
      setHasChanges(nameChanged || bioChanged || picChanged);
    }
  }, [name, bio, newProfilePic, user]);

  const loadUserData = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        const { data } = await supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single();
        
        if (data) {
          setUser(data);
          setName(data.name || '');
          setBio(data.bio || '');
        }
      }
    } catch (error) {
      console.error('Error loading user data:', error);
      Alert.alert('Error', 'Failed to load profile data');
    } finally {
      setIsLoading(false);
    }
  };

  const handlePickImage = async () => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }

    Alert.alert('Change Profile Photo', 'Choose an option', [
      {
        text: 'Take Photo',
        onPress: async () => {
          const { status } = await ImagePicker.requestCameraPermissionsAsync();
          if (status !== 'granted') {
            Alert.alert('Permission Required', 'Please allow camera access to take photos.');
            return;
          }
          const result = await ImagePicker.launchCameraAsync({
            allowsEditing: true,
            aspect: [1, 1],
            quality: 0.8,
          });
          if (!result.canceled && result.assets[0]) {
            setNewProfilePic(result.assets[0].uri);
          }
        },
      },
      {
        text: 'Choose from Library',
        onPress: async () => {
          const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
          if (status !== 'granted') {
            Alert.alert('Permission Required', 'Please allow access to your photo library.');
            return;
          }
          const result = await ImagePicker.launchImageLibraryAsync({
            mediaTypes: ImagePicker.MediaTypeOptions.Images,
            allowsEditing: true,
            aspect: [1, 1],
            quality: 0.8,
          });
          if (!result.canceled && result.assets[0]) {
            setNewProfilePic(result.assets[0].uri);
          }
        },
      },
      {
        text: 'Cancel',
        style: 'cancel',
      },
    ]);
  };

  const handleRemovePhoto = () => {
    if (Platform.OS !== 'web') {
      Haptics.selectionAsync();
    }
    
    Alert.alert(
      'Remove Photo',
      'Are you sure you want to remove your profile photo?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: () => {
            setNewProfilePic(''); // Empty string means remove
          },
        },
      ]
    );
  };

  const handleSave = async () => {
    if (!user) return;

    // Validation
    if (!name.trim()) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', 'Name is required');
      return;
    }

    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }

    setIsSaving(true);

    try {
      let profilePicUrl = user.profile_pic;

      // Upload new profile picture if changed
      if (newProfilePic) {
        if (newProfilePic === '') {
          // Remove photo
          profilePicUrl = null;
        } else {
          // Upload new photo
          profilePicUrl = await uploadProfilePicture(newProfilePic, user.id);
        }
      }

      // Update user profile
      await updateUserProfile(user.id, {
        name: name.trim(),
        bio: bio.trim() || null,
        profile_pic: profilePicUrl,
      });

      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }

      Alert.alert('Success', 'Profile updated successfully', [
        {
          text: 'OK',
          onPress: () => navigation.goBack(),
        },
      ]);
    } catch (error: any) {
      console.error('Error updating profile:', error);
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', error.message || 'Failed to update profile');
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancel = () => {
    if (hasChanges) {
      Alert.alert(
        'Discard Changes?',
        'You have unsaved changes. Are you sure you want to go back?',
        [
          { text: 'Keep Editing', style: 'cancel' },
          {
            text: 'Discard',
            style: 'destructive',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } else {
      navigation.goBack();
    }
  };

  // Get display image
  const displayImage = newProfilePic !== null 
    ? (newProfilePic || null)  // Empty string means removed
    : user?.profile_pic;

  if (isLoading) {
    return (
      <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={colors.primary} />
          <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
            Loading profile...
          </Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['bottom']}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.keyboardView}
      >
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Profile Picture Section */}
          <View style={styles.avatarSection}>
            <Pressable onPress={handlePickImage} style={styles.avatarContainer}>
              {displayImage ? (
                <Image source={{ uri: displayImage }} style={styles.avatarImage} />
              ) : (
                <View style={[styles.avatarPlaceholder, { backgroundColor: colors.primary }]}>
                  <Text style={styles.avatarInitial}>
                    {name ? name.charAt(0).toUpperCase() : user?.email?.charAt(0).toUpperCase() || 'U'}
                  </Text>
                </View>
              )}
              <View style={[styles.editBadge, { backgroundColor: colors.primary, borderColor: colors.background }]}>
                <Ionicons name="camera" size={16} color={colors.textInverse} />
              </View>
            </Pressable>

            <View style={styles.photoButtons}>
              <Pressable
                style={[styles.photoButton, { backgroundColor: colors.primaryMuted }]}
                onPress={handlePickImage}
              >
                <Text style={[styles.photoButtonText, { color: colors.primary }]}>
                  Change Photo
                </Text>
              </Pressable>
              
              {(displayImage || user?.profile_pic) && (
                <Pressable
                  style={[styles.photoButton, { backgroundColor: colors.errorLight }]}
                  onPress={handleRemovePhoto}
                >
                  <Text style={[styles.photoButtonText, { color: colors.error }]}>
                    Remove
                  </Text>
                </Pressable>
              )}
            </View>
          </View>

          {/* Form Fields */}
          <View style={styles.formSection}>
            {/* Name Field */}
            <View style={styles.fieldContainer}>
              <Text style={[styles.fieldLabel, { color: colors.textSecondary }]}>
                Name
              </Text>
              <View
                style={[
                  styles.inputContainer,
                  { 
                    backgroundColor: colors.surface,
                    borderColor: focusedField === 'name' ? colors.primary : colors.border,
                  },
                ]}
              >
                <TextInput
                  style={[styles.input, { color: colors.textPrimary }]}
                  value={name}
                  onChangeText={(text) => setName(text.slice(0, MAX_NAME_LENGTH))}
                  placeholder="Enter your name"
                  placeholderTextColor={colors.textTertiary}
                  onFocus={() => setFocusedField('name')}
                  onBlur={() => setFocusedField(null)}
                  autoCapitalize="words"
                  returnKeyType="next"
                  maxLength={MAX_NAME_LENGTH}
                />
              </View>
              <Text style={[styles.charCount, { color: colors.textTertiary }]}>
                {name.length}/{MAX_NAME_LENGTH}
              </Text>
            </View>

            {/* Bio Field */}
            <View style={styles.fieldContainer}>
              <Text style={[styles.fieldLabel, { color: colors.textSecondary }]}>
                Bio
              </Text>
              <View
                style={[
                  styles.inputContainer,
                  styles.bioInputContainer,
                  { 
                    backgroundColor: colors.surface,
                    borderColor: focusedField === 'bio' ? colors.primary : colors.border,
                  },
                ]}
              >
                <TextInput
                  style={[styles.input, styles.bioInput, { color: colors.textPrimary }]}
                  value={bio}
                  onChangeText={(text) => setBio(text.slice(0, MAX_BIO_LENGTH))}
                  placeholder="Tell others about yourself"
                  placeholderTextColor={colors.textTertiary}
                  onFocus={() => setFocusedField('bio')}
                  onBlur={() => setFocusedField(null)}
                  multiline
                  numberOfLines={4}
                  textAlignVertical="top"
                  maxLength={MAX_BIO_LENGTH}
                />
              </View>
              <Text style={[styles.charCount, { color: colors.textTertiary }]}>
                {bio.length}/{MAX_BIO_LENGTH}
              </Text>
            </View>

            {/* Read-only fields */}
            <View style={styles.fieldContainer}>
              <Text style={[styles.fieldLabel, { color: colors.textSecondary }]}>
                Email
              </Text>
              <View
                style={[
                  styles.inputContainer,
                  styles.disabledInput,
                  { backgroundColor: colors.surfaceSecondary, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.disabledText, { color: colors.textSecondary }]}>
                  {user?.email || 'No email'}
                </Text>
                <Ionicons name="lock-closed" size={16} color={colors.textTertiary} />
              </View>
              <Text style={[styles.hintText, { color: colors.textTertiary }]}>
                Email cannot be changed
              </Text>
            </View>

            <View style={styles.fieldContainer}>
              <Text style={[styles.fieldLabel, { color: colors.textSecondary }]}>
                Campus
              </Text>
              <View
                style={[
                  styles.inputContainer,
                  styles.disabledInput,
                  { backgroundColor: colors.surfaceSecondary, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.disabledText, { color: colors.textSecondary }]}>
                  {user?.campus || 'No campus'}
                </Text>
                <Ionicons name="school" size={16} color={colors.textTertiary} />
              </View>
              <Text style={[styles.hintText, { color: colors.textTertiary }]}>
                Campus is linked to your .edu email
              </Text>
            </View>
          </View>

          {/* Save Button */}
          <View style={styles.buttonSection}>
            <Button
              title={isSaving ? 'Saving...' : 'Save Changes'}
              onPress={handleSave}
              disabled={!hasChanges || isSaving}
              loading={isSaving}
              variant="primary"
              size="large"
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
  },
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: Spacing['2xl'],
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.md,
  },
  loadingText: {
    ...Typography.body,
  },
  avatarSection: {
    alignItems: 'center',
    paddingVertical: Spacing.xl,
    paddingHorizontal: Spacing.lg,
  },
  avatarContainer: {
    position: 'relative',
    marginBottom: Spacing.md,
  },
  avatarImage: {
    width: 120,
    height: 120,
    borderRadius: 60,
  },
  avatarPlaceholder: {
    width: 120,
    height: 120,
    borderRadius: 60,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarInitial: {
    fontSize: 48,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  editBadge: {
    position: 'absolute',
    bottom: 4,
    right: 4,
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
  },
  photoButtons: {
    flexDirection: 'row',
    gap: Spacing.sm,
    marginTop: Spacing.sm,
  },
  photoButton: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
  },
  photoButtonText: {
    ...Typography.footnoteBold,
  },
  formSection: {
    paddingHorizontal: Spacing.lg,
    gap: Spacing.lg,
  },
  fieldContainer: {
    gap: Spacing.xs,
  },
  fieldLabel: {
    ...Typography.footnoteBold,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginLeft: Spacing.xs,
  },
  inputContainer: {
    borderWidth: 1.5,
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
  },
  bioInputContainer: {
    alignItems: 'flex-start',
    minHeight: 100,
  },
  input: {
    flex: 1,
    ...Typography.body,
    padding: 0,
    paddingVertical: Spacing.xs,
  },
  bioInput: {
    minHeight: 80,
    textAlignVertical: 'top',
  },
  charCount: {
    ...Typography.caption2,
    textAlign: 'right',
    marginTop: 2,
  },
  disabledInput: {
    opacity: 0.7,
  },
  disabledText: {
    flex: 1,
    ...Typography.body,
    paddingVertical: Spacing.xs,
  },
  hintText: {
    ...Typography.caption2,
    marginLeft: Spacing.xs,
  },
  buttonSection: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing['2xl'],
  },
});

export default EditProfileScreen;

