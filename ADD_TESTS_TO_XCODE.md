# Add Test Files to Xcode Project

The following test files have been created and need to be added to the Xcode project:

## CampusLinkTests Target Files

### Models Tests
1. `/CampusLinkTests/Models/ProductModelsTests.swift`
2. `/CampusLinkTests/Models/OrderModelsTests.swift`
3. `/CampusLinkTests/Models/NotificationModelsTests.swift`
4. `/CampusLinkTests/Models/SearchModelsTests.swift`

### Services Tests
1. `/CampusLinkTests/Services/WalletServiceTests.swift`

### ViewModels Tests
1. `/CampusLinkTests/ViewModels/ChatViewModelTests.swift`

### Mocks
1. `/CampusLinkTests/Mocks/MockSupabaseClient.swift`

### Helpers
1. `/CampusLinkTests/Helpers/TestHelpers.swift`

## CampusLinkUITests Target Files

1. `/CampusLinkUITests/CriticalFlowsUITests.swift`

## How to Add to Xcode

1. Open `CampusLink.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on the `CampusLinkTests` folder
3. Select "Add Files to 'CampusLink'..."
4. Navigate to the `/CampusLinkTests/` directory
5. Select all the test files listed above
6. Ensure "CampusLinkTests" is checked in the target membership
7. Click "Add"
8. Repeat for the UI test file with the `CampusLinkUITests` target

## Verify Test Target Settings

1. Select the project in navigator
2. Select "CampusLinkTests" target
3. Ensure "Host Application" is set to "CampusLink"
4. In Build Phases, verify all test files are in "Compile Sources"

## Run Tests

After adding files:
1. Press `Cmd+U` to run all tests
2. Or use Product → Test from the menu
3. Check that all tests appear in the Test Navigator (`Cmd+6`)

## CI/CD Configuration

The `.github/workflows/tests.yml` file has been created for automated testing. This will run automatically when you push to GitHub.
