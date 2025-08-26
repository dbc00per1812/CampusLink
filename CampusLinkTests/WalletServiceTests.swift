import XCTest
@testable import CampusLink

final class WalletServiceTests: XCTestCase {
    func testWalletFormatting() throws {
        let wallet = Wallet(
            id: UUID(),
            userId: UUID(),
            availableCents: 12345,
            escrowCents: 2500,
            updatedAt: Date()
        )
        XCTAssertEqual(wallet.formattedAvailableBalance, "$123.45")
        XCTAssertEqual(wallet.formattedEscrowBalance, "$25.00")
        XCTAssertEqual(wallet.formattedTotalBalance, "$148.45")
    }
    
    func testMockService() async throws {
        let service = WalletServiceMock.shared
        let wallet = try await service.fetchBalance()
        XCTAssertTrue(wallet.availableCents > 0)
        
        let payout = try await service.requestPayout(amountCents: 2000)
        XCTAssertEqual(payout.amountCents, 2000)
        
        let history = try await service.getTransactionHistory()
        XCTAssertFalse(history.isEmpty)
        XCTAssertEqual(history.first?.type, .payout)
    }
}
