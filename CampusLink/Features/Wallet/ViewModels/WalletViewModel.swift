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
    
    // Cache for order data to ensure accurate status display
    @Published var orderCache: [UUID: Order] = [:]
    
    // Offers
    @Published var pendingOffers: [UserOffer] = []
    @Published var isLoadingOffers = false
    
    private let walletService = WalletService.shared
    private let offerService = OfferService.shared
    
    func loadWalletData() async {
        isLoading = true
        errorMessage = nil
        
        print("🔵 WalletViewModel: Starting loadWalletData() with optimized loading")
        print("🔵 WalletViewModel: Initial hasStripeConnectAccount = \(hasStripeConnectAccount)")
        
        // OPTIMIZATION 1: Load cached Stripe status from database immediately (fast)
        await loadCachedStripeStatus()
        
        // OPTIMIZATION 2: Load wallet data and Stripe status in PARALLEL
        async let walletResult: Result<Void, Error> = loadWalletAndTransactions()
        async let stripeCheck: Void = checkStripeConnectStatusInBackground()
        
        // Wait for wallet data (required)
        do {
            try await walletResult.get()
        } catch {
            print("❌ WalletViewModel: Failed to load wallet/transactions: \(error)")
            // Handle specific error types for better user experience
            if error.localizedDescription.contains("cancelled") {
                // Don't show error for cancelled requests - user likely released swipe early
                print("🔵 WalletViewModel: Request cancelled - silently ignoring")
            } else if error.localizedDescription.contains("network") {
                errorMessage = "Network error. Please check your connection and try again."
            } else if error.localizedDescription.contains("session") || error.localizedDescription.contains("auth") {
                // Don't show error for auth session issues - user is likely logging out
                print("🔵 WalletViewModel: Auth session issue - likely user logging out")
                isLoading = false
                return
            } else {
                errorMessage = "Failed to load wallet data: \(error.localizedDescription)"
            }
        }
        
        // Stripe check happens in background, don't wait for it
        await stripeCheck
        
        isLoading = false
    }
    
    // OPTIMIZATION: Load cached Stripe status from user profile (instant)
    private func loadCachedStripeStatus() async {
        do {
            guard let userId = try? await supabase.auth.session.user.id.uuidString else {
                print("⚠️ WalletViewModel: No user ID for cached status")
                return
            }
            
            struct UserProfile: Decodable {
                let stripe_payouts_enabled: Bool?
                let stripe_details_submitted: Bool?
            }
            
            let profile: UserProfile = try await supabase
                .from("users")
                .select("stripe_payouts_enabled, stripe_details_submitted")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            // Use cached status if both flags are true
            let cachedStatus = (profile.stripe_payouts_enabled == true && profile.stripe_details_submitted == true)
            hasStripeConnectAccount = cachedStatus
            
            print("✅ WalletViewModel: Loaded cached Stripe status = \(cachedStatus)")
        } catch {
            print("⚠️ WalletViewModel: Failed to load cached Stripe status: \(error)")
            // Keep existing status, don't change it
        }
    }
    
    // OPTIMIZATION: Separate wallet loading for parallel execution
    private func loadWalletAndTransactions() async -> Result<Void, Error> {
        do {
            wallet = try await walletService.fetchBalance()
            let rawTransactions = try await walletService.getTransactionHistory(limit: 50)
            
            // Deduplicate transactions by listing_id (keep most recent)
            transactions = deduplicateTransactions(rawTransactions)
            
            // Preload order data for accurate status display
            await preloadOrderData()
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // Deduplicate transactions to prevent showing the same order multiple times
    private func deduplicateTransactions(_ transactions: [PaymentTransaction]) -> [PaymentTransaction] {
        var seenListingIds: Set<UUID> = []
        var uniqueTransactions: [PaymentTransaction] = []
        
        // Transactions are already sorted by created_at DESC, so we keep the first (most recent) one
        for transaction in transactions {
            if let listingId = transaction.listingId {
                if !seenListingIds.contains(listingId) {
                    seenListingIds.insert(listingId)
                    uniqueTransactions.append(transaction)
                }
            } else {
                // Keep transactions without a listing_id (shouldn't normally happen)
                uniqueTransactions.append(transaction)
            }
        }
        
        print("🔵 WalletViewModel: Deduplicated \(transactions.count) transactions down to \(uniqueTransactions.count) unique transactions")
        return uniqueTransactions
    }
    
    // OPTIMIZATION: Check Stripe status in background (non-blocking)
    private func checkStripeConnectStatusInBackground() async {
        print("🔵 WalletViewModel: Checking Stripe status in background...")
        await checkStripeConnectStatusSafely()
        print("🔵 WalletViewModel: Background Stripe check complete, hasStripeConnectAccount = \(hasStripeConnectAccount)")
    }
    
    func refreshData() async { 
        await loadWalletData()
        if AppConfig.enableSeekMode {
            await loadPendingOffers()
        }
    }
    

    
    func startStripeOnboarding() async {
        isLoading = true
        defer { isLoading = false }
        
        struct OnboardingReq: Encodable { 
            let return_url: String = "https://stripe-redirect.netlify.app/stripe-return.html"
            let refresh_url: String = "https://stripe-redirect.netlify.app/stripe-refresh.html"
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
            let return_url: String = "https://stripe-redirect.netlify.app/stripe-return.html"
            let refresh_url: String = "https://stripe-redirect.netlify.app/stripe-refresh.html"
        }
        struct OnboardingRes: Decodable { 
            let onboarding_url: String?
            let account_id: String?
            let onboarding_complete: Bool?
            let expires_at: Int? 
        }
        
        let session = try await supabase.auth.session
        let accessToken = session.accessToken
        let userId = session.user.id.uuidString
        
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
        let previousStatus = hasStripeConnectAccount
        hasStripeConnectAccount = isComplete
        
        print("🔵 Stripe Connect Status: onboarding_complete=\(res.onboarding_complete ?? false), hasStripeConnectAccount=\(hasStripeConnectAccount)")
        print("🔵 Stripe Connect Status: account_id=\(res.account_id ?? "nil"), onboarding_url=\(res.onboarding_url != nil ? "present" : "nil")")
        
        // OPTIMIZATION: Update database cache if status changed
        if previousStatus != isComplete {
            print("🔄 WalletViewModel: Stripe status changed, updating database cache...")
            await updateStripeCacheInDatabase(userId: userId, isComplete: isComplete)
        }
    }
    
    // OPTIMIZATION: Update cached Stripe status in database
    private func updateStripeCacheInDatabase(userId: String, isComplete: Bool) async {
        do {
            struct UserUpdate: Encodable {
                let stripe_payouts_enabled: Bool
                let stripe_details_submitted: Bool
            }
            
            try await supabase
                .from("users")
                .update(UserUpdate(
                    stripe_payouts_enabled: isComplete,
                    stripe_details_submitted: isComplete
                ))
                .eq("id", value: userId)
                .execute()
            
            print("✅ WalletViewModel: Updated Stripe cache in database")
        } catch {
            print("⚠️ WalletViewModel: Failed to update Stripe cache: \(error)")
            // Non-critical error, don't throw
        }
    }
    
    // MARK: - Order Data Preloading
    private func preloadOrderData() async {
        guard !transactions.isEmpty else { return }
        
        print("🔵 WalletViewModel: Preloading order data for \(transactions.count) transactions")
        
        // Get current user ID
        guard let currentUserId = try? await supabase.auth.session.user.id else {
            print("❌ WalletViewModel: No current user ID for preloading orders")
            return
        }
        
        // Collect all listing IDs from transactions
        let listingIds = transactions.compactMap { $0.listingId }
        guard !listingIds.isEmpty else { return }
        
        do {
            // Load all orders for these transactions in one query
            let orders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .in("listing_id", values: listingIds.map { $0.uuidString })
                .or("buyer_id.eq.\(currentUserId.uuidString),seller_id.eq.\(currentUserId.uuidString)")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Cache orders by transaction ID (using listing ID as the key)
            var newOrderCache: [UUID: Order] = [:]
            for order in orders {
                let listingId = order.listingId
                // Find the transaction that matches this order
                if let transaction = transactions.first(where: { $0.listingId == listingId }) {
                    newOrderCache[transaction.id] = order
                }
            }
            
            orderCache = newOrderCache
            print("✅ WalletViewModel: Cached \(orderCache.count) orders for status display")
            
        } catch {
            print("❌ WalletViewModel: Failed to preload order data: \(error)")
        }
    }
    
    // MARK: - Offers Management
    func loadPendingOffers() async {
        isLoadingOffers = true
        
        do {
            // Get offers where you are BOTH seeker (receiving offers) AND seller (making offers)
            pendingOffers = try await offerService.getUserOffers(role: .both)
                .filter { $0.status == "pending" }
            print("✅ WalletViewModel: Loaded \(pendingOffers.count) pending offers")
        } catch {
            print("❌ WalletViewModel: Failed to load offers: \(error)")
            // Don't show error for offers - it's not critical
        }
        
        isLoadingOffers = false
    }
}

