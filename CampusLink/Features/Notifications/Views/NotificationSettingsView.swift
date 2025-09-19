import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var isLoading = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                if AppConfig.enableNotifications {
                    permissionSection
                    
                    if notificationManager.areNotificationsEnabled {
                        notificationTypesSection
                        timingSection
                        frequencySection
                    }
                } else {
                    featureDisabledSection
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if AppConfig.enableNotifications {
                    await loadData()
                }
            }
            .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    notificationManager.openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To receive notifications, please enable them in Settings > Notifications > CampusLink")
            }
        }
    }
    
    // MARK: - Sections
    
    private var permissionSection: some View {
        Section {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(notificationManager.areNotificationsEnabled ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Push Notifications")
                        .font(.headline)
                    
                    Text(notificationManager.statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if notificationManager.authorizationStatus == .denied {
                    Button("Enable") {
                        showingPermissionAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                } else if notificationManager.authorizationStatus == .notDetermined {
                    Button("Allow") {
                        Task {
                            await notificationManager.requestPermissions()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Permission")
        } footer: {
            if notificationManager.authorizationStatus == .denied {
                Text("Notifications are disabled. Tap 'Enable' to open Settings and allow notifications for CampusLink.")
            } else if notificationManager.authorizationStatus == .notDetermined {
                Text("Allow notifications to stay updated on your orders, messages, and marketplace activity.")
            }
        }
    }
    
    private var notificationTypesSection: some View {
        Section {
            NotificationToggleRow(
                title: "Order Updates",
                description: "New orders, confirmations, and status changes",
                icon: "cart.fill",
                iconColor: .blue,
                isEnabled: notificationService.userPreferences?.orderNotifications ?? true
            ) { enabled in
                await updateOrderNotifications(enabled)
            }
            
            NotificationToggleRow(
                title: "Messages",
                description: "New messages from buyers and sellers",
                icon: "message.fill",
                iconColor: .blue,
                isEnabled: notificationService.userPreferences?.messageNotifications ?? true
            ) { enabled in
                await updateMessageNotifications(enabled)
            }
            
            NotificationToggleRow(
                title: "Payments",
                description: "Payment confirmations and payout updates",
                icon: "creditcard.fill",
                iconColor: .green,
                isEnabled: notificationService.userPreferences?.paymentNotifications ?? true
            ) { enabled in
                await updatePaymentNotifications(enabled)
            }
            
            if AppConfig.enableRatings {
                NotificationToggleRow(
                    title: "Ratings",
                    description: "New ratings and rating reminders",
                    icon: "star.fill",
                    iconColor: .yellow,
                    isEnabled: notificationService.userPreferences?.ratingNotifications ?? true
                ) { enabled in
                    await updateRatingNotifications(enabled)
                }
            }
            
            NotificationToggleRow(
                title: "Marketplace Activity",
                description: "Listing interest and marketplace updates",
                icon: "storefront.fill",
                iconColor: .purple,
                isEnabled: notificationService.userPreferences?.marketplaceNotifications ?? false
            ) { enabled in
                await updateMarketplaceNotifications(enabled)
            }
        } header: {
            Text("Notification Types")
        }
    }
    
    private var timingSection: some View {
        Section {
            NavigationLink(destination: QuietHoursView()) {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.indigo)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiet Hours")
                            .font(.body)
                        
                        if let preferences = notificationService.userPreferences {
                            Text("\(preferences.quietHoursStart) - \(preferences.quietHoursEnd)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } header: {
            Text("Timing")
        } footer: {
            Text("Notifications will be delayed during quiet hours unless they're urgent.")
        }
    }
    
    private var frequencySection: some View {
        Section {
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Limit")
                        .font(.body)
                    
                    Text("Maximum notifications per day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("Daily Limit", selection: .constant(notificationService.userPreferences?.maxDailyNotifications ?? 10)) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                    Text("Unlimited").tag(999)
                }
                .pickerStyle(.menu)
                .onChange(of: notificationService.userPreferences?.maxDailyNotifications ?? 10) { newValue in
                    Task {
                        await updateMaxDailyNotifications(newValue)
                    }
                }
            }
            
            Toggle(isOn: .constant(notificationService.userPreferences?.groupSimilarNotifications ?? true)) {
                HStack {
                    Image(systemName: "rectangle.stack.fill")
                        .foregroundColor(.teal)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Group Similar")
                            .font(.body)
                        
                        Text("Combine similar notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: notificationService.userPreferences?.groupSimilarNotifications ?? true) { newValue in
                Task {
                    await updateGroupSimilarNotifications(newValue)
                }
            }
        } header: {
            Text("Frequency")
        }
    }
    
    private var featureDisabledSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Notifications Disabled")
                    .font(.headline)
                
                Text("The notifications feature is currently disabled. Check back later for updates on your orders, messages, and marketplace activity.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        isLoading = true
        await notificationService.fetchUserPreferences()
        await notificationManager.getCurrentAuthorizationStatus()
        isLoading = false
    }
    
    private func updateOrderNotifications(_ enabled: Bool) async {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil,
            orderNotifications: enabled,
            messageNotifications: nil, paymentNotifications: nil,
            ratingNotifications: nil, marketplaceNotifications: nil,
            quietHoursStart: nil, quietHoursEnd: nil, timezone: nil,
            maxDailyNotifications: nil, groupSimilarNotifications: nil
        )
        await notificationService.updatePreferences(update)
    }
    
    private func updateMessageNotifications(_ enabled: Bool) async {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: enabled,
            paymentNotifications: nil, ratingNotifications: nil,
            marketplaceNotifications: nil, quietHoursStart: nil,
            quietHoursEnd: nil, timezone: nil, maxDailyNotifications: nil,
            groupSimilarNotifications: nil
        )
        await notificationService.updatePreferences(update)
    }
    
    private func updatePaymentNotifications(_ enabled: Bool) async {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: nil, paymentNotifications: enabled,
            ratingNotifications: nil, marketplaceNotifications: nil,
            quietHoursStart: nil, quietHoursEnd: nil, timezone: nil,
            maxDailyNotifications: nil, groupSimilarNotifications: nil
        )
        await notificationService.updatePreferences(update)
    }
    
    private func updateRatingNotifications(_ enabled: Bool) async {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: nil, paymentNotifications: nil,
            ratingNotifications: enabled, marketplaceNotifications: nil,
            quietHoursStart: nil, quietHoursEnd: nil, timezone: nil,
            maxDailyNotifications: nil, groupSimilarNotifications: nil
        )
        await notificationService.updatePreferences(update)
    }
    
    private func updateMarketplaceNotifications(_ enabled: Bool) async {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: nil, paymentNotifications: nil,
            ratingNotifications: nil, marketplaceNotifications: enabled,
            quietHoursStart: nil, quietHoursEnd: nil, timezone: nil,
            maxDailyNotifications: nil, groupSimilarNotifications: nil
        )
        await notificationService.updatePreferences(update)
    }
    
    private func updateMaxDailyNotifications(_ value: Int) async {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: nil, paymentNotifications: nil,
            ratingNotifications: nil, marketplaceNotifications: nil,
            quietHoursStart: nil, quietHoursEnd: nil, timezone: nil,
            maxDailyNotifications: value, groupSimilarNotifications: nil
        )
        await notificationService.updatePreferences(update)
    }
    
    private func updateGroupSimilarNotifications(_ enabled: Bool) async {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: nil, paymentNotifications: nil,
            ratingNotifications: nil, marketplaceNotifications: nil,
            quietHoursStart: nil, quietHoursEnd: nil, timezone: nil,
            maxDailyNotifications: nil, groupSimilarNotifications: enabled
        )
        await notificationService.updatePreferences(update)
    }
}

// MARK: - Supporting Views

struct NotificationToggleRow: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let isEnabled: Bool
    let onToggle: (Bool) async -> Void
    
    @State private var isToggled: Bool
    
    init(
        title: String,
        description: String,
        icon: String,
        iconColor: Color,
        isEnabled: Bool,
        onToggle: @escaping (Bool) async -> Void
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
        self.isEnabled = isEnabled
        self.onToggle = onToggle
        self._isToggled = State(initialValue: isEnabled)
    }
    
    var body: some View {
        Toggle(isOn: $isToggled) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: isToggled) { newValue in
            Task {
                await onToggle(newValue)
            }
        }
        .onAppear {
            isToggled = isEnabled
        }
    }
}

struct QuietHoursView: View {
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var selectedTimezone = TimeZone.current.identifier
    
    var body: some View {
        Form {
            Section {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    .onChange(of: startTime) { _ in
                        updateQuietHours()
                    }
                
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    .onChange(of: endTime) { _ in
                        updateQuietHours()
                    }
            } header: {
                Text("Quiet Hours")
            } footer: {
                Text("Notifications will be delayed during these hours unless they're urgent.")
            }
            
            Section {
                Picker("Timezone", selection: $selectedTimezone) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers.prefix(20), id: \.self) { timezone in
                        Text(timezone).tag(timezone)
                    }
                }
                .onChange(of: selectedTimezone) { _ in
                    updateTimezone()
                }
            } header: {
                Text("Timezone")
            }
        }
        .navigationTitle("Quiet Hours")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        guard let preferences = notificationService.userPreferences else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let start = formatter.date(from: preferences.quietHoursStart) {
            startTime = start
        }
        
        if let end = formatter.date(from: preferences.quietHoursEnd) {
            endTime = end
        }
        
        selectedTimezone = preferences.timezone
    }
    
    private func updateQuietHours() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let startString = formatter.string(from: startTime)
        let endString = formatter.string(from: endTime)
        
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: nil, paymentNotifications: nil,
            ratingNotifications: nil, marketplaceNotifications: nil,
            quietHoursStart: startString,
            quietHoursEnd: endString,
            timezone: nil, maxDailyNotifications: nil,
            groupSimilarNotifications: nil
        )
        
        Task {
            await notificationService.updatePreferences(update)
        }
    }
    
    private func updateTimezone() {
        let update = NotificationPreferencesUpdate(
            pushEnabled: nil, pushToken: nil, orderNotifications: nil,
            messageNotifications: nil, paymentNotifications: nil,
            ratingNotifications: nil, marketplaceNotifications: nil,
            quietHoursStart: nil, quietHoursEnd: nil,
            timezone: selectedTimezone,
            maxDailyNotifications: nil, groupSimilarNotifications: nil
        )
        
        Task {
            await notificationService.updatePreferences(update)
        }
    }
}

#Preview {
    NotificationSettingsView()
}