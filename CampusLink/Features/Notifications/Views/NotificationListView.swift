import SwiftUI

struct NotificationListView: View {
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var selectedCategory: NotificationCategory? = nil
    @State private var showingSettings = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            Group {
                if AppConfig.enableNotifications {
                    if notificationManager.areNotificationsEnabled {
                        notificationContent
                    } else {
                        permissionPromptView
                    }
                } else {
                    featureDisabledView
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All Read") {
                            Task {
                                await notificationService.markAllAsRead()
                            }
                        }
                        .disabled(notificationService.unreadCount == 0)
                        
                        Button("Settings") {
                            showingSettings = true
                        }
                        
                        Button("Refresh") {
                            Task {
                                await refreshNotifications()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NotificationSettingsView()
            }
            .task {
                if AppConfig.enableNotifications && notificationManager.areNotificationsEnabled {
                    await loadNotifications()
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    private var notificationContent: some View {
        VStack(spacing: 0) {
            if !notificationService.notifications.isEmpty {
                categoryFilter
                notificationsList
            } else {
                emptyStateView
            }
        }
        .refreshable {
            await refreshNotifications()
        }
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryFilterChip(
                    title: "All",
                    count: notificationService.notifications.count,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                
                ForEach(NotificationCategory.allCases, id: \.self) { category in
                    let notifications = notificationService.getNotifications(for: category)
                    
                    if !notifications.isEmpty {
                        CategoryFilterChip(
                            title: category.displayName,
                            count: notifications.count,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var notificationsList: some View {
        List {
            ForEach(filteredNotifications) { notification in
                NotificationRow(notification: notification) {
                    await notificationService.markAsRead(notification)
                } onDelete: {
                    await notificationService.deleteNotification(notification)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        Task {
                            await notificationService.deleteNotification(notification)
                        }
                    }
                    
                    if !notification.isRead {
                        Button("Mark Read") {
                            Task {
                                await notificationService.markAsRead(notification)
                            }
                        }
                        .tint(.blue)
                    }
                }
            }
            
            if notificationService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Supporting Views
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("You're all caught up! New notifications will appear here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Refresh") {
                Task {
                    await refreshNotifications()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var permissionPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Enable Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Stay updated on your orders, messages, and marketplace activity by enabling notifications.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                if notificationManager.authorizationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        Task {
                            await notificationManager.requestPermissions()
                            if notificationManager.areNotificationsEnabled {
                                await loadNotifications()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Open Settings") {
                        notificationManager.openAppSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Maybe Later") {
                    // Dismiss or navigate back
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var featureDisabledView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.slash.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("Notifications Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("The notifications feature is currently disabled. Check back later for updates.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var filteredNotifications: [Notification] {
        if let selectedCategory = selectedCategory {
            return notificationService.getNotifications(for: selectedCategory)
        } else {
            return notificationService.notifications
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadNotifications() async {
        await notificationService.initialize()
    }
    
    private func refreshNotifications() async {
        isRefreshing = true
        await notificationService.fetchNotifications()
        await notificationService.fetchUnreadCount()
        isRefreshing = false
    }
}

// MARK: - Supporting Components

struct CategoryFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct NotificationRow: View {
    let notification: Notification
    let onTap: () async -> Void
    let onDelete: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await onTap()
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: notification.type.icon)
                    .font(.title3)
                    .foregroundColor(notification.type.color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(notification.type.color.opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(notification.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.body)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(notification.isRead ? Color.clear : Color.accentColor.opacity(0.05))
        )
    }
}

#Preview {
    NotificationListView()
}
