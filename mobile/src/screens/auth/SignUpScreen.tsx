// Sign Up Screen - Modern iOS-aligned design
import React, { useState, useRef, useEffect } from 'react';
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
  Modal,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { AuthScreenProps } from '../../navigation/types';
import { signUpWithEmailConfirmation } from '../../services/authService';
import { getCampusFromEmail, Campus, CampusList, CampusFullName } from '../../types/campus';
import { useColors } from '../../context/ThemeContext';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Layout } from '../../utils/spacing';
import { Button } from '../../components';

type Props = AuthScreenProps<'SignUp'>;

const SignUpScreen: React.FC<Props> = ({ navigation }) => {
  const colors = useColors();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [selectedCampus, setSelectedCampus] = useState<Campus | null>(null);
  const [showCampusPicker, setShowCampusPicker] = useState(false);
  const [termsAccepted, setTermsAccepted] = useState(false);
  
  // Focus states
  const [focusedField, setFocusedField] = useState<string | null>(null);
  
  // Refs
  const emailRef = useRef<TextInput>(null);
  const passwordRef = useRef<TextInput>(null);
  const confirmRef = useRef<TextInput>(null);

  // Auto-select campus based on email domain
  useEffect(() => {
    if (email) {
      const detectedCampus = getCampusFromEmail(email);
      if (detectedCampus && !selectedCampus) {
        setSelectedCampus(detectedCampus);
      }
    }
  }, [email]);

  const handleSignUp = async () => {
    // Validation
    if (!name || !email || !password || !confirmPassword) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', 'Please fill in all fields');
      return;
    }

    if (!email.toLowerCase().endsWith('.edu')) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', 'Please use a valid .edu email address');
      return;
    }

    // Campus validation
    if (!selectedCampus) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', 'Please select your campus');
      return;
    }

    if (password.length < 6) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', 'Password must be at least 6 characters');
      return;
    }

    if (password !== confirmPassword) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', 'Passwords do not match');
      return;
    }

    if (!termsAccepted) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Error', 'Please accept the Terms of Service, Privacy Policy, and Community Guidelines to continue');
      return;
    }

    // Use selected campus instead of getCampusFromEmail
    const campus = selectedCampus;

    setLoading(true);
    const result = await signUpWithEmailConfirmation(email, password, name, campus);
    setLoading(false);

    if (result.success) {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }
      if (result.data === true) {
        navigation.navigate('OTPVerification', { email, name, campus });
      } else {
        Alert.alert('Success', 'Account created successfully!');
      }
    } else {
      if (Platform.OS !== 'web') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
      Alert.alert('Sign Up Failed', result.error?.message || 'Unknown error');
    }
  };

  const renderCampusPicker = () => {
    return (
      <View style={styles.inputContainer}>
        <Text style={[styles.label, { color: colors.textPrimary }]}>
          Campus
        </Text>
        <Pressable
          onPress={() => {
            if (Platform.OS !== 'web') {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
            }
            setShowCampusPicker(true);
          }}
          style={[
            styles.inputWrapper,
            {
              backgroundColor: colors.surfaceSecondary,
              borderColor: 'transparent',
            },
          ]}
        >
          <Ionicons
            name="school-outline"
            size={20}
            color={selectedCampus ? colors.primary : colors.textTertiary}
            style={styles.inputIcon}
          />
          <Text
            style={[
              styles.input,
              {
                color: selectedCampus ? colors.textPrimary : colors.textTertiary,
              },
            ]}
          >
            {selectedCampus ? CampusFullName[selectedCampus] : 'Choose your campus'}
          </Text>
          <Ionicons
            name="chevron-down"
            size={20}
            color={colors.textTertiary}
          />
        </Pressable>
        <Text style={[styles.hint, { color: colors.textTertiary }]}>
          Select your university to connect with your campus
        </Text>
      </View>
    );
  };

  const renderCampusPickerModal = () => {
    return (
      <Modal
        visible={showCampusPicker}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setShowCampusPicker(false)}
      >
        <Pressable
          style={styles.modalOverlay}
          onPress={() => setShowCampusPicker(false)}
        >
          <Pressable
            style={[styles.modalContent, { backgroundColor: colors.surface }]}
            onPress={(e) => e.stopPropagation()}
          >
            <View style={styles.modalHeader}>
              <Text style={[styles.modalTitle, { color: colors.textPrimary }]}>
                Select Your Campus
              </Text>
              <Pressable
                onPress={() => setShowCampusPicker(false)}
                hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
              >
                <Ionicons name="close" size={28} color={colors.textSecondary} />
              </Pressable>
            </View>

            <ScrollView style={styles.campusList}>
              {CampusList.map((campus) => (
                <Pressable
                  key={campus}
                  onPress={() => {
                    if (Platform.OS !== 'web') {
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
                    }
                    setSelectedCampus(campus);
                    setShowCampusPicker(false);
                  }}
                  style={({ pressed }) => [
                    styles.campusOption,
                    {
                      backgroundColor: pressed
                        ? colors.surfaceSecondary
                        : colors.surface,
                    },
                  ]}
                >
                  <View style={styles.campusOptionContent}>
                    <Ionicons
                      name="school"
                      size={24}
                      color={selectedCampus === campus ? colors.primary : colors.textTertiary}
                    />
                    <Text
                      style={[
                        styles.campusOptionText,
                        {
                          color: selectedCampus === campus
                            ? colors.primary
                            : colors.textPrimary,
                          fontWeight: selectedCampus === campus ? '600' : '400',
                        },
                      ]}
                    >
                      {CampusFullName[campus]}
                    </Text>
                  </View>
                  {selectedCampus === campus && (
                    <Ionicons
                      name="checkmark-circle"
                      size={24}
                      color={colors.primary}
                    />
                  )}
                </Pressable>
              ))}
            </ScrollView>
          </Pressable>
        </Pressable>
      </Modal>
    );
  };

  const renderInput = (
    label: string,
    placeholder: string,
    value: string,
    onChangeText: (text: string) => void,
    icon: keyof typeof Ionicons.glyphMap,
    options: {
      ref?: React.RefObject<TextInput>;
      nextRef?: React.RefObject<TextInput>;
      keyboardType?: 'default' | 'email-address';
      autoCapitalize?: 'none' | 'words';
      secureTextEntry?: boolean;
      isPassword?: boolean;
      hint?: string;
    } = {}
  ) => {
    const fieldId = label.toLowerCase();
    const isFocused = focusedField === fieldId;

    return (
      <View style={styles.inputContainer}>
        <Text style={[styles.label, { color: colors.textPrimary }]}>
          {label}
        </Text>
        <View
          style={[
            styles.inputWrapper,
            {
              backgroundColor: colors.surfaceSecondary,
              borderColor: isFocused ? colors.primary : 'transparent',
            },
          ]}
        >
          <Ionicons
            name={icon}
            size={20}
            color={isFocused ? colors.primary : colors.textTertiary}
            style={styles.inputIcon}
          />
          <TextInput
            ref={options.ref}
            style={[styles.input, { color: colors.textPrimary }]}
            placeholder={placeholder}
            placeholderTextColor={colors.textTertiary}
            value={value}
            onChangeText={onChangeText}
            keyboardType={options.keyboardType || 'default'}
            autoCapitalize={options.autoCapitalize || 'none'}
            autoCorrect={false}
            secureTextEntry={options.isPassword && !showPassword}
            returnKeyType={options.nextRef ? 'next' : 'done'}
            onFocus={() => setFocusedField(fieldId)}
            onBlur={() => setFocusedField(null)}
            onSubmitEditing={() => options.nextRef?.current?.focus()}
          />
          {options.isPassword && (
            <Pressable
              onPress={() => setShowPassword(!showPassword)}
              hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            >
              <Ionicons
                name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                size={20}
                color={colors.textTertiary}
              />
            </Pressable>
          )}
        </View>
        {options.hint && (
          <Text style={[styles.hint, { color: colors.textTertiary }]}>
            {options.hint}
          </Text>
        )}
      </View>
    );
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top']}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.keyboardView}
      >
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Header */}
          <View style={styles.header}>
            <Pressable
              onPress={() => navigation.goBack()}
              style={({ pressed }) => [
                styles.backButton,
                { opacity: pressed ? 0.5 : 1 },
              ]}
              hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            >
              <Ionicons name="chevron-back" size={28} color={colors.primary} />
            </Pressable>
            
            <Text style={[styles.title, { color: colors.textPrimary }]}>
              Create Account
            </Text>
            <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
              Join your campus marketplace
            </Text>
          </View>

          {/* Form */}
          <View style={styles.form}>
            {renderInput('Full Name', 'Your name', name, setName, 'person-outline', {
              autoCapitalize: 'words',
              nextRef: emailRef,
            })}
            
            {renderInput('School Email', 'you@university.edu', email, setEmail, 'mail-outline', {
              ref: emailRef,
              keyboardType: 'email-address',
              nextRef: passwordRef,
              hint: 'Use your .edu email to verify your student status',
            })}
            
            {renderCampusPicker()}
            
            {renderInput('Password', 'Create a password', password, setPassword, 'lock-closed-outline', {
              ref: passwordRef,
              isPassword: true,
              nextRef: confirmRef,
            })}
            
            {renderInput('Confirm Password', 'Confirm your password', confirmPassword, setConfirmPassword, 'lock-closed-outline', {
              ref: confirmRef,
              isPassword: true,
            })}

            {/* Terms Acceptance Checkbox */}
            <Pressable
              onPress={() => {
                if (Platform.OS !== 'web') {
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                }
                setTermsAccepted(!termsAccepted);
              }}
              style={styles.termsContainer}
            >
              <View
                style={[
                  styles.checkbox,
                  {
                    backgroundColor: termsAccepted ? colors.primary : 'transparent',
                    borderColor: termsAccepted ? colors.primary : colors.textTertiary,
                  },
                ]}
              >
                {termsAccepted && (
                  <Ionicons name="checkmark" size={16} color="#FFFFFF" />
                )}
              </View>
              <Text style={[styles.termsText, { color: colors.textSecondary }]}>
                I agree to the{' '}
                <Text
                  style={{ color: colors.primary, textDecorationLine: 'underline' }}
                  onPress={() => navigation.navigate('LegalDocument', { documentType: 'terms' })}
                >
                  Terms of Service
                </Text>
                ,{' '}
                <Text
                  style={{ color: colors.primary, textDecorationLine: 'underline' }}
                  onPress={() => navigation.navigate('LegalDocument', { documentType: 'privacy' })}
                >
                  Privacy Policy
                </Text>
                , and{' '}
                <Text
                  style={{ color: colors.primary, textDecorationLine: 'underline' }}
                  onPress={() => navigation.navigate('LegalDocument', { documentType: 'community' })}
                >
                  Community Guidelines
                </Text>
              </Text>
            </Pressable>

            <Button
              title="Create Account"
              onPress={handleSignUp}
              loading={loading}
              variant="primary"
              size="large"
            />
          </View>

          {/* Footer */}
          <View style={styles.footer}>
            <Text style={[styles.footerText, { color: colors.textSecondary }]}>
              Already have an account?{' '}
            </Text>
            <Pressable
              onPress={() => navigation.navigate('SignIn')}
              style={({ pressed }) => [{ opacity: pressed ? 0.5 : 1 }]}
            >
              <Text style={[styles.footerLink, { color: colors.primary }]}>
                Sign In
              </Text>
            </Pressable>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
      
      {/* Campus Picker Modal */}
      {renderCampusPickerModal()}
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
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: Spacing.xl,
  },
  header: {
    marginTop: Spacing.md,
    marginBottom: Spacing.xl,
  },
  backButton: {
    marginBottom: Spacing.xl,
    marginLeft: -Spacing.sm,
  },
  backButtonText: {
    fontSize: 17,
    fontWeight: '400',
  },
  title: {
    ...Typography.largeTitle,
    marginBottom: Spacing.sm,
  },
  subtitle: {
    ...Typography.body,
  },
  form: {
    gap: Spacing.lg,
  },
  inputContainer: {
    gap: Spacing.sm,
  },
  label: {
    ...Typography.subheadlineBold,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.md,
    height: Layout.inputHeightLarge,
    borderWidth: 2,
  },
  inputIcon: {
    marginRight: Spacing.sm,
  },
  input: {
    flex: 1,
    ...Typography.body,
  },
  hint: {
    ...Typography.caption2,
  },
  termsContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
    paddingVertical: Spacing.sm,
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: 6,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 2,
  },
  termsText: {
    ...Typography.caption1,
    flex: 1,
    lineHeight: 20,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 'auto',
    paddingVertical: Spacing.xl,
  },
  footerText: {
    ...Typography.body,
  },
  footerLink: {
    ...Typography.body,
    fontWeight: '600',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    borderTopLeftRadius: BorderRadius.xl,
    borderTopRightRadius: BorderRadius.xl,
    paddingBottom: Platform.OS === 'ios' ? 40 : Spacing.xl,
    maxHeight: '70%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
    paddingVertical: Spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(0, 0, 0, 0.1)',
  },
  modalTitle: {
    ...Typography.title3Bold,
  },
  campusList: {
    paddingHorizontal: Spacing.xl,
  },
  campusOption: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: Spacing.lg,
    paddingHorizontal: Spacing.md,
    borderRadius: BorderRadius.lg,
    marginTop: Spacing.sm,
  },
  campusOptionContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
  },
  campusOptionText: {
    ...Typography.body,
  },
});

export default SignUpScreen;
