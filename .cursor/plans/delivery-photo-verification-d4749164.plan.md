<!-- d4749164-bb08-4311-932f-e02f9cf759f7 09fdcb75-45b3-41d2-9bcb-3c494542aa2c -->
# Delivery Photo Verification

## Overview

When sellers mark an order as delivered, they will be required to upload a photo as proof of delivery. This photo will be saved to Supabase storage and the URL stored in the database, visible to the buyer for verification.

## Implementation Steps

### 1. Database Schema Update (External - Supabase Dashboard)

Add a new column to the `orders` table:

- Column name: `delivery_photo_url`
- Type: `text` (nullable)
- Description: Stores the Supabase storage URL of the delivery proof photo

SQL to run in Supabase SQL editor:

```sql
ALTER TABLE public.orders 
ADD COLUMN delivery_photo_url text;
```

### 2. Storage Bucket Setup (External - Supabase Dashboard)

Create a new storage bucket for delivery photos:

- Bucket name: `delivery-photos`
- Public access: Yes (for viewing)
- File size limit: 5MB recommended
- Allowed file types: image/jpeg, image/png, image/webp

### 3. Update Order Model (`OrderModels.swift`)

- Add `deliveryPhotoUrl` property to the `Order` struct
- Update `CodingKeys` enum to include `delivery_photo_url`
- Add optional computed property for checking if delivery photo exists

**File:** `CampusLink/Core/Models/OrderModels.swift`

```swift
// Around line 163, add:
let deliveryPhotoUrl: String?

// In CodingKeys enum (around line 235), add:
case deliveryPhotoUrl = "delivery_photo_url"
```

### 4. Create Delivery Photo Upload View

Create a new SwiftUI view for photo capture and upload:

**New File:** `CampusLink/Features/Payments/Views/DeliveryPhotoUploadView.swift`

Features:

- Photo picker for selecting image from camera or library
- Image preview before upload
- Required field validation
- Upload progress indicator
- Cancel and confirm buttons
- Error handling with user-friendly messages

Key components:

- `@State` for selected image, upload state, error messages
- PhotosPicker for image selection
- Upload logic using Supabase storage API pattern (similar to `EditListingView.swift` lines 447-479)
- File naming: `{orderId}_delivery.jpg`
- Compression before upload using existing `UIImage+Resize.swift` extension

### 5. Update OrderService (`OrderService.swift`)

Modify the `markDelivered` function to require photo URL:

**Changes:**

- Update function signature at line 128: `func markDelivered(_ orderId: UUID, deliveryPhotoUrl: String) async throws -> Order`
- Add photo URL to the database update at line 145-151:
```swift
.update([
    "order_status": "seller_confirmed",
    "seller_confirmed_at": ISO8601DateFormatter().string(from: Date()),
    "delivery_photo_url": deliveryPhotoUrl,
    "updated_at": ISO8601DateFormatter().string(from: Date())
])
```


### 6. Update OrderDetailView UI (`OrderDetailView.swift`)

**Changes at line 335 (Mark as Delivered button):**

- Replace direct `markDelivered()` call with showing photo upload sheet
- Add `@State var showDeliveryPhotoSheet = false`
- Button action: `showDeliveryPhotoSheet = true`
- Add `.sheet` modifier to present `DeliveryPhotoUploadView`

**Add delivery photo display section:**

- Show delivery photo in order details if `deliveryPhotoUrl` exists
- Display in a new section below "Payment Details"
- AsyncImage with loading placeholder
- Tap to enlarge functionality (optional enhancement)

### 7. Update MyTransactionsView (`MyTransactionsView.swift`)

Update the `markDelivered` function at line 398:

- Similar changes as OrderDetailView
- Show delivery photo upload sheet before marking delivered
- Pass photo URL to OrderService

## Files to Modify

1. `CampusLink/Core/Models/OrderModels.swift` - Add delivery photo field
2. `CampusLink/Core/Services/OrderService.swift` - Accept photo URL parameter
3. `CampusLink/Features/Payments/Views/OrderDetailView.swift` - Add photo upload UI
4. `CampusLink/Features/Payments/Views/MyTransactionsView.swift` - Add photo upload UI

## Files to Create

1. `CampusLink/Features/Payments/Views/DeliveryPhotoUploadView.swift` - Photo upload sheet

## External Work (Supabase Dashboard)

1. Run SQL migration to add `delivery_photo_url` column to `orders` table
2. Create `delivery-photos` storage bucket with public read access
3. Configure bucket policies for authenticated uploads

## Testing Checklist

- [ ] Seller cannot mark delivered without uploading photo
- [ ] Photo uploads successfully to Supabase storage
- [ ] Photo URL is saved to database
- [ ] Buyer can view delivery photo in order details
- [ ] Error handling works for failed uploads
- [ ] Photo displays correctly across different screen sizes
- [ ] Works for both products and services

### To-dos

- [ ] Add delivery_photo_url column to orders table in Supabase
- [ ] Create delivery-photos storage bucket in Supabase with public read access
- [ ] Add deliveryPhotoUrl property and CodingKey to Order model
- [ ] Create DeliveryPhotoUploadView with photo picker and upload logic
- [ ] Modify markDelivered function to accept and save photo URL
- [ ] Replace mark delivered button with photo upload sheet and add photo display
- [ ] Add photo upload requirement to MyTransactionsView
- [ ] Test complete delivery photo flow from upload to display