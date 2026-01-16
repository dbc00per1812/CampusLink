// Welcome Screen - Matching Swift version design
import React, { useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  StatusBar,
  Animated,
  Image,
  Platform,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { AuthScreenProps } from '../../navigation/types';
import { Typography } from '../../utils/typography';
import { Spacing, BorderRadius, Shadows } from '../../utils/spacing';

type Props = AuthScreenProps<'Welcome'>;

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// iOS-style blue gradient colors (matching Swift version)
const GRADIENT_COLORS = ['#0A84FF', '#007AFF', '#0066CC', '#004999'] as const;

const WelcomeScreen: React.FC<Props> = ({ navigation }) => {
  // Animation values
  const logoScale = useRef(new Animated.Value(0.5)).current;
  const logoOpacity = useRef(new Animated.Value(0)).current;
  const titleOpacity = useRef(new Animated.Value(0)).current;
  const titleTranslateY = useRef(new Animated.Value(30)).current;
  const subtitleOpacity = useRef(new Animated.Value(0)).current;
  const subtitleTranslateY = useRef(new Animated.Value(20)).current;
  const buttonsOpacity = useRef(new Animated.Value(0)).current;
  const buttonsTranslateY = useRef(new Animated.Value(40)).current;
  const footerOpacity = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Staggered entrance animation
    Animated.sequence([
      // Logo animation
      Animated.parallel([
        Animated.spring(logoScale, {
          toValue: 1,
          tension: 50,
          friction: 7,
          useNativeDriver: true,
        }),
        Animated.timing(logoOpacity, {
          toValue: 1,
          duration: 400,
          useNativeDriver: true,
        }),
      ]),
      // Title animation
      Animated.parallel([
        Animated.timing(titleOpacity, {
          toValue: 1,
          duration: 300,
          useNativeDriver: true,
        }),
        Animated.spring(titleTranslateY, {
          toValue: 0,
          tension: 50,
          friction: 8,
          useNativeDriver: true,
        }),
      ]),
      // Subtitle animation
      Animated.parallel([
        Animated.timing(subtitleOpacity, {
          toValue: 1,
          duration: 300,
          useNativeDriver: true,
        }),
        Animated.spring(subtitleTranslateY, {
          toValue: 0,
          tension: 50,
          friction: 8,
          useNativeDriver: true,
        }),
      ]),
      // Buttons animation
      Animated.parallel([
        Animated.timing(buttonsOpacity, {
          toValue: 1,
          duration: 300,
          useNativeDriver: true,
        }),
        Animated.spring(buttonsTranslateY, {
          toValue: 0,
          tension: 50,
          friction: 8,
          useNativeDriver: true,
        }),
      ]),
      // Footer animation
      Animated.timing(footerOpacity, {
        toValue: 1,
        duration: 400,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  const handleGetStarted = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    navigation.navigate('SignUp');
  };

  const handleSignIn = () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    navigation.navigate('SignIn');
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      {/* Gradient Background - Pure blue gradient matching Swift */}
      <LinearGradient
        colors={GRADIENT_COLORS}
        style={styles.gradient}
        start={{ x: 0.5, y: 0 }}
        end={{ x: 0.5, y: 1 }}
      />
      
      {/* Decorative circles - Matching Swift version positioning */}
      <View style={styles.decorCircle1} />
      <View style={styles.decorCircle2} />

      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        <View style={styles.content}>
          {/* Logo Section */}
          <View style={styles.brandContainer}>
            <Animated.View
              style={[
                styles.logoContainer,
                {
                  opacity: logoOpacity,
                  transform: [{ scale: logoScale }],
                },
              ]}
            >
              <Image
                source={require('../../../assets/brand-icon.png')}
                style={styles.logo}
                resizeMode="contain"
              />
            </Animated.View>
            
            <Animated.Text
              style={[
                styles.title,
                {
                  opacity: titleOpacity,
                  transform: [{ translateY: titleTranslateY }],
                },
              ]}
            >
              CampusLink
            </Animated.Text>
            
            <Animated.Text
              style={[
                styles.subtitle,
                {
                  opacity: subtitleOpacity,
                  transform: [{ translateY: subtitleTranslateY }],
                },
              ]}
            >
              Buy, sell, and connect with{'\n'}your campus community
            </Animated.Text>
          </View>

          {/* Auth Buttons - Matching Swift button styles */}
          <Animated.View
            style={[
              styles.buttonContainer,
              {
                opacity: buttonsOpacity,
                transform: [{ translateY: buttonsTranslateY }],
              },
            ]}
          >
            {/* Primary "Get Started" button - White with blue text */}
            <Pressable
              style={({ pressed }) => [
                styles.primaryButton,
                { opacity: pressed ? 0.9 : 1, transform: [{ scale: pressed ? 0.98 : 1 }] },
              ]}
              onPress={handleGetStarted}
            >
              <Text style={styles.primaryButtonText}>Get Started</Text>
            </Pressable>

            {/* Secondary "Sign In" button - Semi-transparent */}
            <Pressable
              style={({ pressed }) => [
                styles.secondaryButton,
                { opacity: pressed ? 0.8 : 1, transform: [{ scale: pressed ? 0.98 : 1 }] },
              ]}
              onPress={handleSignIn}
            >
              <Text style={styles.secondaryButtonText}>
                Already have an account? Sign In
              </Text>
            </Pressable>
          </Animated.View>

          {/* Footer */}
          <Animated.Text style={[styles.footerText, { opacity: footerOpacity }]}>
            Use your .edu email to join your campus marketplace
          </Animated.Text>
        </View>
      </SafeAreaView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  gradient: {
    ...StyleSheet.absoluteFillObject,
  },
  // Decorative circles matching Swift version
  decorCircle1: {
    position: 'absolute',
    width: SCREEN_WIDTH * 0.9,
    height: SCREEN_WIDTH * 0.9,
    borderRadius: SCREEN_WIDTH * 0.45,
    backgroundColor: 'rgba(255, 255, 255, 0.08)',
    top: SCREEN_HEIGHT * 0.08,
    right: -SCREEN_WIDTH * 0.25,
  },
  decorCircle2: {
    position: 'absolute',
    width: SCREEN_WIDTH * 1.1,
    height: SCREEN_WIDTH * 1.1,
    borderRadius: SCREEN_WIDTH * 0.55,
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    bottom: -SCREEN_WIDTH * 0.3,
    left: -SCREEN_WIDTH * 0.35,
  },
  safeArea: {
    flex: 1,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
  },
  brandContainer: {
    alignItems: 'center',
    marginBottom: Spacing['5xl'],
  },
  logoContainer: {
    marginBottom: Spacing.lg,
  },
  logo: {
    width: 100,
    height: 100,
    borderRadius: 50,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
  },
  title: {
    fontSize: 36,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: Spacing.sm,
    textAlign: 'center',
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 18,
    fontWeight: '400',
    color: 'rgba(255, 255, 255, 0.8)',
    textAlign: 'center',
    lineHeight: 26,
  },
  buttonContainer: {
    width: '100%',
    gap: Spacing.md,
    paddingHorizontal: Spacing.md,
  },
  primaryButton: {
    backgroundColor: '#FFFFFF',
    paddingVertical: 18,
    borderRadius: 14,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  primaryButtonText: {
    fontSize: 17,
    fontWeight: '600',
    color: '#007AFF',
  },
  secondaryButton: {
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    paddingVertical: 18,
    borderRadius: 14,
    alignItems: 'center',
  },
  secondaryButtonText: {
    fontSize: 16,
    fontWeight: '500',
    color: '#FFFFFF',
  },
  footerText: {
    fontSize: 13,
    color: 'rgba(255, 255, 255, 0.5)',
    textAlign: 'center',
    marginTop: Spacing['3xl'],
  },
});

export default WelcomeScreen;
