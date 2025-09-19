import Foundation
import Supabase

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var notifications: [Notification] = []
    @Published var unreadCount: Int = 0
    @Published var userPreferences: UserNotificationPreferences?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Feature Flag Check
    private var isEnabled: Bool {
        AppConfig.enableNotifications
    }
    
    // MARK: - Notification Management
    
    /// Fetch notifications for the current user
    func fetchNotifications(limit: Int = 50, offset: Int = 0) async {
        guard isEnabled else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [Notification] = try await supabase
                .from("notifications")
                .select("*")
                .order("created_at", ascending: false)
                .limit(limit)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            if offset == 0 {
                notifications = response
            } else {
                notifications.append(contentsOf: response)
            }
            
            updateUnreadCount()
            isLoading = false
            
        } catch {
            #if DEBUG
            print("Failed to fetch notifications: \(error)")
            #endif
            errorMessage = "Failed to load notifications"
            isLoading = false
        }
    }
    
    /// Fetch unread notifications count
    func fetchUnreadCount() async {
        guard isEnabled else { return }
        
        do {
            let response: [Notification] = try await supabase
                .from("notifications")
                .select("id")
                .eq("is_read", value: "false")  // Changed to string
                .execute()
                .value
            
            unreadCount = response.count
            
        } catch {
            #if DEBUG
            print("Failed to fetch unread count: \(error)")
            #endif
        }
    }
    
    /// Mark a notification as read
    func markAsRead(_ notification: Notification) async {
        guard isEnabled, !notification.isRead else { return }
        
        do {
            try await supabase
                .from("notifications")
                .update([
                    "is_read": "true",  // Changed to string
                    "read_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: notification.id.uuidString)
                .execute()
            
            // Update local state
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                var updatedNotification = notification
                // Note: We can't modify the struct directly, so we'll refetch or update the array
                await fetchNotifications()
            }
            
        } catch {
            #if DEBUG
            print("Failed to mark notification as read: \(error)")
            #endif
        }
    }
    
    /// Mark all notifications as read
    func markAllAsRead() async {
        guard isEnabled else { return }
        
        do {
            try await supabase
                .from("notifications")
                .update([
                    "is_read": "true",  // Changed to string
                    "read_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("is_read", value: "false")  // Changed to string
                .execute()
            
            // Update local state
            await fetchNotifications()
            
        } catch {
            #if DEBUG
            print("Failed to mark all notifications as read: \(error)")
            #endif
        }
    }
    
    /// Delete a notification
    func deleteNotification(_ notification: Notification) async {
        guard isEnabled else { return }
        
        do {
            try await supabase
                .from("notifications")
                .delete()
                .eq("id", value: notification.id.uuidString)
                .execute()
            
            // Update local state
            notifications.removeAll { $0.id == notification.id }
            updateUnreadCount()
            
        } catch {
            #if DEBUG
            print("Failed to delete notification: \(error)")
            #endif
        }
    }
    
    /// Create a new notification
    func createNotification(_ notificationCreate: NotificationCreate) async -> Bool {
        guard isEnabled else { return false }
        
        do {
            try await supabase
                .from("notifications")
                .insert(notificationCreate)
                .execute()
            
            // Refresh notifications to include the new one
            await fetchNotifications()
            return true
            
        } catch {
            #if DEBUG
            print("Failed to create notification: \(error)")
            #endif
            return false
        }
    }
    
    // MARK: - Notification Preferences
    
    /// Fetch user notification preferences
    func fetchUserPreferences() async {
        guard isEnabled else { return }
        
        do {
            let response: [UserNotificationPreferences] = try await supabase
                .from("user_notification_preferences")
                .select("*")
                .limit(1)
                .execute()
                .value
            
            userPreferences = response.first
            
            // If no preferences exist, create default ones
            if userPreferences == nil {
                await createDefaultPreferences()
            }
            
        } catch {
            #if DEBUG
            print("Failed to fetch user preferences: \(error)")
            #endif
        }
    }
    
    /// Create default notification preferences for user
    private func createDefaultPreferences() async {
        guard isEnabled else { return }
        
        do {
            let defaultPrefs = UserNotificationPreferences.defaultPreferences
            
            try await supabase
                .from("user_notification_preferences")
                .insert([
                    "push_enabled": "\(defaultPrefs.pushEnabled)",  // Convert to string
                    "push_platform": defaultPrefs.pushPlatform ?? "ios",
                    "order_notifications": "\(defaultPrefs.orderNotifications)",  // Convert to string
                    "message_notifications": "\(defaultPrefs.messageNotifications)",  // Convert to string
                    "payment_notifications": "\(defaultPrefs.paymentNotifications)",  // Convert to string
                    "rating_notifications": "\(defaultPrefs.ratingNotifications)",  // Convert to string
                    "marketplace_notifications": "\(defaultPrefs.marketplaceNotifications)",  // Convert to string
                    "quiet_hours_start": defaultPrefs.quietHoursStart,
                    "quiet_hours_end": defaultPrefs.quietHoursEnd,
                    "timezone": defaultPrefs.timezone,
                    "max_daily_notifications": "\(defaultPrefs.maxDailyNotifications)",  // Convert to string
                    "group_similar_notifications": "\(defaultPrefs.groupSimilarNotifications)"  // Convert to string
                ])
                .execute()
            
            // Fetch the created preferences
            await fetchUserPreferences()
            
        } catch {
            #if DEBUG
            print("Failed to create default preferences: \(error)")
            #endif
        }
    }
    
    /// Update notification preferences
    func updatePreferences(_ update: NotificationPreferencesUpdate) async -> Bool {
        guard isEnabled else { return false }
        
        do {
            var updateData: [String: String] = [:]  // Changed to [String: String]
            
            if let pushEnabled = update.pushEnabled { updateData["push_enabled"] = "\(pushEnabled)" }
            if let pushToken = update.pushToken { updateData["push_token"] = pushToken }
            if let orderNotifications = update.orderNotifications { updateData["order_notifications"] = "\(orderNotifications)" }
            if let messageNotifications = update.messageNotifications { updateData["message_notifications"] = "\(messageNotifications)" }
            if let paymentNotifications = update.paymentNotifications { updateData["payment_notifications"] = "\(paymentNotifications)" }
            if let ratingNotifications = update.ratingNotifications { updateData["rating_notifications"] = "\(ratingNotifications)" }
            if let marketplaceNotifications = update.marketplaceNotifications { updateData["marketplace_notifications"] = "\(marketplaceNotifications)" }
            if let quietHoursStart = update.quietHoursStart { updateData["quiet_hours_start"] = quietHoursStart }
            if let quietHoursEnd = update.quietHoursEnd { updateData["quiet_hours_end"] = quietHoursEnd }
            if let timezone = update.timezone { updateData["timezone"] = timezone }
            if let maxDaily = update.maxDailyNotifications { updateData["max_daily_notifications"] = "\(maxDaily)" }
            if let groupSimilar = update.groupSimilarNotifications { updateData["group_similar_notifications"] = "\(groupSimilar)" }
            
            try await supabase
                .from("user_notification_preferences")
                .update(updateData)
                .execute()
            
            // Refresh preferences
            await fetchUserPreferences()
            return true
            
        } catch {
            #if DEBUG
            print("Failed to update preferences: \(error)")
            #endif
            return false
        }
    }
    
    /// Update push token
    func updatePushToken(_ token: String) async {
        guard isEnabled else { return }
        
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil,
            pushToken: token,
            orderNotifications: nil,
            messageNotifications: nil,
            paymentNotifications: nil,
            ratingNotifications: nil,
            marketplaceNotifications: nil,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            timezone: nil,
            maxDailyNotifications: nil,
            groupSimilarNotifications: nil
        )
        
        await updatePreferences(update)
    }
    
    // MARK: - Notification Filtering
    
    /// Get notifications by category
    func getNotifications(for category: NotificationCategory) -> [Notification] {
        return notifications.filter { $0.type.category == category }
    }
    
    /// Get unread notifications
    func getUnreadNotifications() -> [Notification] {
        return notifications.filter { !$0.isRead }
    }
    
    /// Get recent notifications (within last 24 hours)
    func getRecentNotifications() -> [Notification] {
        let dayAgo = Date().addingTimeInterval(-86400) // 24 hours ago
        return notifications.filter { $0.createdAt > dayAgo }
    }
    
    // MARK: - Helper Methods
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    /// Initialize notification service for a user
    func initialize() async {
        guard isEnabled else { return }
        
        await fetchUserPreferences()
        await fetchNotifications()
    }
    
    /// Clear all cached data
    func clearCache() {
        notifications.removeAll()
        unreadCount = 0
        userPreferences = nil
        errorMessage = nil
    }
    
    // MARK: - Notification Summary
    
    /// Get notification summary for dashboard
    func getNotificationSummary() -> NotificationSummary {
        let unreadNotifications = getUnreadNotifications()
        let totalUnread = unreadNotifications.count
        
        var unreadByCategory: [NotificationCategory: Int] = [:]
        for category in NotificationCategory.allCases {
            let count = unreadNotifications.filter { $0.type.category == category }.count
            if count > 0 {
                unreadByCategory[category] = count
            }
        }
        
        let recentNotifications = Array(getRecentNotifications().prefix(5))
        
        return NotificationSummary(
            totalUnread: totalUnread,
            unreadByCategory: unreadByCategory,
            recentNotifications: recentNotifications
        )
    }
    
    // MARK: - Convenience Methods for Common Notifications
    
    /// Create an order status notification
    func createOrderNotification(
        for userId: String,
        orderId: UUID,
        listingTitle: String,
        status: OrderStatus
    ) async {
        guard isEnabled else { return }
        
        let (type, title, body) = getOrderNotificationContent(status: status, listingTitle: listingTitle)
        
        let notification = NotificationCreate(
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: ["order_id": AnyCodable(orderId.uuidString)],
            scheduledFor: nil,
            orderId: orderId,
            messageId: nil,
            listingId: nil,
            relatedUserId: nil
        )
        
        await createNotification(notification)
    }
    
    /// Create a message notification
    func createMessageNotification(
        for userId: String,
        messageId: UUID,
        senderName: String,
        messagePreview: String
    ) async {
        guard isEnabled else { return }
        
        let notification = NotificationCreate(
            userId: userId,
            type: .newMessage,
            title: "New Message",
            body: "\(senderName): \(messagePreview)",
            data: ["message_id": AnyCodable(messageId.uuidString)],
            scheduledFor: nil,
            orderId: nil,
            messageId: messageId,
            listingId: nil,
            relatedUserId: nil
        )
        
        await createNotification(notification)
    }
    
    private func getOrderNotificationContent(status: OrderStatus, listingTitle: String) -> (NotificationType, String, String) {
        switch status {
        case .placed:
            return (.orderPlaced, "New Order!", "You have a new order for \"\(listingTitle)\"")
        case .sellerConfirmed:
            return (.orderConfirmed, "Order Confirmed!", "Your order for \"\(listingTitle)\" has been confirmed")
        case .inProgress:
            return (.orderInProgress, "Order In Progress", "Your order for \"\(listingTitle)\" is being prepared")
        case .completed:
            return (.orderCompleted, "Order Completed!", "Your order for \"\(listingTitle)\" has been completed")
        case .cancelled:
            return (.orderCancelled, "Order Cancelled", "Your order for \"\(listingTitle)\" has been cancelled")
        default:
            return (.orderPlaced, "Order Update", "Your order for \"\(listingTitle)\" has been updated")
        }
    }
}