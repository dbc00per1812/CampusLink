import Foundation

// MARK: - Mock Wallet Service for local testing
final class WalletServiceMock {
    static let shared = WalletServiceMock()
    private init() {}
    
    private var wallet = Wallet(
        userId: UUID(),
        availableCents: 12345,
        escrowCents: 2500,
        updatedAt: Date()
    )
    
    func fetchBalance() async throws -> Wallet {
        return wallet
    }
    
    func requestPayout(amountCents: Int) async throws -> Payout {
        let payout = Payout(
            id: UUID(),
            sellerId: wallet.userId,
            amountCents: amountCents,
            destination: "stripe_connect",
            status: .processing,
            stripeTransferId: nil,
            errorMessage: nil,
            retryCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            paidAt: nil
        )
        wallet = Wallet(
            userId: wallet.userId,
            availableCents: max(0, wallet.availableCents - amountCents),
            escrowCents: wallet.escrowCents,
            updatedAt: Date()
        )
        return payout
    }
    
    func getTransactionHistory(limit: Int = 50) async throws -> [WalletTransaction] {
        let tx = WalletTransaction(
            id: UUID(),
            userId: wallet.userId,
            type: .payout,
            amountCents: 2000,
            balanceAfterCents: wallet.availableCents,
            description: "Mock payout",
            relatedId: nil,
            createdAt: Date()
        )
        return [tx]
    }
}
