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
    @Published var showOnboardingSheet = false
    @Published var withdrawAmount: String = ""
    @Published var isProcessingPayout = false
    @Published var hasStripeConnectAccount = false
    @Published var stripeOnboardingURL: String?
    
    private let walletService = WalletService.shared
    
    func loadWalletData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch wallet balance
            wallet = try await walletService.fetchBalance()
            
            // Fetch transaction history
            transactions = try await walletService.getTransactionHistory(limit: 50)
            
            // Check if user has Stripe Connect account
            try await checkStripeConnectStatus()
            
        } catch {
            errorMessage = "Failed to load wallet data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadWalletData()
    }
    
    func requestPayout() async {
        guard let wallet = wallet else { return }
        
        // Parse amount -> cents safely
        let amountCents: Int?
        if let amount = Double(withdrawAmount.replacingOccurrences(of: ",", with: "")) {
            amountCents = Int((amount * 100.0).rounded())
        } else {
            amountCents = nil
        }
        
        guard let cents = amountCents else {
            errorMessage = "Invalid amount"
            return
        }
        
        if cents <= 0 {
            errorMessage = "Amount must be greater than $0"
            return
        }
        
        if cents > wallet.availableCents {
            errorMessage = "Insufficient balance"
            return
        }
        
        isProcessingPayout = true
        errorMessage = nil
        
        do {
            let payout = try await walletService.requestPayout(amountCents: cents)
            
            // Refresh wallet data
            await loadWalletData()
            
            // Clear form and close sheet
            withdrawAmount = ""
            showWithdrawSheet = false
            
            // Show success toast/message
            errorMessage = "Payout of \(payout.formattedAmount) initiated successfully"
            
        } catch {
            errorMessage = "Failed to process payout: \(error.localizedDescription)"
        }
        
        isProcessingPayout = false
    }
    
    func startStripeOnboarding() async {
        isLoading = true
        
        do {
            struct OnboardingReq: Encodable { let return_url: String = "campuslink://wallet/onboarding-complete"; let refresh_url: String = "campuslink://wallet/onboarding-refresh" }
            struct OnboardingRes: Decodable { let onboarding_url: String?; let account_id: String?; let onboarding_complete: Bool?; let expires_at: Int? }
            
            let res: OnboardingRes = try await supabase.functions.invoke(
                "connect_onboarding",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: OnboardingReq()
                )
            )
            
            if res.onboarding_complete == true {
                hasStripeConnectAccount = true
                errorMessage = "Your payout account is already set up!"
            } else if let url = res.onboarding_url {
                stripeOnboardingURL = url
                showOnboardingSheet = true
            }
        } catch {
            errorMessage = "Failed to start onboarding: \(error.localizedDescription)"
        }
        
        isLoading = false
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

