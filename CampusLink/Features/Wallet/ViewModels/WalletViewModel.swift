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
    @Published var showWithdrawSheet = false
    @Published var withdrawAmount: String = ""
    @Published var isProcessingPayout = false
    @Published var hasStripeConnectAccount = false
    // Use Identifiable item for onboarding sheet
    struct OnboardingLink: Identifiable { let url: URL; var id: String { url.absoluteString } }
    @Published var onboardingLink: OnboardingLink?
    
    private let walletService = WalletService.shared
    
    func loadWalletData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            wallet = try await walletService.fetchBalance()
            transactions = try await walletService.getTransactionHistory(limit: 50)
            try await checkStripeConnectStatus()
        } catch {
            // Handle specific error types for better user experience
            if error.localizedDescription.contains("cancelled") {
                errorMessage = "Request was cancelled. Please try again."
            } else if error.localizedDescription.contains("network") {
                errorMessage = "Network error. Please check your connection and try again."
            } else {
                errorMessage = "Failed to load wallet data: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func refreshData() async { await loadWalletData() }
    
    func requestPayout() async {
        guard let wallet = wallet else { return }
        let amountCents: Int?
        if let amount = Double(withdrawAmount.replacingOccurrences(of: ",", with: "")) {
            amountCents = Int((amount * 100.0).rounded())
        } else { amountCents = nil }
        guard let cents = amountCents else { errorMessage = "Invalid amount"; return }
        guard cents > 0 else { errorMessage = "Amount must be greater than $0"; return }
        guard cents <= wallet.availableCents else { errorMessage = "Insufficient balance"; return }
        
        isProcessingPayout = true
        errorMessage = nil
        do {
            let payout = try await walletService.requestPayout(amountCents: cents)
            await loadWalletData()
            withdrawAmount = ""
            showWithdrawSheet = false
            errorMessage = "Payout of \(payout.formattedAmount) initiated successfully"
        } catch {
            errorMessage = "Failed to process payout: \(error.localizedDescription)"
        }
        isProcessingPayout = false
    }
    
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
    
    private func checkStripeConnectStatus() async throws {
        struct UserStripe: Decodable { 
            let stripe_connect_id: String?
            let stripe_payouts_enabled: Bool?
            let stripe_details_submitted: Bool?
        }
        let userId = try await supabase.auth.session.user.id
        let user: UserStripe = try await supabase
            .from("users")
            .select("stripe_connect_id, stripe_payouts_enabled, stripe_details_submitted")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        // Only consider it "complete" if all requirements are met
        hasStripeConnectAccount = user.stripe_connect_id != nil && 
                                 user.stripe_payouts_enabled == true && 
                                 user.stripe_details_submitted == true
    }
}

