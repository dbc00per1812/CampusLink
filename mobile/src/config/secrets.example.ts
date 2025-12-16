// Copy this file to secrets.ts and fill in your values
// secrets.ts is gitignored

export type SupabaseEnvironment = 'production' | 'preview';

// 🔧 SWITCH ENVIRONMENT HERE 🔧
export const CURRENT_ENVIRONMENT: SupabaseEnvironment = 'production';

// Supabase Configuration
export const SUPABASE_URL = CURRENT_ENVIRONMENT === 'production'
  ? 'YOUR_PRODUCTION_SUPABASE_URL'
  : 'YOUR_PREVIEW_SUPABASE_URL';

export const SUPABASE_ANON_KEY = CURRENT_ENVIRONMENT === 'production'
  ? 'YOUR_PRODUCTION_ANON_KEY'
  : 'YOUR_PREVIEW_ANON_KEY';

// Third-Party Keys
// Stripe Publishable Key (starts with pk_test_ for test mode, pk_live_ for production)
// Get from: https://dashboard.stripe.com/apikeys
export const STRIPE_PUBLISHABLE_KEY = 'YOUR_STRIPE_PUBLISHABLE_KEY';

export const ONESIGNAL_APP_ID = 'YOUR_ONESIGNAL_APP_ID';

// Environment helpers
export const isPreview = (CURRENT_ENVIRONMENT as SupabaseEnvironment) === 'preview';
export const environmentName = (CURRENT_ENVIRONMENT as SupabaseEnvironment) === 'production' ? 'Production' : 'Preview';

