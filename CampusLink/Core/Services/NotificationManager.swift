import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pushToken: String?
    @Published var isInitialized = false
    
    private let notificationService = NotificationService.shared
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Initialization
    
    /// Initialize notification manager and request permissions if needed
    func initialize() async {
        print("🔔 NotificationManager: Starting initialization...")
        print("🔔 AppConfig.enableNotifications: \(AppConfig.enableNotifications)")
        
        guard AppConfig.enableNotifications else { 
            print("🔔 Notifications disabled in AppConfig")
            return 
        }
        
        await getCurrentAuthorizationStatus()
        print("🔔 Current authorization status: \(authorizationStatus)")
        
        if authorizationStatus == .notDetermined {
            print("🔔 Requesting notification permissions...")
            await requestPermissions()
        }
        
        if authorizationStatus == .authorized {
            print("🔔 Registering for push notifications...")
            await registerForPushNotifications()
        }
        
        isInitialized = true
        print("🔔 NotificationManager initialization complete")
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions from user
    func requestPermissions() async {
        guard AppConfig.enableNotifications else { return }
        
        print("🔔 Requesting notification permissions...")
        
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            print("🔔 Permission granted: \(granted)")
            
            await getCurrentAuthorizationStatus()
            print("🔔 New authorization status: \(authorizationStatus)")
            
            if granted {
                print("🔔 Registering for push notifications...")
                await registerForPushNotifications()
            }
            
        } catch {
            print("🔔 Failed to request notification permissions: \(error)")
        }
    }
    
    /// Get current authorization status
    func getCurrentAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    /// Open app settings to allow user to enable notifications
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            return
        }
        
        UIApplication.shared.open(settingsUrl)
    }
    
    // MARK: - Push Notification Registration
    
    /// Register for remote push notifications
    private func registerForPushNotifications() async {
        guard AppConfig.enableNotifications else { return }
        // Must be called on main thread; method is synchronous
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    /// Handle successful push token registration
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        pushToken = tokenString
        
        // Update token in notification service
        Task {
            await notificationService.updatePushToken(tokenString)
        }
        
        #if DEBUG
        print("Push token: \(tokenString)")
        #endif
    }
    
    /// Handle push token registration failure
    func didFailToRegisterForRemoteNotifications(with error: Error) {
        #if DEBUG
        print("Failed to register for remote notifications: \(error)")
        #endif
    }
    
    // MARK: - Local Notifications
    
    /// Schedule a local notification
    func scheduleLocalNotification(_ request: LocalNotificationRequest) async -> Bool {
        guard AppConfig.enableNotifications, authorizationStatus == .authorized else { return false }
        
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo = request.data
        
        if let category = request.category {
            content.categoryIdentifier = category
        }
        
        if let sound = request.sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        } else {
            content.sound = .default
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.scheduledDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let notificationRequest = UNNotificationRequest(
            identifier: request.id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(notificationRequest)
            return true
        } catch {
            #if DEBUG
            print("Failed to schedule local notification: \(error)")
            #endif
            return false
        }
    }
    
    /// Cancel a scheduled local notification
    func cancelLocalNotification(withId id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    /// Cancel all scheduled local notifications
    func cancelAllLocalNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Get pending local notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    // MARK: - Badge Management
    
    /// Update app badge count
    func updateBadgeCount(_ count: Int) {
        guard AppConfig.enableNotifications else { return }
        
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    /// Clear app badge
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Notification Categories & Actions
    
    /// Set up notification categories with actions
    func setupNotificationCategories() {
        guard AppConfig.enableNotifications else { return }
        
        // Order notification actions
        let orderViewAction = UNNotificationAction(
            identifier: "VIEW_ORDER",
            title: "View Order",
            options: [.foreground]
        )
        
        let orderCategory = UNNotificationCategory(
            identifier: "ORDER_NOTIFICATION",
            actions: [orderViewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Message notification actions
        let messageReplyAction = UNNotificationAction(
            identifier: "REPLY_MESSAGE",
            title: "Reply",
            options: [.foreground]
        )
        
        let messageViewAction = UNNotificationAction(
            identifier: "VIEW_MESSAGE",
            title: "View",
            options: [.foreground]
        )
        
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE_NOTIFICATION",
            actions: [messageReplyAction, messageViewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Payment notification actions
        let paymentViewAction = UNNotificationAction(
            identifier: "VIEW_PAYMENT",
            title: "View Details",
            options: [.foreground]
        )
        
        let paymentCategory = UNNotificationCategory(
            identifier: "PAYMENT_NOTIFICATION",
            actions: [paymentViewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Rating notification actions
        let ratingSubmitAction = UNNotificationAction(
            identifier: "SUBMIT_RATING",
            title: "Rate Now",
            options: [.foreground]
        )
        
        let ratingCategory = UNNotificationCategory(
            identifier: "RATING_NOTIFICATION",
            actions: [ratingSubmitAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            orderCategory,
            messageCategory,
            paymentCategory,
            ratingCategory
        ])
    }
    
    // MARK: - Notification Handling
    
    /// Handle notification tap
    func handleNotificationTap(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        // Extract notification data
        if let orderId = userInfo["order_id"] as? String {
            handleOrderNotificationTap(orderId: orderId)
        } else if let messageId = userInfo["message_id"] as? String {
            handleMessageNotificationTap(messageId: messageId)
        } else if let listingId = userInfo["listing_id"] as? String {
            handleListingNotificationTap(listingId: listingId)
        }
        
        // Mark notification as read if it exists in our database
        if let notificationId = userInfo["notification_id"] as? String,
           let uuid = UUID(uuidString: notificationId) {
            Task {
                if let dbNotification = notificationService.notifications.first(where: { $0.id == uuid }) {
                    await notificationService.markAsRead(dbNotification)
                }
            }
        }
    }
    
    private func handleOrderNotificationTap(orderId: String) {
        // TODO: Navigate to order detail view
        #if DEBUG
        print("Tapped order notification: \(orderId)")
        #endif
    }
    
    private func handleMessageNotificationTap(messageId: String) {
        // TODO: Navigate to chat view
        #if DEBUG
        print("Tapped message notification: \(messageId)")
        #endif
    }
    
    private func handleListingNotificationTap(listingId: String) {
        // TODO: Navigate to listing detail view
        #if DEBUG
        print("Tapped listing notification: \(listingId)")
        #endif
    }
    
    // MARK: - Convenience Methods
    
    /// Check if notifications are fully enabled
    var areNotificationsEnabled: Bool {
        AppConfig.enableNotifications && authorizationStatus == .authorized
    }
    
    /// Check if we can send notifications
    var canSendNotifications: Bool {
        AppConfig.enableNotifications && (authorizationStatus == .authorized || authorizationStatus == .provisional)
    }
    
    /// Get user-friendly status description
    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Quiet Hours Support
    
    /// Check if current time is within quiet hours
    func isWithinQuietHours() -> Bool {
        guard let preferences = notificationService.userPreferences else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let startTime = formatter.date(from: preferences.quietHoursStart),
              let endTime = formatter.date(from: preferences.quietHoursEnd) else {
            return false
        }
        
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let currentMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        if startMinutes <= endMinutes {
            // Same day (e.g., 9:00 - 17:00)
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Crosses midnight (e.g., 22:00 - 08:00)
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
    
    /// Schedule notification respecting quiet hours
    func scheduleNotificationRespectingQuietHours(_ request: LocalNotificationRequest) async -> Bool {
        var scheduledDate = request.scheduledDate
        
        // If the scheduled time is within quiet hours, schedule for end of quiet hours
        if isWithinQuietHours(), let preferences = notificationService.userPreferences {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            if let endTime = formatter.date(from: preferences.quietHoursEnd) {
                let calendar = Calendar.current
                let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                
                scheduledDate = calendar.nextDate(
                    after: scheduledDate,
                    matching: endComponents,
                    matchingPolicy: .nextTime
                ) ?? scheduledDate
            }
        }
        
        let updatedRequest = LocalNotificationRequest(
            id: request.id,
            title: request.title,
            body: request.body,
            scheduledDate: scheduledDate,
            data: request.data,
            category: request.category,
            sound: request.sound
        )
        
        return await scheduleLocalNotification(updatedRequest)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationTap(response.notification)
        completionHandler()
    }
}
