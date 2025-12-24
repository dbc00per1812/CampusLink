# OneSignal Push Notification Edge Function

This Supabase Edge Function sends push notifications via OneSignal REST API to React Native mobile app users.

## Setup

### 1. Set Environment Variables

Add these secrets to your Supabase project:

```bash
# OneSignal App ID (from OneSignal dashboard)
ONESIGNAL_APP_ID=cb72afc9-84c6-4cfc-8cc3-64f63d1700c1

# OneSignal REST API Key (from OneSignal Settings > Keys & IDs)
ONESIGNAL_REST_API_KEY=os_v2_app_znzk7smeyzgpzdgdmt3d2fyaygrqwhvvis5ub6e6dzatew45bwht56hbk3ossykighoaexsq3q67qmkrrjb4zwvpaq3hc7bnhdoigey
```

**Via Supabase Dashboard:**
1. Go to Project Settings > Edge Functions > Manage secrets
2. Add both variables

**Via CLI:**
```bash
supabase secrets set ONESIGNAL_APP_ID=cb72afc9-84c6-4cfc-8cc3-64f63d1700c1
supabase secrets set ONESIGNAL_REST_API_KEY=os_v2_app_znzk7smeyzgpzdgdmt3d2fyaygrqwhvvis5ub6e6dzatew45bwht56hbk3ossykighoaexsq3q67qmkrrjb4zwvpaq3hc7bnhdoigey
```

### 2. Deploy Function

```bash
supabase functions deploy send-push-onesignal
```

## Usage

### Send Notification to Single User

```typescript
const { data, error } = await supabase.functions.invoke('send-push-onesignal', {
  body: {
    user_id: 'uuid-here',
    title: 'New Order',
    body: 'You have a new order!',
    data: {
      type: 'order_placed',
      order_id: 'order-uuid',
      screen: 'OrderDetail',
    },
    badge: 1,
    sound: 'default',
    priority: 'high',
  }
});
```

### Payload Schema

```typescript
interface PushNotificationPayload {
  user_id: string;          // Required: Supabase user UUID
  title: string;            // Required: Notification title
  body: string;             // Required: Notification body text
  data?: {                  // Optional: Custom data for navigation
    type?: string;          // Notification type
    order_id?: string;      // Order UUID (if applicable)
    listing_id?: string;    // Listing UUID (if applicable)
    conversation_id?: string;
    message_id?: string;
    screen?: string;        // Screen to navigate to
    params?: any;           // Navigation params
  };
  badge?: number;           // iOS badge count
  sound?: string;           // Sound file name (default: 'default')
  priority?: 'high' | 'normal';  // Notification priority
}
```

## How It Works

1. **User Targeting**: Uses OneSignal external user IDs (Supabase user_id)
2. **Permission Check**: Verifies user has push enabled in `user_notification_preferences`
3. **OneSignal API**: Sends notification via OneSignal REST API
4. **Database Record**: Creates entry in `notifications` table
5. **Platform Handling**: OneSignal routes to APNs (iOS) or FCM (Android) automatically

## Testing

### Test from Supabase SQL Editor

```sql
SELECT
  functions.send_push_onesignal(
    jsonb_build_object(
      'user_id', 'your-user-uuid-here',
      'title', 'Test Notification',
      'body', 'This is a test notification',
      'data', jsonb_build_object('type', 'test')
    )
  );
```

### Test from JavaScript

```javascript
const response = await fetch(
  'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-onesignal',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      user_id: 'test-user-uuid',
      title: 'Test',
      body: 'Testing OneSignal',
    }),
  }
);

const result = await response.json();
console.log(result);
```

## Troubleshooting

### Notification not received

1. **Check user preferences**: Verify `push_enabled = true` in `user_notification_preferences`
2. **Check OneSignal player ID**: Ensure `push_token` exists for user
3. **Check OneSignal dashboard**: View delivery reports
4. **Check device permissions**: User must grant push permissions in app settings
5. **Check external user ID**: Verify user is linked in OneSignal with Supabase user_id

### Function errors

- **Missing credentials**: Ensure environment variables are set
- **User not found**: User must have entry in `user_notification_preferences`
- **OneSignal API error**: Check OneSignal dashboard for API status

## Migration from Expo/APNs

This function replaces:
- `send-push-notification` (Expo-based)
- `process-push-queue` (APNs-based)

Both can coexist during migration period.

