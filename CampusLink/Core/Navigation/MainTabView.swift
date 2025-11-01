import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var tabCoordinator = TabCoordinator.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var walletBadge: String?
    @State private var homeNavigationPath = NavigationPath()
    @State private var hasRequestedPermissions = false
    
    private var isAuthenticated: Bool {
        authManager.session != nil
    }
    
    var body: some View {
        ResponsiveContainer {
            TabView(selection: $tabCoordinator.selectedTab) {
                // Home Tab - Always accessible
                NavigationStack(path: $homeNavigationPath) {
                    HomeTabView()
                }
                .tabItem {
                    Image(systemName: AppTab.home.systemImage)
                        .responsiveFontSize(24)
                }
                .tag(AppTab.home)
                
                // Messages Tab - Requires authentication
                Group {
                    if isAuthenticated {
                        ConversationListView()
                    } else {
                        GuestPromptView(
                            icon: "message.circle",
                            title: "Messages",
                            message: "Sign in to view and send messages"
                        )
                    }
                }
                .tabItem {
                    Image(systemName: AppTab.messages.systemImage)
                        .responsiveFontSize(24)
                }
                .tag(AppTab.messages)
                
                // Post Tab - Requires authentication
                Group {
                    if isAuthenticated {
                        PostView()
                    } else {
                        GuestPromptView(
                            icon: "plus.circle",
                            title: "Create Listing",
                            message: "Sign in to post items for sale"
                        )
                    }
                }
                .tabItem {
                    Image(systemName: AppTab.post.systemImage)
                        .responsiveFontSize(24)
                }
                .tag(AppTab.post)
                
                // Wallet Tab - Requires authentication
                Group {
                    if isAuthenticated {
                        WalletView()
                            .badge(walletBadge)
                            .task { await loadWalletBadge() }
                    } else {
                        GuestPromptView(
                            icon: "wallet.pass",
                            title: "Wallet",
                            message: "Sign in to manage your earnings and payments"
                        )
                    }
                }
                .tabItem {
                    Image(systemName: AppTab.wallet.systemImage)
                        .responsiveFontSize(24)
                }
                .tag(AppTab.wallet)
                
                // Profile Tab - Show guest profile or authenticated profile
                Group {
                    if isAuthenticated {
                        ProfileTabView()
                    } else {
                        GuestProfileView()
                    }
                }
                .tabItem {
                    Image(systemName: AppTab.profile.systemImage)
                        .responsiveFontSize(24)
                }
                .tag(AppTab.profile)
            }
            .accentColor(Color("ThemeColor"))
            .adaptiveBottomPadding()
        }
        .environmentObject(tabCoordinator)
        .task {
            // Request notification permissions on first launch after login
            if isAuthenticated && !hasRequestedPermissions && notificationManager.authorizationStatus == .notDetermined {
                hasRequestedPermissions = true
                await notificationManager.requestPermissions()
            }
        }
        .onChange(of: tabCoordinator.selectedTab) { newTab in
            if newTab == .home {
                // Reset home navigation when home tab is selected
                homeNavigationPath = NavigationPath()
            }
        }
        .onChange(of: tabCoordinator.shouldResetHomeNavigation) { shouldReset in
            if shouldReset {
                homeNavigationPath = NavigationPath()
                tabCoordinator.resetHomeNavigationFlag()
            }
        }
    }
    
    private func loadWalletBadge() async {
        do {
            let wallet = try await WalletService.shared.fetchBalance()
            let dollars = Int(Double(wallet.availableCents) / 100.0)
            walletBadge = dollars > 0 ? "\(dollars)" : nil
        } catch {
            walletBadge = nil
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthManager())
    }
} 