import XCTest
@testable import CampusLink

final class ConversationListViewModelTests: XCTestCase {
    func testLoadConversationsWithoutAuthenticationSetsError() async {
        let viewModel = ConversationListViewModel()
        await viewModel.loadConversations()
        XCTAssertEqual(viewModel.errorMessage, "Not authenticated")
    }
}
