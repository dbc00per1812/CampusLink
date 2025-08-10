import XCTest
@testable import CampusLink

final class PaymentServiceTests: XCTestCase {
    func testFunctionsBaseURLBuildsCorrectURL() throws {
        let service = PaymentService.shared
        let url = try service.functionsBaseURL()
        XCTAssertEqual(url.absoluteString, "https://example.functions.supabase.co/")
    }
}
