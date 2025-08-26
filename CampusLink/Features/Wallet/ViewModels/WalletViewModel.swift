import Foundation
import SwiftUI
import Supabase

@MainActor
class WalletViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var transactions: [PaymentTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showWithdrawSheet = false
    @Published var withdrawAmount: String = ""
    @Published var isProcessingPayout = false
    @Published var hasStripeConnectAccount = false
    // Use URL item for onboarding sheet; when nil, no sheet is shown
    @Published var onboardingURL: URL?
    
    private let walletService = WalletService.shared
    
    func loadWalletData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            wallet = try await walletService.fetchBalance()
            transactions = try await walletService.getTransactionHistory(limit: 50)
            try await checkStripeConnectStatus()
        } catch {
            errorMessage = "Failed to load wallet data: \(error.localizedDescription)"
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
        
        struct OnboardingReq: Encodable { let return_url: String = "campuslink://wallet/onboarding-complete"; let refresh_url: String = "campuslink://wallet/onboarding-refresh" }
        struct OnboardingRes: Decodable { let onboarding_url: String?; let account_id: String?; let onboarding_complete: Bool?; let expires_at: Int? }
        
        do {
            let res: OnboardingRes = try await supabase.functions.invoke(
                "connect_onboarding",
                options: FunctionInvokeOptions(method: .post, body: OnboardingReq())
            )
            if res.onboarding_complete == true {
                hasStripeConnectAccount = true
                onboardingURL = nil
                errorMessage = "Your payout account is already set up!"
            } else if let urlStr = res.onboarding_url, let url = URL(string: urlStr) {
                onboardingURL = url
            } else {
                onboardingURL = nil
                errorMessage = "Unable to start onboarding. Please try again."
            }
        } catch {
            onboardingURL = nil
            errorMessage = "Failed to start onboarding: \(error.localizedDescription)"
        }
    }
    
    private func checkStripeConnectStatus() async throws {
        struct UserStripe: Decodable { let stripe_connect_id: String? }
        let userId = try await supabase.auth.session.user.id
        let user: UserStripe = try await supabase
            .from("users")
            .select("stripe_connect_id")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        hasStripeConnectAccount = user.stripe_connect_id != nil
    }
}

