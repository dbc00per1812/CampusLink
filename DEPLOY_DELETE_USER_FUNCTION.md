# Deploy Delete User Edge Function

## Quick Summary
The account deletion feature requires a Supabase Edge Function to be deployed. Without it, users will see a helpful error message and be signed out instead.

## 🚀 Deployment Steps

### 1. Go to Supabase Dashboard
Navigate to: https://supabase.com/dashboard and select your CampusLink project

### 2. Create Edge Function
1. Click "Edge Functions" in the left sidebar
2. Click "New function" button
3. Name: `delete_user`

### 3. Copy Function Code
Open the file: `supabase_functions/delete_user/index.ts`

Copy the entire contents and paste it into the Supabase code editor

### 4. Deploy
Click the "Deploy" button

### 5. Verify
The function should now be available at:
```
https://YOUR_PROJECT_REF.functions.supabase.co/delete_user
```

Test by:
1. Opening the CampusLink app
2. Going to Settings
3. Tapping "Delete Account"
4. Confirming deletion

## ✅ What Happens After Deployment

**With Edge Function Deployed:**
- User account is fully deleted from Supabase Auth
- All user data is cleaned up from database
- User is automatically signed out
- Success message shown

**Without Edge Function (Before Deployment):**
- User sees: "Account deletion is temporarily unavailable. You have been signed out. Please contact support at support@campuslink.app to delete your account."
- User is signed out
- Account is NOT deleted (requires manual deletion by support)

## 🔧 What the Function Does

1. Verifies user's JWT token
2. Deletes user data from all database tables:
   - wallet_transactions
   - user_notification_preferences
   - ratings, reports
   - time_slot_bookings, payouts
   - messages, conversations
   - orders, payments, listings
   - disputes
   - wallets
   - users table
3. Deletes user from Supabase Auth (invalidates session)
4. Returns success/failure response

## 📝 Environment Variables

No additional configuration needed. The following are automatically available:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

## 🐛 Troubleshooting

**Error: "Account deletion is temporarily unavailable"**
→ Edge function not deployed. Follow deployment steps above.

**Error: "Authentication error"**
→ User's session is invalid. Sign out and sign in again before deleting.

**Error: "Network error"**
→ Check internet connection and verify Supabase project is active.

## 📚 More Info

See `supabase_functions/delete_user/README.md` for detailed documentation.

