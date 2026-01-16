// OTP Verification Screen
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  SafeAreaView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { AuthScreenProps } from '../../navigation/types';
import { verifyEmailAndCompleteSignup } from '../../services/authService';
import Colors from '../../utils/colors';

type Props = AuthScreenProps<'OTPVerification'>;

const OTPVerificationScreen: React.FC<Props> = ({ navigation, route }) => {
  const { email, name, campus } = route.params;
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);

  const handleVerify = async () => {
    if (otp.length < 6) {
      Alert.alert('Error', 'Please enter the 6-digit code');
      return;
    }

    setLoading(true);
    const result = await verifyEmailAndCompleteSignup(email, otp, name, campus);
    setLoading(false);

    if (result.success) {
      console.log('✅ Email verified, navigating to interest selection');
      // Navigate to interest selection screen
      navigation.navigate('InterestSelection');
    } else {
      Alert.alert('Verification Failed', result.error?.message || 'Invalid code');
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>Verify Email</Text>
          <Text style={styles.subtitle}>
            We sent a 6-digit code to{'\n'}
            <Text style={styles.email}>{email}</Text>
          </Text>
        </View>

        {/* OTP Input */}
        <View style={styles.otpContainer}>
          <TextInput
            style={styles.otpInput}
            placeholder="000000"
            placeholderTextColor={Colors.textTertiary}
            value={otp}
            onChangeText={setOtp}
            keyboardType="number-pad"
            maxLength={6}
            textAlign="center"
          />
        </View>

        {/* Verify Button */}
        <TouchableOpacity
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={handleVerify}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color={Colors.textInverse} />
          ) : (
            <Text style={styles.buttonText}>Verify Email</Text>
          )}
        </TouchableOpacity>

        {/* Resend */}
        <View style={styles.resendContainer}>
          <Text style={styles.resendText}>Didn't receive the code? </Text>
          <TouchableOpacity>
            <Text style={styles.resendLink}>Resend</Text>
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
    paddingHorizontal: 24,
    paddingTop: 16,
  },
  header: {
    marginBottom: 40,
  },
  backButton: {
    fontSize: 16,
    color: Colors.primary,
    marginBottom: 24,
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
  email: {
    color: Colors.textPrimary,
    fontWeight: '600',
  },
  otpContainer: {
    marginBottom: 24,
  },
  otpInput: {
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 16,
    paddingHorizontal: 24,
    paddingVertical: 20,
    fontSize: 32,
    fontWeight: '600',
    color: Colors.textPrimary,
    letterSpacing: 12,
  },
  button: {
    backgroundColor: Colors.primary,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  buttonText: {
    color: Colors.textInverse,
    fontSize: 17,
    fontWeight: '600',
  },
  resendContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 24,
  },
  resendText: {
    fontSize: 15,
    color: Colors.textSecondary,
  },
  resendLink: {
    fontSize: 15,
    color: Colors.primary,
    fontWeight: '600',
  },
});

export default OTPVerificationScreen;

