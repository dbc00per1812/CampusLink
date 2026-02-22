// LegalDocumentScreen - Display legal documents in-app using PDF viewer
// Uses react-native-pdf for reliable PDF rendering
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import Pdf from 'react-native-pdf';
import { useColors } from '../../context/ThemeContext';

type DocumentType = 'terms' | 'privacy' | 'community';

type LegalDocumentRouteParams = {
  LegalDocument: { documentType: DocumentType };
};

const DOCUMENT_TITLES = {
  terms: 'Terms of Service',
  privacy: 'Privacy Policy',
  community: 'Community Guidelines',
};

// PDF assets - loaded from mobile/assets/legal/ folder
const PDF_SOURCES: Record<DocumentType, any> = {
  terms: require('../../../assets/legal/terms.pdf'),
  privacy: require('../../../assets/legal/privacy.pdf'),
  community: require('../../../assets/legal/community-guidelines.pdf'),
};

const LegalDocumentScreen: React.FC = () => {
  const navigation = useNavigation();
  const route = useRoute<RouteProp<LegalDocumentRouteParams, 'LegalDocument'>>();
  const colors = useColors();
  const { documentType } = route.params;
  const [error, setError] = useState<string | null>(null);

  const title = DOCUMENT_TITLES[documentType];
  const pdfSource = PDF_SOURCES[documentType];

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
          <Ionicons name="chevron-back" size={28} color={colors.primary} />
        </TouchableOpacity>
        <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>{title}</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* PDF Content */}
      {error ? (
        <View style={styles.errorContainer}>
          <Ionicons name="document-text-outline" size={48} color={colors.textSecondary} />
          <Text style={[styles.errorText, { color: colors.textSecondary }]}>
            Unable to load document
          </Text>
          <Text style={[styles.errorSubtext, { color: colors.textTertiary }]}>
            {error}
          </Text>
        </View>
      ) : (
        <Pdf
          source={pdfSource}
          style={[styles.pdf, { backgroundColor: colors.background }]}
          onLoadComplete={(numberOfPages) => {
            console.log(`[LegalDocumentScreen] PDF loaded: ${numberOfPages} pages`);
          }}
          onError={(err: Error) => {
            console.error('[LegalDocumentScreen] PDF error:', err);
            setError(err?.message || 'Failed to load PDF');
          }}
          onPressLink={(uri) => {
            console.log(`[LegalDocumentScreen] Link pressed: ${uri}`);
          }}
          trustAllCerts={false}
          enablePaging={false}
          horizontal={false}
          fitPolicy={0}
          spacing={8}
          renderActivityIndicator={() => (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={colors.primary} />
              <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
                Loading document...
              </Text>
            </View>
          )}
        />
      )}
    </SafeAreaView>
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
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
  backButton: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
  },
  pdf: {
    flex: 1,
    width: Dimensions.get('window').width,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 14,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  errorText: {
    fontSize: 18,
    fontWeight: '600',
    marginTop: 16,
    textAlign: 'center',
  },
  errorSubtext: {
    fontSize: 14,
    marginTop: 8,
    textAlign: 'center',
  },
});

export default LegalDocumentScreen;
