// ShareListingSheet - Reddit-style sharing to Snapchat, Instagram, etc.
import React, { useState, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  Pressable,
  Alert,
  Linking,
  Share,
  Platform,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import ViewShot from 'react-native-view-shot';
import * as MediaLibrary from 'expo-media-library';
import * as FileSystem from 'expo-file-system/legacy';
import RNShare, { Social } from 'react-native-share';
import { CreativeKit } from '@snapchat/snap-kit-react-native';
import ListingStickerView from './ListingStickerView';
import { useColors } from '../context/ThemeContext';

interface ShareListingSheetProps {
  visible: boolean;
  onClose: () => void;
  listingId: string;
  listingTitle: string;
  listingDescription: string;
  listingPrice: string;
  listingImageUrl?: string | null;
}

interface ShareOptionProps {
  icon: string;
  iconColor: string;
  title: string;
  subtitle: string;
  onPress: () => void;
  loading?: boolean;
}

const ShareOption: React.FC<ShareOptionProps> = ({
  icon,
  iconColor,
  title,
  subtitle,
  onPress,
  loading,
}) => {
  const colors = useColors();
  
  return (
    <Pressable
      style={({ pressed }) => [
        styles.shareOption,
        { backgroundColor: pressed ? colors.secondaryBackground : colors.background },
      ]}
      onPress={onPress}
      disabled={loading}
    >
      <View style={[styles.iconContainer, { backgroundColor: `${iconColor}15` }]}>
        {loading ? (
          <ActivityIndicator size="small" color={iconColor} />
        ) : (
          <Ionicons name={icon as any} size={22} color={iconColor} />
        )}
      </View>
      <View style={styles.optionTextContainer}>
        <Text style={[styles.optionTitle, { color: colors.text }]}>{title}</Text>
        <Text style={[styles.optionSubtitle, { color: colors.secondaryText }]}>
          {subtitle}
        </Text>
      </View>
      <Ionicons name="chevron-forward" size={16} color={colors.secondaryText} />
    </Pressable>
  );
};

const ShareListingSheet: React.FC<ShareListingSheetProps> = ({
  visible,
  onClose,
  listingId,
  listingTitle,
  listingDescription,
  listingPrice,
  listingImageUrl,
}) => {
  const colors = useColors();
  const viewShotRef = useRef<ViewShot>(null);
  const [isGenerating, setIsGenerating] = useState(false);
  const [loadingOption, setLoadingOption] = useState<string | null>(null);

  const appStoreUrl = 'https://apps.apple.com/us/app/campuslink-student-market/id6751429664';

  // Generate sticker image from the view
  const generateStickerImage = useCallback(async (): Promise<string | null> => {
    try {
      if (!viewShotRef.current?.capture) {
        console.error('ViewShot ref not available');
        return null;
      }
      
      const uri = await viewShotRef.current.capture();
      console.log('✅ Sticker captured:', uri);
      return uri;
    } catch (error) {
      console.error('Failed to capture sticker:', error);
      return null;
    }
  }, []);

  // Share to Snapchat - Reddit-style (opens camera with sticker)
  // THIS IS THE WORKING VERSION - uses CreativeKit.sharePhoto with base64
  const shareToSnapchat = async () => {
    if (Platform.OS === 'web') {
      Alert.alert('Not Available', 'Snapchat sharing is only available on mobile devices');
      return;
    }

    setLoadingOption('snapchat');
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    try {
      console.log('📸 Generating sticker image...');
      const stickerUri = await generateStickerImage();
      if (!stickerUri) {
        throw new Error('Failed to generate sticker');
      }
      console.log('✅ Sticker URI:', stickerUri);

      // Convert image to base64 for Snap Kit
      console.log('🔄 Converting to base64...');
      const base64Image = await FileSystem.readAsStringAsync(stickerUri, {
        encoding: 'base64',
      });
      console.log('✅ Base64 length:', base64Image.length);

      // Use Snap Kit sharePhoto - this is the method that WORKS
      // The sticker becomes the main content (full screen initially)
      console.log('📤 Calling CreativeKit.sharePhoto...');
      await CreativeKit.sharePhoto({
        content: {
          raw: base64Image, // Base64 without data URI prefix
        },
        attachmentUrl: appStoreUrl,
        caption: `${listingTitle} - ${listingPrice} 📌 Pinch to resize!`,
      });

      console.log('✅ Shared to Snapchat successfully!');
      onClose();
    } catch (error: any) {
      console.error('Snapchat share error:', error);
      
      // Check if user cancelled
      if (error.message?.includes('cancelled') || error.message?.includes('User did not share')) {
        return;
      }
      
      // Fallback: Save to camera roll and prompt user
      console.log('⚠️ CreativeKit failed, falling back to camera roll...');
      try {
        const uri = await generateStickerImage();
        if (uri) {
          await saveAndOpenApp(uri, 'snapchat://');
        }
      } catch (fallbackError) {
        Alert.alert('Error', 'Failed to share to Snapchat. Make sure Snapchat is installed.');
      }
    } finally {
      setLoadingOption(null);
    }
  };

  // Share to Instagram Stories
  const shareToInstagram = async () => {
    if (Platform.OS === 'web') {
      Alert.alert('Not Available', 'Instagram sharing is only available on mobile devices');
      return;
    }

    setLoadingOption('instagram');
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    try {
      const stickerUri = await generateStickerImage();
      if (!stickerUri) {
        throw new Error('Failed to generate sticker');
      }

      // Convert image to base64 for react-native-share
      const base64Image = await FileSystem.readAsStringAsync(stickerUri, {
        encoding: 'base64',
      });

      // Use react-native-share with Instagram Stories
      await RNShare.shareSingle({
        social: Social.InstagramStories,
        stickerImage: `data:image/png;base64,${base64Image}`,
        backgroundBottomColor: '#000000',
        backgroundTopColor: '#000000',
        attributionURL: appStoreUrl,
      });

      console.log('✅ Shared to Instagram Stories via react-native-share');
      onClose();
    } catch (error: any) {
      console.error('Instagram share error:', error);
      
      // Check if user cancelled
      if (error.message?.includes('cancelled') || error.message?.includes('User did not share')) {
        return;
      }
      
      // Fallback: Save to camera roll
      const stickerUri = await generateStickerImage();
      if (stickerUri) {
        await saveAndOpenApp(stickerUri, 'instagram://');
      }
    } finally {
      setLoadingOption(null);
    }
  };

  // Save sticker to camera roll and open app
  const saveAndOpenApp = async (imageUri: string, appScheme: string) => {
    try {
      // Request permissions
      const { status } = await MediaLibrary.requestPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Required', 'Please allow access to save photos');
        return;
      }

      // Save to camera roll
      await MediaLibrary.saveToLibraryAsync(imageUri);
      console.log('✅ Sticker saved to camera roll');

      // Check if app is installed
      const canOpen = await Linking.canOpenURL(appScheme);
      if (canOpen) {
        Alert.alert(
          'Sticker Saved!',
          'Your sticker has been saved to your camera roll. The app will open now - add the sticker from your recent photos.',
          [
            {
              text: 'Open App',
              onPress: async () => {
                await Linking.openURL(appScheme);
                onClose();
              },
            },
            { text: 'Done', style: 'cancel', onPress: onClose },
          ]
        );
      } else {
        Alert.alert(
          'Sticker Saved!',
          'Your sticker has been saved to your camera roll. Open the app and add it from your photos.',
          [{ text: 'Done', onPress: onClose }]
        );
      }
    } catch (error) {
      console.error('Save error:', error);
      Alert.alert('Error', 'Failed to save sticker');
    }
  };

  // Share via system share sheet
  const shareViaSystem = async () => {
    setLoadingOption('system');
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    try {
      await Share.share({
        message: `Check out ${listingTitle} on CampusLink! ${listingPrice}\n\n${appStoreUrl}`,
        title: listingTitle,
      });
    } catch (error) {
      console.error('Share error:', error);
    } finally {
      setLoadingOption(null);
    }
  };

  // Copy link to clipboard
  const copyLink = async () => {
    setLoadingOption('link');
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

    try {
      // Copy to clipboard using Expo
      const Clipboard = await import('expo-clipboard');
      await Clipboard.setStringAsync(appStoreUrl);
      
      Alert.alert('Copied!', 'Link copied to clipboard');
    } catch (error) {
      // Fallback for older versions
      Alert.alert('Link', appStoreUrl);
    } finally {
      setLoadingOption(null);
    }
  };

  // Share via Messages
  const shareViaMessages = async () => {
    setLoadingOption('messages');
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    try {
      const message = `Check out ${listingTitle} on CampusLink! ${listingPrice}\n${appStoreUrl}`;
      const encodedMessage = encodeURIComponent(message);
      const smsUrl = `sms:&body=${encodedMessage}`;
      
      const canOpen = await Linking.canOpenURL(smsUrl);
      if (canOpen) {
        await Linking.openURL(smsUrl);
      } else {
        Alert.alert('Error', 'Unable to open Messages');
      }
    } catch (error) {
      console.error('Messages error:', error);
    } finally {
      setLoadingOption(null);
    }
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <View style={[styles.container, { backgroundColor: colors.background }]}>
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.headerSpacer} />
          <Text style={[styles.headerTitle, { color: colors.text }]}>Share Listing</Text>
          <Pressable style={styles.closeButton} onPress={onClose}>
            <Ionicons name="close-circle" size={28} color={colors.secondaryText} />
          </Pressable>
        </View>

        {/* Success Badge */}
        <View style={styles.successBadge}>
          <View style={styles.successIconOuter}>
            <View style={styles.successIconInner}>
              <Ionicons name="checkmark" size={32} color="#FFFFFF" />
            </View>
          </View>
          <Text style={[styles.successTitle, { color: colors.text }]}>
            Share Your Listing
          </Text>
          <Text style={[styles.successSubtitle, { color: colors.secondaryText }]}>
            Let your friends know what you're selling
          </Text>
        </View>

        {/* Hidden sticker view for capture */}
        <View style={styles.hiddenContainer}>
          <ViewShot
            ref={viewShotRef}
            options={{ format: 'png', quality: 1.0 }}
          >
            <ListingStickerView
              title={listingTitle}
              price={listingPrice}
              description={listingDescription}
              imageUrl={listingImageUrl}
            />
          </ViewShot>
        </View>

        {/* Share Options */}
        <View style={styles.optionsContainer}>
          <ShareOption
            icon="logo-snapchat"
            iconColor="#FFFC00"
            title="Snapchat Stories"
            subtitle="Share as a sticker"
            onPress={shareToSnapchat}
            loading={loadingOption === 'snapchat'}
          />
          
          <View style={[styles.divider, { backgroundColor: colors.border }]} />
          
          <ShareOption
            icon="logo-instagram"
            iconColor="#E1306C"
            title="Instagram Stories"
            subtitle="Share as a sticker"
            onPress={shareToInstagram}
            loading={loadingOption === 'instagram'}
          />
          
          <View style={[styles.divider, { backgroundColor: colors.border }]} />
          
          <ShareOption
            icon="share-outline"
            iconColor="#007AFF"
            title="More Options"
            subtitle="Share via any app"
            onPress={shareViaSystem}
            loading={loadingOption === 'system'}
          />
          
          <View style={[styles.divider, { backgroundColor: colors.border }]} />
          
          <ShareOption
            icon="chatbubble-outline"
            iconColor="#34C759"
            title="Messages"
            subtitle="Send to your contacts"
            onPress={shareViaMessages}
            loading={loadingOption === 'messages'}
          />
          
          <View style={[styles.divider, { backgroundColor: colors.border }]} />
          
          <ShareOption
            icon="link-outline"
            iconColor="#FF9500"
            title="Copy Link"
            subtitle="Copy listing link"
            onPress={copyLink}
            loading={loadingOption === 'link'}
          />
        </View>

        {/* Done Button */}
        <Pressable
          style={[styles.doneButton, { backgroundColor: colors.primary }]}
          onPress={onClose}
        >
          <Text style={styles.doneButtonText}>Done</Text>
        </Pressable>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 20,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: 16,
    paddingBottom: 8,
  },
  headerSpacer: {
    width: 28,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
  },
  closeButton: {
    padding: 4,
  },
  successBadge: {
    alignItems: 'center',
    paddingVertical: 32,
  },
  successIconOuter: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(52, 199, 89, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  successIconInner: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#34C759',
    justifyContent: 'center',
    alignItems: 'center',
  },
  successTitle: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 8,
  },
  successSubtitle: {
    fontSize: 15,
  },
  hiddenContainer: {
    position: 'absolute',
    left: -1000,
    top: -1000,
  },
  optionsContainer: {
    borderRadius: 16,
    overflow: 'hidden',
    marginBottom: 24,
  },
  shareOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 16,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  optionTextContainer: {
    flex: 1,
  },
  optionTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  optionSubtitle: {
    fontSize: 13,
  },
  divider: {
    height: 1,
    marginLeft: 80,
  },
  doneButton: {
    height: 56,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 32,
  },
  doneButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
});

export default ShareListingSheet;

