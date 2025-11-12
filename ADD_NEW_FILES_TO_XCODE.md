# Add New Pending Transactions Files to Xcode

## Files to Add

You need to manually add these 3 new files to your Xcode project:

### 1. PendingTransactionModels.swift
**File Location**: `CampusLink/Core/Models/PendingTransactionModels.swift`  
**Add to Group**: Core → Models

**Steps**:
1. In Xcode, navigate to the `Core/Models` folder in the Project Navigator
2. Right-click on `Models` folder
3. Select "Add Files to CampusLink..."
4. Navigate to and select `CampusLink/Core/Models/PendingTransactionModels.swift`
5. Make sure "CampusLink" target is checked
6. Click "Add"

### 2. AllPendingTransactionsView.swift
**File Location**: `CampusLink/Features/Wallet/Views/AllPendingTransactionsView.swift`  
**Add to Group**: Features → Wallet → Views

**Steps**:
1. In Xcode, navigate to the `Features/Wallet/Views` folder in the Project Navigator
2. Right-click on `Views` folder
3. Select "Add Files to CampusLink..."
4. Navigate to and select `CampusLink/Features/Wallet/Views/AllPendingTransactionsView.swift`
5. Make sure "CampusLink" target is checked
6. Click "Add"

### 3. PendingTransactionDetailView.swift
**File Location**: `CampusLink/Features/Wallet/Views/PendingTransactionDetailView.swift`  
**Add to Group**: Features → Wallet → Views

**Steps**:
1. In Xcode, navigate to the `Features/Wallet/Views` folder in the Project Navigator
2. Right-click on `Views` folder
3. Select "Add Files to CampusLink..."
4. Navigate to and select `CampusLink/Features/Wallet/Views/PendingTransactionDetailView.swift`
5. Make sure "CampusLink" target is checked
6. Click "Add"

## Quick Alternative Method

You can also add all files at once:
1. In Finder, select all 3 files:
   - `CampusLink/Core/Models/PendingTransactionModels.swift`
   - `CampusLink/Features/Wallet/Views/AllPendingTransactionsView.swift`
   - `CampusLink/Features/Wallet/Views/PendingTransactionDetailView.swift`
2. Drag them into Xcode Project Navigator
3. Drop them in their appropriate groups
4. Make sure "Copy items if needed" is UNCHECKED (files are already in the right location)
5. Make sure "CampusLink" target is checked
6. Click "Finish"

## Verification

After adding the files, verify:
- [ ] All 3 files appear in the Project Navigator
- [ ] Files are in the correct groups (Models and Wallet/Views)
- [ ] CampusLink target membership is checked for each file
- [ ] Project builds without errors (`Cmd+B`)

## What These Files Do

1. **PendingTransactionModels.swift**: Defines the unified transaction model that wraps offers, orders, and payouts
2. **AllPendingTransactionsView.swift**: Full-screen view showing all pending transactions with filtering and sorting
3. **PendingTransactionDetailView.swift**: Detail view for individual pending transactions

## Modified Files (Already Updated)

These files were automatically updated and should already be part of your project:
- ✅ `CampusLink/Features/Wallet/ViewModels/WalletViewModel.swift`
- ✅ `CampusLink/Features/Wallet/Views/WalletView.swift`

## Testing After Adding Files

1. Build the project (`Cmd+B`) - should build successfully
2. Run the app
3. Navigate to Wallet tab
4. Look for "Pending Transactions" section (replaced "Pending Offers")
5. Tap on a transaction to see detail view
6. Tap "See All" if you have more than 5 pending transactions
7. Test filtering and sorting in the All Pending Transactions view

## Troubleshooting

**If you see build errors**:
- Make sure all files are added to the CampusLink target
- Check that import statements are correct
- Clean build folder (Cmd+Shift+K) and rebuild

**If files don't appear**:
- Make sure you didn't check "Copy items if needed"
- Verify files are in the correct physical locations on disk
- Try removing and re-adding the files

**If you get "file not found" errors**:
- Right-click the file in Xcode → Show in Finder
- Verify the path matches the expected location
- Check file references in the File Inspector

