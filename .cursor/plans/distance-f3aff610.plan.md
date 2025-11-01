<!-- f3aff610-8786-46ba-8a37-5c9ec5cf67fc 6ed04955-7507-4209-ad1d-0117078e067e -->
# Add Distance Feature to Listing Cards

## Overview

Add distance display on each listing card showing how far the seller is from the current user. Implementation uses profile-based location (address stored in profile), Google Maps Distance Matrix API for walking/driving distance, privacy controls (approximate distance/hide completely), and user preference for units (miles/km).

## Key Components

### 1. Database Schema Changes (SQL)

**File**: `add_user_location.sql` (new)

Add location fields to `users` table:

- `location_address`: TEXT (user's profile address like "1234 Main St, City, State")
- `location_lat`: DECIMAL (cached geocoded latitude)
- `location_lng`: DECIMAL (cached geocoded longitude)
- `location_privacy`: TEXT (values: 'approximate', 'hidden', 'exact') - default 'approximate'
- `location_updated_at`: TIMESTAMP

### 2. Swift Model Updates

**File**: `CampusLink/Core/Models/ProductModels.swift`

Update `User` struct to include:

```swift
let locationAddress: String?
let locationLat: Double?
let locationLng: Double?
let locationPrivacy: String?
```

Add CodingKeys mappings for snake_case database fields.

### 3. Location Service (NEW)

**File**: `CampusLink/Core/Services/LocationService.swift` (new)

Create service to handle:

- Geocoding addresses to lat/lng (Google Geocoding API)
- Distance calculation between two coordinates using Google Maps Distance Matrix API
- Caching geocoded coordinates in database
- Privacy-aware distance formatting:
  - `approximate`: Show ranges like "< 0.5 mi", "0.5-1 mi", "1-2 mi", "2-5 mi", "> 5 mi"
  - `hidden`: Return nil (no distance shown)
  - `exact`: Show precise distance like "1.2 mi"

**API Key Storage**: Add Google Maps API key to `Secrets.swift`:

```swift
static let googleMapsApiKey: String = "YOUR_KEY_HERE"
```

### 4. User Settings Toggle

**File**: `CampusLink/Features/Profile/SettingsView.swift`

Add new "Distance Units" section under Appearance:

- Toggle between Miles/Kilometers using `@AppStorage("distanceUnit")`
- Default to miles

### 5. Profile Edit - Location Field

**File**: `CampusLink/Features/Profile/ProfileTabView.swift` → `EditProfileView`

Add location management section:

- Text field for address input
- Privacy dropdown: "Approximate distance", "Hide distance", "Show exact" 
- "Update Location" button that geocodes and saves to database
- Show current location if set

### 6. ListingCard Distance Display

**File**: `CampusLink/Features/Home/HomeTabView.swift` → `ListingCard`

Add distance display below author info (lines 814-836):

- Small icon (pin/location) + distance text
- Call LocationService to calculate distance
- Respect seller's privacy setting
- Use buyer's unit preference
- Gray/secondary color styling
- Handle cases: no location set, hidden, approximate, exact

Example UI:

```
📍 < 0.5 mi away
📍 1.2 mi away
📍 2.3 km away
(or nothing if hidden/not set)
```

### 7. Feature Flag

**File**: `CampusLink/Core/Config/AppConfig.swift`

Add feature flag:

```swift
static let enableDistanceFeature = true
```

## Implementation Order

1. Database schema - Run SQL migration to add location fields to users table
2. Update User model - Add location fields to Swift User struct
3. Add Google Maps API key - Add to Secrets.swift (external step)
4. LocationService - Create distance calculation service with API integration
5. Settings UI - Add distance unit toggle (miles/km)
6. Profile Edit UI - Add location address field and privacy controls
7. ListingCard UI - Display distance on each card
8. Apple Privacy Compliance - Update PrivacyInfo.xcprivacy and privacy.html
9. Testing - Test with various privacy settings and locations

## External Work Required

1. Get Google Maps API Key:

   - Enable Geocoding API
   - Enable Distance Matrix API
   - Add key to Secrets.swift

2. Database Migration:

   - Run `add_user_location.sql` via Supabase dashboard SQL editor

## Apple Privacy Compliance (CRITICAL)

This feature collects approximate location data and makes third-party API calls, requiring Apple privacy declarations.

### 1. Update PrivacyInfo.xcprivacy

**File**: `PrivacyInfo.xcprivacy`

Add new data collection type for approximate location in the NSPrivacyCollectedDataTypes array:

```xml
<dict>
  <key>NSPrivacyCollectedDataType</key><string>NSPrivacyCollectedDataTypeApproximateLocation</string>
  <key>NSPrivacyCollectedDataTypeLinked</key><true/>
  <key>NSPrivacyCollectedDataTypeTracking</key><false/>
  <key>NSPrivacyCollectedDataTypePurposes</key>
  <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
</dict>
```

Add network API access declarations (new root-level key):

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryNetworking</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array>
      <string>CA92.1</string>
    </array>
  </dict>
</array>
```

### 2. Update privacy.html

**File**: `privacy.html`

Add new items under "What We Collect" section:

**Under "Personal Information":**

- Location Address: Optional user-provided address for calculating distances to sellers

**New "Third-Party Services" subsection:**

- Google Maps API: Used for geocoding addresses and calculating walking distances

Add to "App Store Privacy Nutrition Label" table (new row):

```html
<tr>
    <td>Approximate Location</td>
    <td>Yes</td>
    <td>Yes</td>
    <td>No</td>
    <td>App Functionality</td>
</tr>
```

Update changelog section with new version entry.

### 3. App Store Connect Privacy Labels

When submitting next update, declare in App Store Connect:

**Data Type**: Approximate Location

- Usage: App Functionality
- Linked to User: Yes
- Used for Tracking: No
- Description: "We collect your optional address to show distance between buyers and sellers. You control privacy settings: show approximate distance, hide completely, or show exact distance."

### 4. Important Notes

- NO CoreLocation permissions needed (using profile-based addresses, not GPS)
- NO Info.plist location keys required (NSLocationWhenInUseUsageDescription, etc.)
- Rejection risk if privacy declarations missing
- Must declare Google Maps API domain access

## Privacy and UX Notes

- Never show exact address, only distance
- Sellers control privacy level (approximate/hidden/exact)
- Buyers can't see exact location even if seller chooses "exact" distance
- If either user has no location set, no distance shown
- Graceful fallbacks if API fails
- Cache geocoded coordinates to minimize API calls

### To-dos

- [ ] Create and document SQL migration for user location fields
- [ ] Add location fields to User struct in ProductModels.swift
- [ ] Create LocationService with Google Maps API integration for geocoding and distance calculation
- [ ] Add distance unit toggle (miles/km) to SettingsView
- [ ] Add location address field and privacy controls to EditProfileView
- [ ] Display distance on ListingCard with privacy-aware formatting
- [ ] Add enableDistanceFeature flag to AppConfig.swift
- [ ] Update PrivacyInfo.xcprivacy with approximate location data type and network API declarations
- [ ] Update privacy.html to document location data collection and Google Maps API usage
- [ ] Test distance feature with various privacy settings and locations