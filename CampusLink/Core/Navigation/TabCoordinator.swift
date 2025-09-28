import SwiftUI

// MARK: - Tab Types
enum AppTab: String, CaseIterable {
    case home = "home"
    case messages = "messages"
    case post = "post"
    case wallet = "wallet"
    case profile = "profile"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .messages: return "Messages"
        case .post: return "Post"
        case .wallet: return "Wallet"
        case .profile: return "Profile"
        }
    }
    
    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .messages: return "message.fill"
        case .post: return "plus.circle.fill"
        case .wallet: return "creditcard.fill"
        case .profile: return "person.circle.fill"
        }
    }
}

// MARK: - Tab Coordinator
@MainActor
class TabCoordinator: ObservableObject {
    static let shared = TabCoordinator()
    
    @Published var selectedTab: AppTab = .home
    @Published var walletShouldFocusOffers: Bool = false
    
    private init() {}
    
    /// Navigate to a specific tab
    func navigateToTab(_ tab: AppTab) {
        selectedTab = tab
    }
    
    /// Navigate to wallet tab and focus on offers section
    func navigateToWalletWithOffersFocus() {
        walletShouldFocusOffers = true
        selectedTab = .wallet
        
        // Reset the focus flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.walletShouldFocusOffers = false
        }
    }
}
