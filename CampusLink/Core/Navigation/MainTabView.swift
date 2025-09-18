import SwiftUI

struct MainTabView: View {
    @State private var walletBadge: String?
    
    var body: some View {
        ResponsiveContainer {
            TabView {
                // Home Tab
                HomeTabView()
                    .tabItem {
                        Image(systemName: "house.fill")
                            .responsiveFontSize(24)
                    }
                
                // Messages Tab
                ConversationListView()
                    .tabItem {
                        Image(systemName: "message.fill")
                            .responsiveFontSize(24)
                    }
                
                // Post Tab
                PostView()
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                            .responsiveFontSize(24)
                    }
                
                // Wallet Tab
                WalletView()
                    .tabItem {
                        Image(systemName: "creditcard.fill")
                            .responsiveFontSize(24)
                    }
                    .badge(walletBadge)
                    .task { await loadWalletBadge() }
                
                // Profile Tab
                ProfileTabView()
                    .tabItem {
                        Image(systemName: "person.circle.fill")
                            .responsiveFontSize(24)
                    }
            }
            .accentColor(Color("ThemeColor"))
            .adaptiveBottomPadding()
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