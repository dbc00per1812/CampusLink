import XCTest
@testable import CampusLink

final class AuthManagerTests: XCTestCase {
    func testSignUpRejectsNonEduEmail() async {
        let manager = AuthManager()
        let result = await manager.signUp(email: "user@gmail.com", password: "password", name: "User")
        switch result {
        case .failure(let error):
            if case .invalidEmail = error {
                // expected
            } else {
                XCTFail("Expected invalidEmail error")
            }
        default:
            XCTFail("Expected failure for non .edu email")
        }
    }
}
