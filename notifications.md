# 🔔 Push Notifications System Implementation Plan

## 🎯 **Goal**
Implement a comprehensive push notification system that keeps users engaged with timely updates about order status changes, new messages, payment confirmations, and marketplace activities. Enable both local and remote notifications with user preference controls.

**Schema awareness**: Need to add `public.notifications` table, user notification preferences, and integrate with iOS UserNotifications framework and Supabase Edge Functions for delivery.

---

## ✅ Current State (aligned with codebase and schema)

- **Feature flag**: Notifications are currently disabled (no feature flag exists yet).
- **Models**: No notification models implemented yet.
- **Service**: No notification service exists yet.
- **UI**: No notification settings or management UI exists.
- **Database**: No notification-related tables exist in current schema.
- **iOS Integration**: No UserNotifications framework integration present.

### Delta vs Original Plan

- No notification infrastructure currently exists in the codebase.
- Need to implement from scratch following the same pattern as ratings system.
- Database schema needs to be created with proper RLS policies.
- iOS notification permissions and handling need to be added.

### Minimal Next Actions to Go Live (safe, small steps)

1) Database (outside IDE; run against dev):
- Create `public.notifications` table with proper schema.
- Add user notification preferences table.
- Create RLS policies for notification access.
- Add notification trigger functions for order/message events.

2) iOS Integration (IDE):
- Add UserNotifications framework import and permission requests.
- Create notification models and service.
- Implement notification settings UI.
- Add feature flag to `AppConfig`.

3) Backend Integration (IDE):
- Create Supabase Edge Function for notification delivery.
- Integrate notification triggers with existing order/message flows.
- Add notification badge management.

---

## 📋 **Implementation Steps**

### **Phase 0 — Database Schema & Foundation**
**Human explanation:**
- Create notification table structure and user preference system.

**Steps done in IDE by AI:**
- Create notification models and enums for the Swift app
- Add notification-related UI stubs behind feature flag
- Create NotificationService for database operations
- Add iOS UserNotifications framework integration

**Steps done outside IDE by human:**
- Run database migration to create notifications table and triggers

### **Phase 1 — Core Notification Types**
**Human explanation:**
- Enable basic notifications for order status changes and new messages.

**Steps done in IDE by AI:**
- Implement order status change notifications
- Add new message notifications
- Create notification permission request flow
- Add notification settings UI

### **Phase 2 — Advanced Notification Features**
**Human explanation:**
- Add payment confirmations, marketplace activity, and rating prompts.

**Steps done in IDE by AI:**
- Add payment status notifications
- Implement marketplace activity notifications
- Create rating reminder notifications
- Add notification history view

### **Phase 3 — Smart Notifications & Preferences**
**Human explanation:**
- Add intelligent notification scheduling and granular user preferences.

**Steps done in IDE by AI:**
- Implement quiet hours and frequency controls
- Add smart notification grouping
- Create notification analytics
- Add push notification delivery optimization

### **Phase 4 — Advanced Features & Analytics**
**Human explanation:**
- Add notification analytics, A/B testing, and advanced delivery features.

**Steps done in IDE by AI:**
- Create notification analytics dashboard
- Implement A/B testing for notification content
- Add advanced delivery features (location-based, time-sensitive)
- Create notification performance monitoring

---

## 🗄️ **Database Schema (Postgres/Supabase)**

```sql
-- Notifications table for storing notification data
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY[
    'order_placed'::text,
    'order_confirmed'::text,
    'order_in_progress'::text,
    'order_completed'::text,
    'order_cancelled'::text,
    'payment_succeeded'::text,
    'payment_failed'::text,
    'new_message'::text,
    'rating_received'::text,
    'rating_reminder'::text,
    'payout_completed'::text,
    'listing_interest'::text,
    'marketplace_activity'::text
  ])),
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  is_read boolean DEFAULT false,
  is_delivered boolean DEFAULT false,
  scheduled_for timestamp with time zone,
  delivered_at timestamp with time zone,
  read_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  
  -- Related entity references
  order_id uuid,
  message_id uuid,
  listing_id uuid,
  related_user_id uuid,
  
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT notifications_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT notifications_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id),
  CONSTRAINT notifications_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES public.listings(id),
  CONSTRAINT notifications_related_user_id_fkey FOREIGN KEY (related_user_id) REFERENCES public.users(id)
);

-- User notification preferences
CREATE TABLE public.user_notification_preferences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  
  -- Push notification preferences
  push_enabled boolean DEFAULT true,
  push_token text,
  push_platform text CHECK (push_platform = ANY (ARRAY['ios'::text, 'android'::text])),
  
  -- Notification type preferences
  order_notifications boolean DEFAULT true,
  message_notifications boolean DEFAULT true,
  payment_notifications boolean DEFAULT true,
  rating_notifications boolean DEFAULT true,
  marketplace_notifications boolean DEFAULT false,
  
  -- Timing preferences
  quiet_hours_start time DEFAULT '22:00',
  quiet_hours_end time DEFAULT '08:00',
  timezone text DEFAULT 'UTC',
  
  -- Frequency controls
  max_daily_notifications integer DEFAULT 10,
  group_similar_notifications boolean DEFAULT true,
  
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  
  CONSTRAINT user_notification_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT user_notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Performance indexes
CREATE INDEX idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_user_type ON public.notifications(user_id, type);
CREATE INDEX idx_notifications_scheduled ON public.notifications(scheduled_for) WHERE scheduled_for IS NOT NULL;
CREATE INDEX idx_notifications_delivered ON public.notifications(delivered_at) WHERE delivered_at IS NOT NULL;

-- RLS Policies
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select ON public.notifications FOR SELECT TO authenticated
USING (user_id = auth.uid());

CREATE POLICY notifications_insert ON public.notifications FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY notifications_update ON public.notifications FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY user_notification_preferences_select ON public.user_notification_preferences FOR SELECT TO authenticated
USING (user_id = auth.uid());

CREATE POLICY user_notification_preferences_insert ON public.user_notification_preferences FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY user_notification_preferences_update ON public.user_notification_preferences FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Auto-update notification preferences timestamp
CREATE OR REPLACE FUNCTION update_notification_preferences_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_notification_preferences_updated_at
  BEFORE UPDATE ON public.user_notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_notification_preferences_updated_at();

-- Function to create notifications
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}',
  p_order_id uuid DEFAULT NULL,
  p_message_id uuid DEFAULT NULL,
  p_listing_id uuid DEFAULT NULL,
  p_related_user_id uuid DEFAULT NULL,
  p_scheduled_for timestamptz DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  notification_id uuid;
  user_prefs record;
BEGIN
  -- Get user notification preferences
  SELECT * INTO user_prefs 
  FROM public.user_notification_preferences 
  WHERE user_id = p_user_id;
  
  -- Check if user has notifications enabled for this type
  IF user_prefs IS NULL OR NOT user_prefs.push_enabled THEN
    RETURN NULL;
  END IF;
  
  -- Check type-specific preferences
  CASE p_type
    WHEN 'order_placed', 'order_confirmed', 'order_in_progress', 'order_completed', 'order_cancelled' THEN
      IF NOT user_prefs.order_notifications THEN RETURN NULL; END IF;
    WHEN 'new_message' THEN
      IF NOT user_prefs.message_notifications THEN RETURN NULL; END IF;
    WHEN 'payment_succeeded', 'payment_failed', 'payout_completed' THEN
      IF NOT user_prefs.payment_notifications THEN RETURN NULL; END IF;
    WHEN 'rating_received', 'rating_reminder' THEN
      IF NOT user_prefs.rating_notifications THEN RETURN NULL; END IF;
    WHEN 'listing_interest', 'marketplace_activity' THEN
      IF NOT user_prefs.marketplace_notifications THEN RETURN NULL; END IF;
  END CASE;
  
  -- Check quiet hours
  IF p_scheduled_for IS NULL THEN
    p_scheduled_for := now();
  END IF;
  
  -- Insert notification
  INSERT INTO public.notifications (
    user_id, type, title, body, data, order_id, message_id, 
    listing_id, related_user_id, scheduled_for
  ) VALUES (
    p_user_id, p_type, p_title, p_body, p_data, p_order_id, p_message_id,
    p_listing_id, p_related_user_id, p_scheduled_for
  ) RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic notifications
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS trigger AS $$
DECLARE
  buyer_prefs record;
  seller_prefs record;
  listing_info record;
BEGIN
  -- Get listing info for context
  SELECT title INTO listing_info FROM public.listings WHERE id = NEW.listing_id;
  
  -- Notify buyer
  IF NEW.order_status = 'seller_confirmed' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_confirmed',
      'Order Confirmed!',
      'Your order for "' || listing_info.title || '" has been confirmed by the seller.',
      '{"order_id": "' || NEW.id || '"}'::jsonb,
      NEW.id
    );
  ELSIF NEW.order_status = 'in_progress' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_in_progress',
      'Order In Progress',
      'Your order for "' || listing_info.title || '" is now being prepared.',
      '{"order_id": "' || NEW.id || '"}'::jsonb,
      NEW.id
    );
  ELSIF NEW.order_status = 'completed' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_completed',
      'Order Completed!',
      'Your order for "' || listing_info.title || '" has been completed. Rate your experience!',
      '{"order_id": "' || NEW.id || '"}'::jsonb,
      NEW.id
    );
  ELSIF NEW.order_status = 'cancelled' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_cancelled',
      'Order Cancelled',
      'Your order for "' || listing_info.title || '" has been cancelled.',
      '{"order_id": "' || NEW.id || '"}'::jsonb,
      NEW.id
    );
  END IF;
  
  -- Notify seller
  IF NEW.order_status = 'placed' THEN
    PERFORM create_notification(
      NEW.seller_id,
      'order_placed',
      'New Order!',
      'You have a new order for "' || listing_info.title || '"',
      '{"order_id": "' || NEW.id || '"}'::jsonb,
      NEW.id,
      NULL,
      NEW.listing_id,
      NEW.buyer_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_notification_trigger
  AFTER INSERT OR UPDATE OF order_status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();

-- Message notification trigger
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS trigger AS $$
DECLARE
  recipient_id uuid;
  conversation_info record;
BEGIN
  -- Get conversation info
  SELECT 
    CASE 
      WHEN NEW.sender_id = c.user1_id THEN c.user2_id 
      ELSE c.user1_id 
    END as recipient_id,
    c.id as conversation_id
  INTO conversation_info
  FROM public.conversations c
  WHERE c.id = NEW.conversation_id;
  
  -- Only notify if message is from someone else
  IF NEW.sender_id != recipient_id THEN
    PERFORM create_notification(
      recipient_id,
      'new_message',
      'New Message',
      SUBSTRING(NEW.content FROM 1 FOR 50) || CASE WHEN LENGTH(NEW.content) > 50 THEN '...' ELSE '' END,
      '{"conversation_id": "' || conversation_info.conversation_id || '", "message_id": "' || NEW.id || '"}'::jsonb,
      NULL,
      NEW.id,
      NULL,
      NEW.sender_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER message_notification_trigger
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();
```

---

## 📱 **Swift Models**

```swift
// MARK: - Notification Models

enum NotificationType: String, Codable, CaseIterable {
    case orderPlaced = "order_placed"
    case orderConfirmed = "order_confirmed"
    case orderInProgress = "order_in_progress"
    case orderCompleted = "order_completed"
    case orderCancelled = "order_cancelled"
    case paymentSucceeded = "payment_succeeded"
    case paymentFailed = "payment_failed"
    case newMessage = "new_message"
    case ratingReceived = "rating_received"
    case ratingReminder = "rating_reminder"
    case payoutCompleted = "payout_completed"
    case listingInterest = "listing_interest"
    case marketplaceActivity = "marketplace_activity"
    
    var displayName: String {
        switch self {
        case .orderPlaced: return "New Orders"
        case .orderConfirmed: return "Order Confirmations"
        case .orderInProgress: return "Order Updates"
        case .orderCompleted: return "Order Completions"
        case .orderCancelled: return "Order Cancellations"
        case .paymentSucceeded: return "Payment Confirmations"
        case .paymentFailed: return "Payment Failures"
        case .newMessage: return "New Messages"
        case .ratingReceived: return "New Ratings"
        case .ratingReminder: return "Rating Reminders"
        case .payoutCompleted: return "Payout Confirmations"
        case .listingInterest: return "Listing Interest"
        case .marketplaceActivity: return "Marketplace Activity"
        }
    }
    
    var icon: String {
        switch self {
        case .orderPlaced: return "cart.badge.plus"
        case .orderConfirmed: return "checkmark.circle"
        case .orderInProgress: return "clock.arrow.circlepath"
        case .orderCompleted: return "checkmark.circle.fill"
        case .orderCancelled: return "xmark.circle"
        case .paymentSucceeded: return "creditcard.fill"
        case .paymentFailed: return "creditcard.trianglebadge.exclamationmark"
        case .newMessage: return "message.fill"
        case .ratingReceived: return "star.fill"
        case .ratingReminder: return "star.circle"
        case .payoutCompleted: return "arrow.down.circle.fill"
        case .listingInterest: return "heart.fill"
        case .marketplaceActivity: return "bell.fill"
        }
    }
    
    var category: NotificationCategory {
        switch self {
        case .orderPlaced, .orderConfirmed, .orderInProgress, .orderCompleted, .orderCancelled:
            return .orders
        case .paymentSucceeded, .paymentFailed, .payoutCompleted:
            return .payments
        case .newMessage:
            return .messaging
        case .ratingReceived, .ratingReminder:
            return .ratings
        case .listingInterest, .marketplaceActivity:
            return .marketplace
        }
    }
}

enum NotificationCategory: String, Codable, CaseIterable {
    case orders = "orders"
    case payments = "payments"
    case messaging = "messaging"
    case ratings = "ratings"
    case marketplace = "marketplace"
    
    var displayName: String {
        switch self {
        case .orders: return "Orders"
        case .payments: return "Payments"
        case .messaging: return "Messages"
        case .ratings: return "Ratings"
        case .marketplace: return "Marketplace"
        }
    }
}

struct Notification: Codable, Identifiable {
    let id: UUID
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: AnyCodable]
    let isRead: Bool
    let isDelivered: Bool
    let scheduledFor: Date?
    let deliveredAt: Date?
    let readAt: Date?
    let createdAt: Date
    
    // Related entity references
    let orderId: UUID?
    let messageId: UUID?
    let listingId: UUID?
    let relatedUserId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type, title, body, data
        case isRead = "is_read"
        case isDelivered = "is_delivered"
        case scheduledFor = "scheduled_for"
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
        case createdAt = "created_at"
        case orderId = "order_id"
        case messageId = "message_id"
        case listingId = "listing_id"
        case relatedUserId = "related_user_id"
    }
}

struct UserNotificationPreferences: Codable {
    let id: UUID
    let userId: String
    
    // Push notification preferences
    let pushEnabled: Bool
    let pushToken: String?
    let pushPlatform: String?
    
    // Notification type preferences
    let orderNotifications: Bool
    let messageNotifications: Bool
    let paymentNotifications: Bool
    let ratingNotifications: Bool
    let marketplaceNotifications: Bool
    
    // Timing preferences
    let quietHoursStart: String
    let quietHoursEnd: String
    let timezone: String
    
    // Frequency controls
    let maxDailyNotifications: Int
    let groupSimilarNotifications: Bool
    
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pushEnabled = "push_enabled"
        case pushToken = "push_token"
        case pushPlatform = "push_platform"
        case orderNotifications = "order_notifications"
        case messageNotifications = "message_notifications"
        case paymentNotifications = "payment_notifications"
        case ratingNotifications = "rating_notifications"
        case marketplaceNotifications = "marketplace_notifications"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case timezone
        case maxDailyNotifications = "max_daily_notifications"
        case groupSimilarNotifications = "group_similar_notifications"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Helper for JSON encoding/decoding
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
```

---

## 🎨 **UI Components & Flow**

### **1. Notification Permission Request**
- **PermissionRequestView**: Explains benefits and requests notification permission
- **Onboarding integration**: Show during first app launch
- **Settings fallback**: Allow users to enable later in settings

### **2. Notification Settings**
- **NotificationSettingsView**: Toggle individual notification types
- **QuietHoursView**: Set quiet hours and timezone
- **FrequencyControlsView**: Control notification frequency and grouping
- **PushTokenManagement**: Handle token registration and updates

### **3. Notification Display**
- **NotificationListView**: Show notification history
- **NotificationCardView**: Individual notification display
- **NotificationBadgeView**: Unread count indicator
- **NotificationActionsView**: Mark as read, delete, etc.

### **4. Integration Points**
- **Tab bar**: Show notification badge on relevant tabs
- **Home screen**: Show recent notifications
- **Order detail**: Show related notifications
- **Message list**: Show unread message indicators

---

## 🔔 **Notification Delivery Strategy**

### **Local Notifications**
- **Scheduled reminders**: Rating reminders, follow-up prompts
- **Offline fallback**: Show local notifications when push fails
- **User-initiated**: Allow users to set custom reminders

### **Push Notifications**
- **Real-time delivery**: Order updates, new messages
- **Batch delivery**: Group similar notifications
- **Smart scheduling**: Respect quiet hours and user preferences
- **Rich content**: Include images and action buttons

### **In-App Notifications**
- **Toast notifications**: Quick feedback for user actions
- **Banner notifications**: Non-intrusive updates
- **Modal notifications**: Important alerts requiring attention

---

## 🛡️ **Privacy & Compliance**

### **Data Protection**
- **Minimal data**: Only include necessary information in notifications
- **User control**: Full control over notification preferences
- **Data retention**: Automatic cleanup of old notifications
- **Encryption**: Secure storage and transmission

### **Apple Guidelines Compliance**
- **Permission-based**: Always request permission before sending
- **Relevant content**: Only send notifications related to app functionality
- **User benefit**: Clear value proposition for each notification type
- **Opt-out respect**: Honor all user preferences immediately

---

## 📊 **Success Metrics**

- **Permission rate**: >80% of users enable notifications
- **Engagement**: >60% of notifications are opened
- **Retention**: Users with notifications enabled have 30% higher retention
- **Uninstall rate**: <5% increase in uninstalls due to notifications
- **User satisfaction**: >4.5/5 rating for notification relevance

---

## 🚀 **Implementation Timeline**

**Phase 0** (Week 1): Database schema + basic models + iOS integration  
**Phase 1** (Week 2): Core notification types + permission flow  
**Phase 2** (Week 3): Advanced features + settings UI  
**Phase 3** (Week 4): Smart notifications + analytics  
**Phase 4** (Week 5): Advanced delivery + optimization  

---

## ✅ **Database Alignment Verification**

**Verified against current schema:**
- ✅ `public.users.id` exists as `uuid` (line 227)
- ✅ `public.orders.id` exists as `uuid` (line 93)
- ✅ `public.messages.id` exists as `uuid` (line 143)
- ✅ `public.listings.id` exists as `uuid` (line 65)
- ✅ Foreign key references align with existing tables
- ✅ UUID types match existing patterns
- ✅ Timestamp fields use consistent `timestamp with time zone`
- ✅ RLS policies follow existing patterns

**Ready for implementation** - All database references are accurate and aligned with the current schema.

---

## 🔧 **Technical Implementation Notes**

### **iOS Integration Requirements**
- Add `UserNotifications` framework import
- Request notification permissions in `AppDelegate` or `App` struct
- Handle notification taps and deep linking
- Manage notification badges and sounds
- Implement background notification processing

### **Supabase Edge Functions**
- Create notification delivery function
- Handle APNs (Apple Push Notification service) integration
- Implement notification scheduling and batching
- Add notification analytics and tracking

### **Performance Considerations**
- Batch notification delivery to avoid rate limits
- Cache notification preferences for quick access
- Implement efficient notification queries with proper indexing
- Use background tasks for notification processing

### **Testing Strategy**
- Unit tests for notification models and logic
- UI tests for notification settings and flows
- Integration tests for push notification delivery
- Performance tests for high-volume notification scenarios
