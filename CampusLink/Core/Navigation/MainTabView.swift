import SwiftUI

struct MainTabView: View {
    @StateObject private var tabCoordinator = TabCoordinator.shared
    @State private var walletBadge: String?
    
    var body: some View {
        ResponsiveContainer {
            TabView(selection: $tabCoordinator.selectedTab) {
                // Home Tab
                HomeTabView()
                    .tabItem {
                        Image(systemName: AppTab.home.systemImage)
                            .responsiveFontSize(24)
                    }
                    .tag(AppTab.home)
                
                // Messages Tab
                ConversationListView()
                    .tabItem {
                        Image(systemName: AppTab.messages.systemImage)
                            .responsiveFontSize(24)
                    }
                    .tag(AppTab.messages)
                
                // Post Tab
                PostView()
                    .tabItem {
                        Image(systemName: AppTab.post.systemImage)
                            .responsiveFontSize(24)
                    }
                    .tag(AppTab.post)
                
                // Wallet Tab
                WalletView()
                    .tabItem {
                        Image(systemName: AppTab.wallet.systemImage)
                            .responsiveFontSize(24)
                    }
                    .tag(AppTab.wallet)
                    .badge(walletBadge)
                    .task { await loadWalletBadge() }
                
                
                // Profile Tab
                ProfileTabView()
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