# Delete User Edge Function

This edge function handles account deletion by removing the user from Supabase Auth and cleaning up all related data in the database.

## Deployment Instructions

Since this project doesn't use Docker and deploys edge functions via the Supabase website:

1. **Go to Supabase Dashboard**
   - Navigate to https://supabase.com/dashboard
   - Select your project

2. **Navigate to Edge Functions**
   - Click on "Edge Functions" in the left sidebar
   - Click "New function" button

3. **Create the Function**
   - Name: `delete_user`
   - Copy and paste the contents of `index.ts` into the code editor
   - Click "Deploy"

4. **Verify Deployment**
   - The function should be available at: `https://YOUR_PROJECT_REF.functions.supabase.co/delete_user`
   - Test by attempting to delete an account from the app

## What This Function Does

1. Verifies the user's JWT token
2. Deletes user data from all related tables:
   - wallet_transactions
   - user_notification_preferences
   - ratings, reports
   - time_slot_bookings, payouts
   - messages, conversations
   - orders, payments, listings
   - disputes
   - wallets
   - users table
3. Deletes the user from Supabase Auth (invalidates session)
4. Returns success/failure response

## Required Environment Variables

The following environment variables are automatically available:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

No additional configuration needed.

## Error Handling

If the edge function is not deployed, the app will:
1. Show a user-friendly error message
2. Provide instructions to contact support
3. Sign out the user

## Testing

To test the function:
1. Sign in to the app
2. Go to Settings
3. Tap "Delete Account"
4. Confirm deletion
5. Check the console logs for debugging info

## Troubleshooting

**Error: "Account deletion is temporarily unavailable"**
- The edge function is not deployed
- Deploy the function following the instructions above

**Error: "Authentication error"**
- The user's session is invalid
- Sign out and sign in again before deleting

**Error: "Network error"**
- Check internet connection
- Verify Supabase project is active

