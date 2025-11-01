# Adding ProductVerificationInfoView.swift to Xcode Project

If Xcode doesn't automatically detect the new file, follow these steps:

## Steps to Add File Manually:

1. **Open Xcode** and your CampusLink project

2. **Navigate to** `CampusLink/Shared/Views/` in the Project Navigator (left sidebar)

3. **Right-click** on the "Views" folder (inside Shared)

4. **Select** "Add Files to CampusLink..."

5. **Navigate to and select**: `CampusLink/Shared/Views/ProductVerificationInfoView.swift`

6. **Make sure** the following options are checked:
   - ✅ Copy items if needed (should be unchecked since file is already in place)
   - ✅ Create groups (not folder references)
   - ✅ Add to targets: CampusLink

7. **Click** "Add"

8. **Build the project** (⌘B) to verify everything compiles

## Alternative: Drag and Drop

You can also drag the `ProductVerificationInfoView.swift` file from Finder directly into the "Views" folder (inside Shared) in Xcode's Project Navigator.

---

**File Location**: `/Users/eileenmurphy/CampusLink/CampusLink/Shared/Views/ProductVerificationInfoView.swift`

## What This Component Does

This new component provides an expandable FAQ dropdown for product listings that explains the escrow and photo verification process. It shows different messaging for buyers ("How do I make sure I receive the product?") vs sellers ("How do I make sure I get paid for my product?").

The component has been integrated into:
- TabViews.swift (create listing flow)
- ListingDetailView.swift (view product details)
- EditListingView.swift (edit existing listings)

Once added to Xcode, you can delete this instruction file.

