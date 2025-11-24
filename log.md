## November 24, 2025 - Edit Listing Photo Deletion ✅

### Feature: Delete Photos When Editing Posts

#### Problem
User reported that when editing posts, there was no delete button to remove existing photos. They could only add new photos but couldn't remove unwanted ones from the listing.

#### Solution
Implemented photo deletion functionality for the edit listing flow:
- ✅ Added `deletedPhotoURLs` state variable to track which existing photos should be removed.
- ✅ Added delete buttons (X button) to existing photos display (lines 144-177).
- ✅ Added delete button to single photo fallback display (lines 178-210).
- ✅ Photos marked for deletion are hidden from the UI immediately.
- ✅ Updated save logic to filter out deleted photos before saving to database.
- ✅ If the main photo is deleted, it automatically sets the first remaining photo as the new main photo.

### Implementation Details

**State Management**:
- Added `@State private var deletedPhotoURLs: Set<String> = []` to track URLs of photos to be deleted.
- Photos in this set are filtered from display and from the save payload.

**UI Updates** (`EditListingView.swift`):
- **Multiple Photos Display** (lines 144-177):
  - Wrapped each existing photo in a `ZStack` with delete button overlay.
  - Delete button adds photo URL to `deletedPhotoURLs` set.
  - Photos in `deletedPhotoURLs` are conditionally hidden using `if !deletedPhotoURLs.contains(photoURL)`.
  
- **Single Photo Fallback** (lines 178-210):
  - Added delete button with same logic as multiple photos.
  - Updated condition to check `!deletedPhotoURLs.contains(photoURL)`.

**Save Logic** (lines 451-465):
- Filters `listing.photos` array to remove deleted photos: `listing.photos.filter { !deletedPhotoURLs.contains($0) }`.
- Checks if main photo was deleted and updates it to first remaining photo or nil.
- Maintains backward compatibility with single `photo` field.

### Files Modified
- `CampusLink/Features/Marketplace/Views/EditListingView.swift`

### User Experience
- Users can now delete unwanted photos when editing their listings.
- Deleted photos disappear immediately from the UI.
- Changes are persisted when "Save Changes" is tapped.
- Clean, intuitive X button matches the design for newly added photos.

---

## November 22, 2025 - Story & Sticker Sharing ✅

### Feature: Share Listings as Stickers for Instagram & Snapchat

#### Problem
User wanted a "Reddit-style" sharing experience:
- Visual "sticker" representing the post (Title, Price, Image).
- Ability to share to Instagram Stories and Snapchat easily.
- Link back to the app/store.

#### Solution
Implemented a custom Sticker generation and sharing flow:
- ✅ Created `ListingStickerView`: A SwiftUI view that renders a beautiful card with the listing image, title, price, and "Open App" CTA.
- ✅ Updated `ShareListingSheet`: Added options for "Instagram Stories" and generic "Share Sticker".
- ✅ Implemented `generateStickerImage`: Asynchronously downloads the listing image and renders the sticker view to a `UIImage` using `ImageRenderer` (iOS 16+).
- ✅ Instagram Integration: Uses `instagram-stories://share` URL scheme with pasteboard data to place the sticker on the user's story background.
- ✅ Added Deep Link Support: Attached `contentURL` to the Instagram share payload so the "Link" sticker or context is available.
- ✅ Snapchat/General Integration: Uses `UIActivityViewController` to share the rendered sticker image + URL. Apps like Snapchat will use the image, others might use both.
- ✅ Updated `Info.plist`: Added `LSApplicationQueriesSchemes` for `instagram-stories` and `snapchat` to verify app installation.

### Implementation Details

**Sticker View** (`CampusLink/Core/Components/ListingStickerView.swift`):
- Clean, rounded card design.
- Handles missing images gracefully with a placeholder.
- Includes "CampusLink" branding.

**Share Logic** (`CampusLink/Core/Components/ShareListingSheet.swift`):
- **Instagram Stories**: 
  - Generates sticker.
  - Sets `com.instagram.sharedSticker.stickerImage` in pasteboard.
  - Sets `com.instagram.sharedSticker.contentURL` for linking.
  - Opens `instagram-stories://share`.
- **Generic Sticker**:
  - Generates sticker.
  - Opens iOS Share Sheet with `[image, url]`.

**Configuration**:
- Added `LSApplicationQueriesSchemes` to `Info.plist`.

### Files Created/Modified
- `CampusLink/Core/Components/ListingStickerView.swift` (New)
- `CampusLink/Core/Components/ShareListingSheet.swift` (Modified)
- `CampusLink/Info.plist` (Modified)
