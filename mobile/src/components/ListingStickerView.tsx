// ListingStickerView - Shareable sticker card for social media
import React, { forwardRef } from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

interface ListingStickerViewProps {
  title: string;
  price: string;
  description: string;
  imageUrl?: string | null;
}

// Using forwardRef so we can capture this view with react-native-view-shot
const ListingStickerView = forwardRef<View, ListingStickerViewProps>(
  ({ title, price, description, imageUrl }, ref) => {
    return (
      <View ref={ref} style={styles.container}>
        {/* Image Area */}
        {imageUrl ? (
          <Image
            source={{ uri: imageUrl }}
            style={styles.image}
            resizeMode="cover"
          />
        ) : (
          <View style={styles.placeholderImage}>
            <Ionicons name="image-outline" size={50} color="rgba(255,255,255,0.6)" />
          </View>
        )}

        {/* Details Section */}
        <View style={styles.detailsContainer}>
          {/* Title and Price */}
          <View style={styles.titlePriceContainer}>
            <Text style={styles.title} numberOfLines={2}>
              {title}
            </Text>
            <Text style={styles.price}>{price}</Text>
          </View>

          {/* Description */}
          {description ? (
            <Text style={styles.description} numberOfLines={2}>
              {description}
            </Text>
          ) : null}

          {/* Divider */}
          <View style={styles.divider} />

          {/* Footer with branding */}
          <View style={styles.footer}>
            <View style={styles.brandContainer}>
              <Ionicons name="school" size={14} color="#007AFF" />
              <Text style={styles.brandText}>CampusLink</Text>
            </View>
            <View style={styles.ctaContainer}>
              <Text style={styles.ctaText}>Tap to Open</Text>
              <Ionicons name="arrow-forward-circle" size={14} color="#007AFF" />
            </View>
          </View>
        </View>
      </View>
    );
  }
);

ListingStickerView.displayName = 'ListingStickerView';

const styles = StyleSheet.create({
  container: {
    width: 300,
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 8,
  },
  image: {
    width: 300,
    height: 250,
  },
  placeholderImage: {
    width: 300,
    height: 250,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  detailsContainer: {
    padding: 18,
  },
  titlePriceContainer: {
    marginBottom: 6,
  },
  title: {
    fontSize: 19,
    fontWeight: '700',
    color: '#000000',
    marginBottom: 6,
  },
  price: {
    fontSize: 24,
    fontWeight: '800',
    color: '#007AFF',
  },
  description: {
    fontSize: 14,
    fontWeight: '400',
    color: '#666666',
    marginTop: 8,
    lineHeight: 20,
  },
  divider: {
    height: 1,
    backgroundColor: 'rgba(0,0,0,0.1)',
    marginVertical: 14,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  brandContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  brandText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#000000',
  },
  ctaContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  ctaText: {
    fontSize: 12,
    fontWeight: '500',
    color: '#007AFF',
  },
});

export default ListingStickerView;

