//
//  CampusLinkTestApp.swift
//  CampusLinkTest
//
//  Created by Eileen Murphy on o   7/26/25.
//

import SwiftUI
import Supabase
import UserNotifications

let supabase = SupabaseClient(  
  supabaseURL: Secrets.supabaseURL,
  supabaseKey: Secrets.supabaseKey
)

@main
struct CampusLinkTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(notificationManager)
                .task {
                    // Initialize notification manager when app launches
                    await notificationManager.initialize()
                    notificationManager.setupNotificationCategories()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)) { _ in
                    // Handle app launch from notification
                    Task {
                        await notificationManager.getCurrentAuthorizationStatus()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Update badge and check for new notifications when app becomes active
                    Task {
                        if AppConfig.enableNotifications {
                            await NotificationService.shared.fetchUnreadCount()
                            notificationManager.updateBadgeCount(NotificationService.shared.unreadCount)
                        }
                    }
                }
                .onOpenURL { url in
                    Task {
                        do {
                            try await supabase.auth.session(from: url)
                            #if DEBUG
                            print("✅ Successfully handled auth URL: \(url)")
                            #endif
                        } catch {
                            #if DEBUG
                            print("❌ Failed to handle auth URL: \(error)")
                            #endif
                        }
                    }
                }
        }
    }
}
