# CampusLink Test Plan

## Overview

This document outlines the comprehensive testing strategy for the CampusLink iOS application. The test suite is designed to ensure reliability, maintainability, and quality throughout the development lifecycle.

## Test Structure

```
CampusLink/
├── CampusLinkTests/           # Unit Tests
│   ├── Models/                # Data model tests
│   ├── Services/              # Service layer tests
│   ├── ViewModels/            # ViewModel tests
│   ├── Mocks/                 # Mock objects
│   └── Helpers/               # Test utilities
└── CampusLinkUITests/         # UI Tests
    ├── CampusLinkUITests.swift
    └── CriticalFlowsUITests.swift
```

## Test Categories

### 1. Unit Tests

#### Model Tests ✅
- **ProductModelsTests**: Listing, User, Offer models
- **OrderModelsTests**: Order flow and payment models
- **NotificationModelsTests**: Notification system models
- **SearchModelsTests**: Search functionality models

#### Service Tests
- **WalletServiceTests**: Wallet and payment operations ✅
- **OrderService**: Order management (pending)
- **NotificationService**: Push notifications (pending)
- **SearchService**: Search functionality (pending)

#### ViewModel Tests
- **ChatViewModelTests**: Messaging functionality ✅
- **ConversationListViewModel**: Conversation management (pending)
- Additional ViewModels (pending)

### 2. UI Tests ✅

#### Critical User Flows
- **Authentication**: Login, signup, email verification
- **Product Management**: Create, edit, browse listings
- **Search & Discovery**: Search products, apply filters
- **Purchase Flow**: Complete purchase with wallet/card
- **Messaging**: Send messages, view conversations
- **Profile Management**: Update profile, settings

### 3. Integration Tests (Future)

- Supabase API integration
- Stripe payment processing
- Push notification delivery
- Real-time messaging

## Running Tests

### Command Line

```bash
# Run all tests
xcodebuild test -scheme CampusLink -destination 'platform=iOS Simulator,name=iPhone 15'

# Run only unit tests
xcodebuild test -scheme CampusLink -only-testing:CampusLinkTests

# Run only UI tests
xcodebuild test -scheme CampusLink -only-testing:CampusLinkUITests

# Run specific test class
xcodebuild test -scheme CampusLink -only-testing:CampusLinkTests/ProductModelsTests

# Run with coverage
xcodebuild test -scheme CampusLink -enableCodeCoverage YES
```

### Xcode

1. Press `Cmd+U` to run all tests
2. Click the diamond icon next to specific tests to run individually
3. Use Test Navigator (`Cmd+6`) to manage tests
4. View coverage in Report Navigator (`Cmd+9`)

## Test Data

### Using TestDataBuilder

```swift
// Create test user
let user = TestDataBuilder.createTestUser(
    email: "test@university.edu",
    trustScore: 90
)

// Create test listing
let listing = TestDataBuilder.createTestListing(
    title: "iPhone 13",
    price: 500.0,
    category: "Electronics"
)

// Create test order
let order = TestDataBuilder.createTestOrder(
    priceCents: 50000,
    status: .placed
)
```

## Mock Objects

### MockSupabaseClient Usage

```swift
let mockSupabase = MockSupabaseClient()

// Set up mock responses
mockSupabase.setTableData("listings", data: [testListing])
mockSupabase.setAuthSession(Session.mockSession())

// Use in tests
let result = try await service.fetchListings()
```

## Best Practices

### 1. Test Naming
```swift
func test{Feature}{Scenario}{ExpectedResult}() {
    // Example: testLoginWithValidCredentialsSucceeds
}
```

### 2. Arrange-Act-Assert Pattern
```swift
func testExample() {
    // Arrange
    let input = "test"
    
    // Act
    let result = processInput(input)
    
    // Assert
    XCTAssertEqual(result, "expected")
}
```

### 3. Async Testing
```swift
func testAsyncOperation() async throws {
    // Use async/await for async tests
    let result = try await service.fetchData()
    XCTAssertNotNil(result)
}
```

### 4. UI Test Stability
```swift
// Always wait for elements
let element = app.buttons["Submit"]
XCTAssertTrue(element.waitForExistence(timeout: 5))
element.tap()
```

## Coverage Goals

- **Overall**: 80% minimum
- **Models**: 100% coverage
- **Critical Services**: 90% coverage
- **ViewModels**: 85% coverage
- **UI Flows**: All critical paths covered

## Continuous Integration

GitHub Actions workflow configured for:
- Automated test runs on push/PR
- Separate unit and UI test jobs
- Code coverage reporting
- Test result artifacts

## Debugging Tests

### Common Issues

1. **Simulator not found**
   ```bash
   xcrun simctl list devices  # List available simulators
   xcrun simctl create "Test" com.apple.CoreSimulator.SimDeviceType.iPhone-15
   ```

2. **Test timeouts**
   - Increase timeout values in waitForExistence calls
   - Check for proper async handling

3. **Flaky UI tests**
   - Add proper wait conditions
   - Use accessibility identifiers
   - Disable animations in tests

### Viewing Test Results

1. **Xcode**: Report Navigator shows detailed results
2. **Command Line**: Results in `.xcresult` bundle
3. **CI**: Check GitHub Actions artifacts

## Adding New Tests

### 1. Create Test File
```swift
import XCTest
@testable import CampusLink

final class NewFeatureTests: XCTestCase {
    // Add setUp and tearDown if needed
    
    func testNewFeature() {
        // Test implementation
    }
}
```

### 2. Add to Test Plan
- Ensure test class is included in test target
- Update this document with new test coverage

### 3. Run Locally
- Verify tests pass locally before pushing
- Check coverage meets requirements

## Test Maintenance

### Weekly
- Review failing tests
- Update tests for new features
- Remove obsolete tests

### Monthly
- Review coverage reports
- Update test data
- Refactor test helpers

### Quarterly
- Performance test review
- UI test stability audit
- Mock object updates

## Contact

For questions about testing:
- Review test examples in codebase
- Check TestHelpers.swift for utilities
- Consult iOS testing documentation
