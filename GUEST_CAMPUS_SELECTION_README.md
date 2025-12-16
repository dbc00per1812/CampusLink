# Guest Campus Selection Feature

## Overview
This feature allows guest users (users without an account) to select a campus and browse campus-specific listings without signing up.

## Implementation Summary

### Files Created
1. **GuestCampusSelectionView.swift** (`ios-swift/CampusLink/Core/Auth/GuestCampusSelectionView.swift`)
   - Campus selection UI with all available campuses
   - Stores selection in AppStorage for persistence

### Files Modified
1. **WelcomeView.swift** - "Browse as Guest" now shows campus selection
2. **HomeTabView.swift** - All listing load methods support guest campus filtering
3. **GuestProfileView.swift** - Added campus selector in settings

### How It Works

#### For Guest Users:
1. User taps "Browse as Guest" on welcome screen
2. Campus selection screen appears
3. User selects their campus (e.g., "Indiana University Bloomington")
4. Listings are filtered to show only items from that campus
5. Campus preference is saved and persists across app launches
6. User can change campus anytime from Profile → Settings → Campus

#### Technical Details:
- **Storage**: Uses `@AppStorage("guestSelectedCampus")` to persist selection
- **Filtering**: Same server-side campus filtering as authenticated users
- **Scope**: Works across all listing views (For You, All, Selling, Wanted, Categories)

### Testing Instructions

1. **Open Xcode** and ensure the new file is added to the project:
   - In Xcode, right-click on `ios-swift/CampusLink/Core/Auth/` folder
   - Select "Add Files to CampusLink..."
   - Navigate to and select `GuestCampusSelectionView.swift`
   - Ensure "Copy items if needed" is unchecked
   - Click "Add"

2. **Build and run** the app

3. **Test guest browsing flow**:
   - Delete the app from simulator/device (to clear AppStorage)
   - Launch the app
   - You should see the welcome screen
   - Tap "Browse as Guest"
   - Campus selection screen should appear
   - Select a campus (e.g., "Indiana University Bloomington")
   - You should see the home screen with listings
   - Verify listings are filtered by the selected campus

4. **Test campus persistence**:
   - Force quit the app
   - Relaunch the app
   - You should still see listings from the same campus

5. **Test campus change**:
   - Go to Profile tab (should show Guest Profile)
   - Tap on "Campus" in Settings section
   - Select a different campus
   - Verify listings refresh to show new campus

6. **Test sign-up clears guest data**:
   - Sign up for a new account
   - Guest campus should no longer affect listings
   - User's selected campus from signup should be used instead

### Code Architecture

#### AppStorage Key
```swift
@AppStorage("guestSelectedCampus") private var guestSelectedCampus: String = ""
```

#### Campus Detection Logic (HomeTabView)
```swift
if let currentUserId = authManager.session?.user.id.uuidString {
    // Authenticated: fetch from database
    currentCampus = user.campus
} else {
    // Guest: read from AppStorage
    currentCampus = UserDefaults.standard.string(forKey: "guestSelectedCampus")
}
```

#### Server-Side Filtering
```swift
.eq("users.campus", value: campusValue)  // Filters at database level
```

### Edge Cases Handled

1. **No campus selected**: Won't happen - campus selection is required before browsing
2. **Campus not found**: Returns all listings (graceful degradation)
3. **Sign up/login**: Guest campus is ignored once authenticated
4. **Multiple campuses**: Each campus has isolated listings
5. **Campus changes**: Listings automatically refresh

### Future Enhancements

- Location-based campus suggestions
- Campus-specific welcome messages
- Show listing count per campus on selection screen
- Campus logos/images on selection cards
- "Recently viewed campuses" for quick switching

## Support

If you encounter any issues:
1. Check Xcode console for debug logs (prefix: 🔍 or 🎯)
2. Verify the new file is added to the Xcode project target
3. Clean build folder (Cmd+Shift+K) and rebuild
4. Reset UserDefaults: Settings app → Your App → Reset

---

**Created**: December 8, 2025
**Status**: Complete and ready for testing

