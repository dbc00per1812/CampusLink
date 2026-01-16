// Image Upload Service - Handle image uploads to Supabase Storage
import { supabase } from '../config/supabase';
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator';
import { decode } from 'base64-arraybuffer';

interface UploadResult {
  url: string;
  path: string;
}

// Upload a single image to Supabase Storage
export const uploadImage = async (
  localUri: string,
  bucket: string = 'listings',
  folder: string = ''
): Promise<UploadResult> => {
  try {
    const startTime = Date.now();
    console.log('📸 Starting image upload:', localUri.substring(localUri.lastIndexOf('/') + 1));
    
    // Compress and get base64 directly from manipulator
    const manipResult = await manipulateAsync(
      localUri,
      [{ resize: { width: 1080, height: 1080 } }],
      { compress: 0.7, format: SaveFormat.JPEG, base64: true }
    );
    
    console.log(`  ✅ Image resized in ${Date.now() - startTime}ms`);
    const uploadStart = Date.now();

    if (!manipResult.base64) {
      throw new Error('Failed to get base64 from image');
    }

    const blobSize = ((manipResult.base64.length * 0.75) / 1024 / 1024).toFixed(2);
    console.log(`  📦 File size: ~${blobSize}MB`);
    
    // Convert base64 to ArrayBuffer for upload
    const arrayBuffer = decode(manipResult.base64);

    // Generate unique filename
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(2, 8);
    const fileName = folder 
      ? `${folder}/${timestamp}_${randomId}.jpg`
      : `${timestamp}_${randomId}.jpg`;

    // Upload to Supabase Storage using binary data
    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(fileName, arrayBuffer, {
        contentType: 'image/jpeg',
        upsert: false,
      });

    if (uploadError) {
      throw uploadError;
    }

    console.log(`  ⬆️  Uploaded in ${Date.now() - uploadStart}ms (total: ${Date.now() - startTime}ms)`);

    // Get public URL
    const { data: urlData } = supabase.storage
      .from(bucket)
      .getPublicUrl(fileName);

    return {
      url: urlData.publicUrl,
      path: fileName,
    };
  } catch (error) {
    console.error('Image upload error:', error);
    throw error;
  }
};

// Upload multiple images in parallel (much faster)
export const uploadMultipleImages = async (
  localUris: string[],
  bucket: string = 'listings',
  folder: string = ''
): Promise<UploadResult[]> => {
  const startTime = Date.now();
  console.log(`🚀 Starting upload of ${localUris.length} images in parallel...`);
  
  // Upload all images in parallel instead of sequentially
  const uploadPromises = localUris.map(uri => uploadImage(uri, bucket, folder));
  const results = await Promise.all(uploadPromises);
  
  console.log(`✅ All ${localUris.length} images uploaded in ${Date.now() - startTime}ms`);
  return results;
};

// Upload profile picture
export const uploadProfilePicture = async (
  localUri: string,
  userId: string
): Promise<string> => {
  const result = await uploadImage(localUri, 'profile-pictures', userId);
  return result.url;
};

// Delete an image from storage
export const deleteImage = async (
  path: string,
  bucket: string = 'listings'
): Promise<void> => {
  const { error } = await supabase.storage.from(bucket).remove([path]);
  if (error) throw error;
};

export default {
  uploadImage,
  uploadMultipleImages,
  uploadProfilePicture,
  deleteImage,
};

