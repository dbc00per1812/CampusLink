import XCTest
@testable import CampusLink

final class PaymentLogicTests: XCTestCase {
    func makeTx(status: String, disputed: Bool = false, buyer: String = "buyer", seller: String = "seller") -> PaymentTransaction {
        PaymentTransaction(
            id: UUID(),
            listingId: UUID(),
            buyerId: buyer,
            sellerId: seller,
            paymentIntentId: "pi_123",
            amount: 10.0,
            status: status,
            createdAt: Date(),
            escrowReleaseAt: nil,
            deliveredAt: nil,
            buyerConfirmedAt: nil,
            disputeStatus: disputed ? .open : .none,
            disputeReason: disputed ? "not_received" : nil,
            disputeNotes: disputed ? "evidence" : nil,
            listing: nil
        )
    }

    func testCanBuyerConfirm_onlyRequiresCapture_andNotDisputed() {
        let capturable = makeTx(status: "requires_capture")
        XCTAssertTrue(PaymentLogic.canBuyerConfirm(transaction: capturable, isBuyer: true))

        let succeeded = makeTx(status: "succeeded")
        XCTAssertFalse(PaymentLogic.canBuyerConfirm(transaction: succeeded, isBuyer: true))

        let disputed = makeTx(status: "requires_capture", disputed: true)
        XCTAssertFalse(PaymentLogic.canBuyerConfirm(transaction: disputed, isBuyer: true))

        let notBuyer = makeTx(status: "requires_capture")
        XCTAssertFalse(PaymentLogic.canBuyerConfirm(transaction: notBuyer, isBuyer: false))
    }

    func testStatusLabel_prettifiesUnderscores() {
        XCTAssertEqual(PaymentLogic.statusLabel(for: "requires_capture"), "Requires Capture")
        XCTAssertEqual(PaymentLogic.statusLabel(for: "succeeded"), "Succeeded")
    }
}


