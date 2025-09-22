import SwiftUI
import UserNotifications
import Supabase

struct PushNotificationTestView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @StateObject private var notificationService = NotificationService.shared
    @State private var testResult = ""
    @State private var isLoading = false
    @State private var pushToken: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                statusCard
                
                // Push Token Card
                pushTokenCard
                
                // Test Actions
                testActionsCard
                
                // Results
                if !testResult.isEmpty {
                    resultCard
                }
            }
            .padding()
        }
        .navigationTitle("Push Notification Test")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCurrentStatus()
        }
    }
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notification Status", systemImage: "bell.badge")
                .font(.headline)
            
            Divider()
            
            statusRow("Feature Enabled", AppConfig.enableNotifications ? "✅ Yes" : "❌ No")
            statusRow("Permission Status", notificationManager.statusDescription)
            statusRow("Push Token", notificationManager.pushToken != nil ? "✅ Available" : "❌ Not Set")
            statusRow("Can Send", notificationManager.canSendNotifications ? "✅ Yes" : "❌ No")
            
            if let preferences = notificationService.userPreferences {
                statusRow("Push Enabled in DB", preferences.pushEnabled ? "✅ Yes" : "❌ No")
                statusRow("DB Token", preferences.pushToken != nil ? "✅ Saved" : "❌ Not Saved")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var pushTokenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Push Token Details", systemImage: "key")
                .font(.headline)
            
            Divider()
            
            if let token = notificationManager.pushToken {
                Text("Local Token:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(token.prefix(20)) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                
                Button(action: copyToken) {
                    Label("Copy Full Token", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            } else {
                Text("No push token available")
                    .foregroundColor(.secondary)
            }
            
            if let dbToken = notificationService.userPreferences?.pushToken {
                Text("Database Token:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Text(String(dbToken.prefix(20)) + "...")
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var testActionsCard: some View {
        VStack(spacing: 12) {
            Label("Test Actions", systemImage: "wrench")
                .font(.headline)
            
            Divider()
            
            // Request Permissions
            Button(action: requestPermissions) {
                Label("Request Permissions", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(notificationManager.authorizationStatus == .authorized)
            
            // Test Local Notification
            Button(action: testLocalNotification) {
                Label("Test Local Notification", systemImage: "bell")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            // Save Token to Database
            Button(action: saveTokenToDatabase) {
                Label("Save Token to Database", systemImage: "icloud.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(notificationManager.pushToken == nil)
            
            // Test Apple Push Notification (Direct APNs)
            Button(action: testApplePush) {
                Label("Test Apple Push (Direct)", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            
            // Open Settings
            Button(action: openSettings) {
                Label("Open App Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Test Result", systemImage: "doc.text")
                .font(.headline)
            
            Divider()
            
            Text(testResult)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentStatus() async {
        await notificationService.fetchUserPreferences()
        pushToken = notificationManager.pushToken
    }
    
    private func requestPermissions() {
        Task {
            await notificationManager.requestPermissions()
            testResult = "Permission request completed. Status: \(notificationManager.statusDescription)"
        }
    }
    
    private func testLocalNotification() {
        // First check if we have permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    let content = UNMutableNotificationContent()
                    content.title = "Test Local Notification"
                    content.body = "This is a local test notification from CampusLink!"
                    content.sound = .default
                    content.badge = 1
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.testResult = "❌ Local notification failed: \(error.localizedDescription)"
                            } else {
                                self.testResult = "✅ Local notification scheduled! Check in 2 seconds.\nSettings: \(settings)"
                            }
                        }
                    }
                } else {
                    self.testResult = "❌ Notifications not authorized. Status: \(settings.authorizationStatus.rawValue)\nSettings: \(settings)"
                }
            }
        }
    }
    
    private func saveTokenToDatabase() {
        guard let token = notificationManager.pushToken else {
            testResult = "❌ No push token available"
            return
        }
        
        isLoading = true
        Task {
            await notificationService.updatePushToken(token)
            await loadCurrentStatus()
            isLoading = false
            
            if let dbToken = notificationService.userPreferences?.pushToken, dbToken == token {
                testResult = "✅ Token saved to database successfully!"
            } else {
                testResult = "❌ Failed to save token to database"
            }
        }
    }
    
    private func testApplePush() {
        guard let deviceToken = notificationManager.pushToken else {
            testResult = "❌ No push token available. Please save token to database first."
            return
        }
        
        // Convert device token to proper format for APNs
        // Remove spaces and convert to lowercase
        let fullToken = deviceToken.replacingOccurrences(of: " ", with: "").lowercased()
        
        // Log the token for debugging
        print("🔍 Device token length: \(fullToken.count)")
        print("🔍 Device token preview: \(String(fullToken.prefix(20)))...")
        
        isLoading = true
        Task {
            do {
                // Define expected response type
                struct PushNotificationResponse: Codable {
                    let success: Bool
                    let message: String?
                    let error: String?
                    let apns_status: Int?
                    let apns_response: String?
                }
                
                // Call test push function with device token directly
                let response: PushNotificationResponse = try await supabase.functions.invoke(
                    "test-push-direct",
                    options: FunctionInvokeOptions(
                        method: .post,
                        body: [
                            "device_token": fullToken,
                            "title": "Test Push",
                            "body": "This is a test push notification from CampusLink!"
                        ]
                    )
                )
                
                if response.success {
                    testResult = "✅ Apple push sent! \(response.message ?? "")\nAPNs Status: \(response.apns_status ?? 0)\nResponse: \(response.apns_response ?? "")"
                } else {
                    testResult = "❌ Apple push failed: \(response.error ?? "Unknown error")"
                }
                
            } catch {
                testResult = "❌ Apple push error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func copyToken() {
        if let token = notificationManager.pushToken {
            UIPasteboard.general.string = token
            testResult = "✅ Token copied to clipboard"
        }
    }
    
    private func openSettings() {
        notificationManager.openAppSettings()
    }
}

#Preview {
    NavigationStack {
        PushNotificationTestView()
            .environmentObject(NotificationManager.shared)
    }
}
