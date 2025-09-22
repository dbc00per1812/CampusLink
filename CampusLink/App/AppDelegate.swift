import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self
        
        #if DEBUG
        print("🚀 AppDelegate: Application launched")
        #endif
        
        return true
    }
    
    // MARK: - Push Notification Token Handling
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        #if DEBUG
        print("📱 Push Token Received: \(tokenString)")
        #endif
        
        // Update the notification manager with the token
        NotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("❌ Failed to register for remote notifications: \(error)")
        #endif
        
        NotificationManager.shared.didFailToRegisterForRemoteNotifications(with: error)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        #if DEBUG
        print("📬 Notification received in foreground: \(notification.request.content.title)")
        #endif
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        #if DEBUG
        print("📬 Notification tapped: \(response.notification.request.content.title)")
        #endif
        
        // Handle notification tap
        NotificationManager.shared.handleNotificationTap(response.notification)
        
        completionHandler()
    }
}
