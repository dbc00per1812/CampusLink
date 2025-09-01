import Foundation
import SwiftUI
import Supabase

@MainActor
class WalletViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var transactions: [PaymentTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String? { didSet { isShowingError = errorMessage != nil } }
    @Published var isShowingError: Bool = false
    @Published var showPayoutRequestSheet = false
    @Published var showPayoutHistorySheet = false
    @Published var hasStripeConnectAccount = false
    // Use Identifiable item for onboarding sheet
    struct OnboardingLink: Identifiable { let url: URL; var id: String { url.absoluteString } }
    @Published var onboardingLink: OnboardingLink?
    
    private let walletService = WalletService.shared
    
    func loadWalletData() async {
        isLoading = true
        errorMessage = nil
        
        print("🔵 WalletViewModel: Starting loadWalletData()")
        print("🔵 WalletViewModel: Initial hasStripeConnectAccount = \(hasStripeConnectAccount)")
        
        do {
            wallet = try await walletService.fetchBalance()
            transactions = try await walletService.getTransactionHistory(limit: 50)
        } catch {
            print("❌ WalletViewModel: Failed to load wallet/transactions: \(error)")
            // Handle specific error types for better user experience
            if error.localizedDescription.contains("cancelled") {
                errorMessage = "Request was cancelled. Please try again."
            } else if error.localizedDescription.contains("network") {
                errorMessage = "Network error. Please check your connection and try again."
            } else {
                errorMessage = "Failed to load wallet data: \(error.localizedDescription)"
            }
        }
        
        // Always check Stripe status, even if wallet loading fails
        print("🔵 WalletViewModel: About to check Stripe Connect status...")
        await checkStripeConnectStatusSafely()
        print("🔵 WalletViewModel: After checking Stripe status, hasStripeConnectAccount = \(hasStripeConnectAccount)")
        
        isLoading = false
    }
    
    func refreshData() async { await loadWalletData() }
    

    
    func startStripeOnboarding() async {
        isLoading = true
        defer { isLoading = false }
        
        struct OnboardingReq: Encodable { 
            let return_url: String = "campuslink://wallet/onboarding-complete"
            let refresh_url: String = "campuslink://wallet/onboarding-refresh"
        }
        struct OnboardingRes: Decodable { let onboarding_url: String?; let account_id: String?; let onboarding_complete: Bool?; let expires_at: Int? }
        
        do {
            let session = try await supabase.auth.session
            print("DEBUG: User ID: \(session.user.id)")
            print("DEBUG: Session expires at: \(session.expiresAt)")
            
            let accessToken = try await supabase.auth.session.accessToken
            print("DEBUG: Access token length: \(accessToken.count)")
            print("DEBUG: Access token starts with: \(String(accessToken.prefix(20)))...")
            
            let res: OnboardingRes = try await supabase.functions.invoke(
                "connect_onboarding",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: ["Authorization": "Bearer \(accessToken)"],
                    body: OnboardingReq()
                )
            )
            if res.onboarding_complete == true {
                print("✅ startStripeOnboarding: Account already complete, setting hasStripeConnectAccount = true")
                hasStripeConnectAccount = true
                onboardingLink = nil
                errorMessage = "Your payout account is already set up!"
            } else if let urlStr = res.onboarding_url, let url = URL(string: urlStr) {
                onboardingLink = OnboardingLink(url: url)
            } else {
                onboardingLink = nil
                errorMessage = "Unable to start onboarding. Please try again."
            }
        } catch {
            onboardingLink = nil
            errorMessage = "Failed to start onboarding: \(error.localizedDescription)"
        }
    }
    
    private func checkStripeConnectStatusSafely() async {
        do {
            print("🔵 WalletViewModel: Attempting checkStripeConnectStatus()")
            try await checkStripeConnectStatus()
            print("✅ WalletViewModel: checkStripeConnectStatus() completed successfully")
        } catch {
            print("⚠️ WalletViewModel: Failed to check Stripe Connect status: \(error)")
            print("⚠️ WalletViewModel: Error type: \(type(of: error))")
            print("⚠️ WalletViewModel: Error description: \(error.localizedDescription)")
            // Don't update hasStripeConnectAccount on error - keep current state
            // This prevents showing "Complete Payout Setup" when we can't verify status
        }
    }
    
    private func checkStripeConnectStatus() async throws {
        // Use the same method as startStripeOnboarding() - call the Edge Function
        struct OnboardingReq: Encodable { 
            let return_url: String = "campuslink://wallet/onboarding-complete"
            let refresh_url: String = "campuslink://wallet/onboarding-refresh"
        }
        struct OnboardingRes: Decodable { 
            let onboarding_url: String?
            let account_id: String?
            let onboarding_complete: Bool?
            let expires_at: Int? 
        }
        
        let accessToken = try await supabase.auth.session.accessToken
        print("🔵 checkStripeConnectStatus: Calling connect_onboarding function...")
        
        let res: OnboardingRes = try await supabase.functions.invoke(
            "connect_onboarding",
            options: FunctionInvokeOptions(
                method: .post,
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: OnboardingReq()
            )
        )
        
        // Check if onboarding is complete
        let isComplete = res.onboarding_complete == true
        hasStripeConnectAccount = isComplete
        
        print("🔵 Stripe Connect Status: onboarding_complete=\(res.onboarding_complete ?? false), hasStripeConnectAccount=\(hasStripeConnectAccount)")
        print("🔵 Stripe Connect Status: account_id=\(res.account_id ?? "nil"), onboarding_url=\(res.onboarding_url != nil ? "present" : "nil")")
    }
}

