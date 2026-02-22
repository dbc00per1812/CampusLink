// Auth Service - Converted from AuthManager.swift
import { supabase } from '../config/supabase';
import { Session, User as AuthUser } from '@supabase/supabase-js';
import { User } from '../types';
import { SUPABASE_URL } from '../config/secrets';

export type AuthError =
  | 'invalidEmail'
  | 'signUpFailed'
  | 'signInFailed'
  | 'profileUpdateFailed'
  | 'signOutFailed'
  | 'deleteFailed'
  | 'passwordResetFailed'
  | 'emailConfirmationRequired'
  | 'emailConfirmationFailed';

export interface AuthResult<T = void> {
  success: boolean;
  data?: T;
  error?: { type: AuthError; message: string };
}

// Get current session
export const getSession = async (): Promise<Session | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
};

// Get current user ID
export const getCurrentUserId = async (): Promise<string | null> => {
  const session = await getSession();
  return session?.user.id ?? null;
};

// Sign up with email and password
export const signUp = async (
  email: string,
  password: string,
  name: string
): Promise<AuthResult> => {
  // Validate .edu email requirement
  if (!email.toLowerCase().endsWith('.edu')) {
    console.log('❌ Signup rejected: email does not end with .edu');
    return {
      success: false,
      error: {
        type: 'invalidEmail',
        message: 'Please use a valid .edu email address',
      },
    };
  }

  try {
    console.log('🔄 Starting signup process for', email);
    
    // Create the user account
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { name },
      },
    });

    if (authError) throw authError;

    console.log('✅ Auth user created successfully:', authData.user?.id);

    // Sign in immediately
    const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) throw signInError;

    console.log('✅ User signed in successfully:', signInData.user?.id);

    // Ensure user profile exists
    if (signInData.user) {
      try {
        await ensureUserProfileExists(signInData.user.id, email, name);
      } catch (profileError) {
        console.error('❌ Profile creation failed:', profileError);
        return {
          success: false,
          error: {
            type: 'signUpFailed',
            message: 'Failed to create your profile. Please try again or contact support.',
          },
        };
      }
    }

    console.log('🎉 Signup completed successfully!');
    return { success: true };
  } catch (error: any) {
    console.error('❌ Signup error:', error);
    
    if (error.message?.includes('User already registered')) {
      return {
        success: false,
        error: {
          type: 'signUpFailed',
          message: 'User already exists. Try signing in instead.',
        },
      };
    }

    return {
      success: false,
      error: {
        type: 'signUpFailed',
        message: error.message || 'Sign up failed',
      },
    };
  }
};

// Sign up with email confirmation (OTP-based)
export const signUpWithEmailConfirmation = async (
  email: string,
  password: string,
  name: string,
  campus: string
): Promise<AuthResult<boolean>> => {
  // Validate .edu email requirement
  if (!email.toLowerCase().endsWith('.edu')) {
    console.log('❌ Signup rejected: email does not end with .edu');
    return {
      success: false,
      error: {
        type: 'invalidEmail',
        message: 'Please use a valid .edu email address',
      },
    };
  }

  try {
    console.log('🔄 Starting signup with email confirmation for', email);

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { name, campus },
      },
    });

    if (error) throw error;

    console.log('✅ Signup request sent successfully');
    console.log('✅ User email confirmed:', !!data.user?.email_confirmed_at);

    // Check if email confirmation is required
    if (!data.user?.email_confirmed_at) {
      console.log('📧 Email confirmation required');
      return { success: true, data: true }; // true = needs OTP
    } else {
      console.log('⚠️ User already confirmed');
      
      if (data.user) {
        try {
          await ensureUserProfileExists(data.user.id, email, name, campus);
        } catch (profileError) {
          console.error('❌ Profile creation failed:', profileError);
          return {
            success: false,
            error: {
              type: 'signUpFailed',
              message: 'Failed to create your profile. Please try again or contact support.',
            },
          };
        }
      }

      return { success: true, data: false }; // false = auto-confirmed
    }
  } catch (error: any) {
    console.error('❌ Signup with email confirmation failed:', error);
    return {
      success: false,
      error: {
        type: 'signUpFailed',
        message: error.message || 'Sign up failed',
      },
    };
  }
};

// Verify email OTP and complete signup
export const verifyEmailAndCompleteSignup = async (
  email: string,
  otp: string,
  name: string,
  campus: string
): Promise<AuthResult> => {
  // Validate .edu email requirement (defense in depth)
  if (!email.toLowerCase().endsWith('.edu')) {
    console.log('❌ Email verification rejected: email does not end with .edu');
    return {
      success: false,
      error: {
        type: 'invalidEmail',
        message: 'Please use a valid .edu email address',
      },
    };
  }

  try {
    console.log('🔄 Verifying email OTP...');

    const { data, error } = await supabase.auth.verifyOtp({
      email,
      token: otp,
      type: 'signup',
    });

    if (error) throw error;

    console.log('✅ Email OTP verified');

    // Create user profile after successful email verification
    if (data.user) {
      try {
        await ensureUserProfileExists(data.user.id, email, name, campus);
      } catch (profileError) {
        console.error('❌ Profile creation failed:', profileError);
        return {
          success: false,
          error: {
            type: 'emailConfirmationFailed',
            message: 'Failed to create your profile. Please try again or contact support.',
          },
        };
      }
    }

    console.log('✅ Signup completed successfully');
    return { success: true };
  } catch (error: any) {
    console.error('❌ Email verification failed:', error);
    return {
      success: false,
      error: {
        type: 'emailConfirmationFailed',
        message: error.message || 'Email verification failed',
      },
    };
  }
};

// Sign in with email and password
export const signIn = async (
  email: string,
  password: string
): Promise<AuthResult> => {
  try {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) throw error;

    return { success: true };
  } catch (error: any) {
    return {
      success: false,
      error: {
        type: 'signInFailed',
        message: error.message || 'Sign in failed',
      },
    };
  }
};

// Sign out
export const signOut = async (): Promise<AuthResult> => {
  try {
    await supabase.auth.signOut();
    console.log('✅ Sign out successful');
    return { success: true };
  } catch (error: any) {
    console.warn('⚠️ Sign out failed:', error.message);
    // Still treat as success since local session should be cleared
    return { success: true };
  }
};

// Send password reset email
export const resetPassword = async (email: string): Promise<AuthResult> => {
  try {
    console.log('🔄 Sending password reset to', email);

    const { error } = await supabase.auth.resetPasswordForEmail(email);

    if (error) throw error;

    console.log('✅ Password reset email sent successfully');
    return { success: true };
  } catch (error: any) {
    console.error('❌ Password reset failed:', error);
    return {
      success: false,
      error: {
        type: 'passwordResetFailed',
        message: error.message || 'Password reset failed',
      },
    };
  }
};

// Verify OTP and set new password
export const verifyOTPAndResetPassword = async (
  email: string,
  otp: string,
  newPassword: string
): Promise<AuthResult> => {
  try {
    console.log('🔄 Verifying OTP and resetting password...');

    // Verify OTP - this creates an authenticated session
    const { error: verifyError } = await supabase.auth.verifyOtp({
      email,
      token: otp,
      type: 'recovery',
    });

    if (verifyError) throw verifyError;

    // Update password with the authenticated session
    const { error: updateError } = await supabase.auth.updateUser({
      password: newPassword,
    });

    if (updateError) throw updateError;

    console.log('✅ Password updated successfully');
    return { success: true };
  } catch (error: any) {
    console.error('❌ Password reset failed:', error);
    return {
      success: false,
      error: {
        type: 'passwordResetFailed',
        message: error.message || 'Password reset failed',
      },
    };
  }
};

// Delete current user account
export const deleteCurrentUser = async (): Promise<AuthResult> => {
  try {
    console.log('🔄 Starting account deletion process...');

    const session = await getSession();
    if (!session?.access_token) {
      return {
        success: false,
        error: {
          type: 'deleteFailed',
          message: 'No active session. Please sign in again.',
        },
      };
    }

    // Build edge function URL
    const baseUrl = SUPABASE_URL.replace('.supabase.co', '.functions.supabase.co');
    const url = `${baseUrl}/delete_user`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${session.access_token}`,
      },
      body: JSON.stringify({}),
    });

    if (response.ok) {
      console.log('✅ Account deletion successful');
      return { success: true };
    }

    const responseData = await response.json().catch(() => ({}));
    const errorMessage = responseData.error || 'Failed to delete account';
    
    console.error('❌ Delete account failed:', errorMessage);
    return {
      success: false,
      error: {
        type: 'deleteFailed',
        message: errorMessage,
      },
    };
  } catch (error: any) {
    console.error('❌ Account deletion error:', error);
    return {
      success: false,
      error: {
        type: 'deleteFailed',
        message: error.message || 'Failed to delete account',
      },
    };
  }
};

// Helper: Ensure user profile exists in database
const ensureUserProfileExists = async (
  userId: string,
  email: string,
  name: string,
  campus: string = ''
): Promise<void> => {
  const MAX_RETRIES = 3;
  const RETRY_DELAY_MS = 1000;

  console.log('🔧 Ensuring user profile exists for', userId);
  console.log('📍 Campus value being saved:', campus ? `"${campus}"` : '(empty/null)');

  // Retry logic with exponential backoff
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const { error } = await supabase.from('users').insert({
        id: userId,
        email,
        name,
        campus: campus || null,
        campus_email_verified: false,
        trust_score: 100, // Default 5-star rating
      });

      if (error) {
        // Check if user already exists
        if (error.message?.includes('duplicate') || error.message?.includes('unique')) {
          console.log('ℹ️ User profile already exists');
          
          // Update campus if provided
          if (campus) {
            await updateUserCampus(userId, campus);
          }
          return;
        }
        throw error;
      }

      console.log('✅ User profile created successfully');
      
      // Verify campus was saved correctly
      const { data: verifyUser } = await supabase
        .from('users')
        .select('campus')
        .eq('id', userId)
        .single();
      console.log('📍 Verified saved campus:', verifyUser?.campus ? `"${verifyUser.campus}"` : '(null)');

      // Create notification preferences
      await supabase.from('user_notification_preferences').insert({
        user_id: userId,
      });

      console.log('✅ Notification preferences created');
      return; // Success - exit retry loop
    } catch (error) {
      console.error(`❌ Failed to create user profile (attempt ${attempt + 1}/${MAX_RETRIES}):`, error);
      
      // If this is the last attempt, re-throw the error
      if (attempt === MAX_RETRIES - 1) {
        throw error;
      }
      
      // Wait before retrying (exponential backoff)
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS * (attempt + 1)));
    }
  }
};

// Helper: Update user campus
const updateUserCampus = async (userId: string, campus: string): Promise<void> => {
  try {
    await supabase
      .from('users')
      .update({ campus })
      .eq('id', userId);

    console.log('✅ Campus updated successfully');
  } catch (error) {
    console.error('❌ Failed to update campus:', error);
  }
};

// Subscribe to auth state changes
export const onAuthStateChange = (
  callback: (session: Session | null) => void
) => {
  const { data: { subscription } } = supabase.auth.onAuthStateChange(
    (_event, session) => {
      callback(session);
    }
  );
  return subscription;
};

export default {
  getSession,
  getCurrentUserId,
  signUp,
  signUpWithEmailConfirmation,
  verifyEmailAndCompleteSignup,
  signIn,
  signOut,
  resetPassword,
  verifyOTPAndResetPassword,
  deleteCurrentUser,
  onAuthStateChange,
};

