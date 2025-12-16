// Image Upload Service - Handle image uploads to Supabase Storage
import { supabase } from '../config/supabase';
import * as FileSystem from 'expo-file-system';
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
    // Read the file as base64
    const base64 = await FileSystem.readAsStringAsync(localUri, {
      encoding: 'base64',
    });

    // Generate unique filename
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(2, 8);
    const extension = localUri.split('.').pop()?.toLowerCase() || 'jpg';
    const fileName = folder 
      ? `${folder}/${timestamp}_${randomId}.${extension}`
      : `${timestamp}_${randomId}.${extension}`;

    // Determine content type
    const contentType = extension === 'png' ? 'image/png' : 'image/jpeg';

    // Upload to Supabase Storage
    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(fileName, decode(base64), {
        contentType,
        upsert: false,
      });

    if (uploadError) {
      throw uploadError;
    }

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

// Upload multiple images
export const uploadMultipleImages = async (
  localUris: string[],
  bucket: string = 'listings',
  folder: string = ''
): Promise<UploadResult[]> => {
  const results: UploadResult[] = [];

  for (const uri of localUris) {
    const result = await uploadImage(uri, bucket, folder);
    results.push(result);
  }

  return results;
};

// Upload profile picture
export const uploadProfilePicture = async (
  localUri: string,
  userId: string
): Promise<string> => {
  const result = await uploadImage(localUri, 'profile-pics', userId);
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

