# CampusLink Development Log

## Payout Cancellation with Stripe Integration Fix

### Issue: Payout cancellation was not integrated with Stripe

### Changes Made:

#### 1. Created Supabase Edge Function: cancel_payout
- Validates user authentication and payout ownership
- Cancels Stripe transfers when possible
- Restores wallet balance atomically

#### 2. Updated PayoutService  
- Modified cancelPayout() to call the Edge Function
- Added proper error handling

#### 3. Enhanced UI Feedback
- Added success message when payout is cancelled
- Extended cancel button to processing payouts

### Status: ✅ COMPLETED


## Stripe Transaction Fee Handling

### Issue: Stripe fees were not properly displayed or accounted for

### Changes Made:

#### 1. Updated Edge Function: create_payment_intent
- Calculates Stripe processing fee (2.9% + 30¢)
- Adds fee to total payment amount
- Stores fee breakdown in metadata
- Returns fee information to client

#### 2. Updated PaymentService
- Modified preparePaymentSheet to return fee information
- Updated configurePaymentSheet to handle fees
- Added debug logging for fee amounts

#### 3. Updated UI Components
- ListingDetailView: Shows estimated fee and total upfront
- ListingCard (Home): Displays total price with fees
- ProfileTabView: Shows price with fee indicator
- MyListingCard: Includes total price display

#### 4. Fee Calculation
- Base price + (2.9% + $0.30) = Total charged to buyer
- Fees shown transparently before purchase
- Wallet payments have no processing fees
- Card payments include Stripe fees

### Status: ✅ COMPLETED


## PayoutService Compilation Error Fix

### Issue: Build errors after updating cancelPayout function

### Error Details:
- Value of tuple type '()' has no member 'status'
- Value of tuple type '()' has no member 'data'
- Type ambiguity in response handling

### Fix Applied:
- Updated cancelPayout to match Supabase SDK pattern
- Created CancelPayoutResponse struct for typed response
- Functions.invoke returns decoded type directly, not a response wrapper
- Removed incorrect status/data property access

### Status: ✅ BUILD SUCCEEDED


## Order Completion Flow UI Improvements

### Issue: Better feedback needed for order completion actions

### Changes Made:

#### 1. OrderDetailView Enhancements
- Added success overlay with checkmark animation
- Shows different messages for buyers vs sellers
- Automatic page refresh after successful action
- Two options: Done (dismiss) or View Order Details
- Blurs background during success state

#### 2. MyTransactionsView Improvements  
- Added success toast notifications
- Auto-dismissing after 3 seconds
- Different messages for services vs products
- Smooth slide-in animation from top

#### 3. User Experience Flow
- Mark Delivered (Seller): Shows success → Updates order status
- Confirm Received (Buyer): Shows success → Releases payment
- Buttons disappear after action completes
- Order status updates automatically

### Status: ✅ BUILD SUCCEEDED


## Payment Error Fix: 'The data couldn't be read because it is missing'

### Issue: Generic error when trying to book service with credit card

### Root Cause:
- PaymentIntent client_secret could be null/undefined
- Response decoding failed silently without proper error messages
- Edge Function didn't validate client_secret existence

### Changes Made:

#### 1. Edge Function (create_payment_intent)
- Added validation to ensure client_secret exists
- Better error message if PaymentIntent creation fails
- Explicit error thrown if no client_secret returned

#### 2. PaymentService (iOS)
- Made response fields optional to handle missing data
- Added error field to response structure
- Better error logging for debugging
- Shows actual server error messages to user
- Logs response data when decoding fails

### Benefits:
- Clear error messages instead of generic 'data missing'
- Easier debugging with response logging
- Prevents silent failures
- Better user feedback

### Status: ✅ BUILD SUCCEEDED


## Edge Functions Deployment - Payment Flow Fixed

### Issue: Payment error 'invalid response from server'

### Root Cause:
- Edge Functions were not deployed with latest changes
- Server was returning old format without fee information
- iOS app expected new format with fees

### Solution:
1. Deployed create_payment_intent with fee calculations
2. Deployed cancel_payout for Stripe integration
3. Made iOS app backward compatible with both formats

### Deployed Functions:
- create_payment_intent: Now returns fees properly
- cancel_payout: New function for Stripe cancellation

### Status: ✅ DEPLOYED & BUILD SUCCEEDED


## Transaction Display Fix

### Issue: Cancelled/failed transactions showing in UI

### Root Cause:
- MyTransactionsView was loading ALL orders without filtering
- WalletService was loading ALL payments without filtering
- Both were showing cancelled and failed transactions

### Solution:
1. Updated MyTransactionsView.loadData() to filter out:
   - Orders with order_status = 'cancelled'
   - Orders with payment_status = 'failed'

2. Updated WalletService.getTransactionHistory() to filter out:
   - Payments with status = 'failed'
   - Payments with status = 'cancelled'

### Files Modified:
- CampusLink/Features/Payments/Views/MyTransactionsView.swift
- CampusLink/Core/Services/WalletService.swift

### Status: ✅ FIXED


## Order Details UI Cleanup

### Issue: Debug info and order details cluttering the UI

### Root Cause:
- Debug info and order information sections were always visible
- Taking up unnecessary screen space and making UI look cluttered

### Solution:
1. Added @State private var showOrderInfo = false to control visibility
2. Created collapsible dropdown section with:
   - Clickable header with chevron icon animation
   - Smooth animation when expanding/collapsing
   - Combined debug info and order details in one dropdown
   - Improved styling with better spacing and backgrounds

### Features:
- Header shows 'Order Information' with chevron that rotates
- Expandable content shows both debug info and order details
- Smooth animations for better UX
- Positioned at bottom of page to avoid cluttering main content

### Files Modified:
- CampusLink/Features/Payments/Views/OrderDetailView.swift

### Status: ✅ FIXED


## Payout Setup Requirement for Posting

### Issue: Users could post listings without setting up payouts

### Root Cause:
- No validation to check if users had completed Stripe Connect onboarding
- Users could post listings but couldn't receive payments

### Solution:
1. Added user profile loading to PostView with new state variables:
   - @State private var userProfile: User? = nil
   - @State private var isLoadingProfile = true

2. Created conditional UI flow:
   - Loading state while fetching user profile
   - Payout required view if stripePayoutsEnabled != true
   - Normal posting form if payouts are enabled

3. Payout required view features:
   - Clear explanation of why payouts are required
   - Step-by-step instructions (Go to Wallet → Complete onboarding → Return)
   - Refresh status button to check again after setup
   - Professional UI with proper spacing and colors

4. Added loadUserProfile() function:
   - Fetches user profile from Supabase
   - Checks stripePayoutsEnabled status
   - Graceful error handling with fallback profile

### Files Modified:
- CampusLink/Core/Navigation/TabViews.swift (PostView)

### Status: ✅ IMPLEMENTED


## Fixed Compilation Errors in PostView

### Issue: 44 compilation errors in TabViews.swift

### Root Cause:
- When restructuring PostView to add payout validation, the modifiers and structure got mixed up
- State variables weren't properly accessible in the new structure
- NavigationView and .onAppear modifiers were in wrong places

### Solution:
1. Wrapped main body in NavigationView for proper navigation
2. Moved .onAppear modifier to the main body level (outside NavigationView)
3. Fixed indentation and structure of postingFormView modifiers
4. Ensured all state variables are accessible throughout the view

### Files Fixed:
- CampusLink/Core/Navigation/TabViews.swift

### Status: ✅ ALL COMPILATION ERRORS RESOLVED


## Fixed Payout Status Refresh Issue

### Issue: Payout setup required screen persists after completing Stripe Connect

### Root Cause:
- stripe_payouts_enabled field only gets updated via Stripe webhooks
- Webhooks might have delays or not fire immediately
- Refresh Status button only reloaded cached user profile

### Solution:
1. Created new Edge Function 'check_stripe_status':
   - Directly queries Stripe API for current account status
   - Compares with database and updates if different
   - Returns real-time payout status

2. Updated PostView refresh logic:
   - Added checkStripeStatusAndRefresh() function
   - Calls new Edge Function to sync Stripe status
   - Reloads user profile after status update

3. Enhanced error handling:
   - Graceful fallback to profile reload if Edge Function fails
   - Debug logging for troubleshooting

### Files Added/Modified:
- supabase/functions/check_stripe_status/index.ts (NEW)
- supabase/functions/check_stripe_status/deno.json (NEW)
- CampusLink/Core/Navigation/TabViews.swift

### Status: ✅ DEPLOYED & READY TO TEST


## Fixed Compilation Errors in TabViews.swift

### Issue: 2 compilation errors after adding Stripe status check

### Errors:
1. Cannot find 'FunctionInvokeOptions' in scope
2. Cannot infer contextual base in reference to member 'post'

### Root Cause:
- Used incorrect Supabase function invocation syntax
- FunctionInvokeOptions with method parameter not needed for simple POST

### Solution:
- Simplified supabase.functions.invoke() call
- Removed unnecessary FunctionInvokeOptions wrapper
- Used direct invoke syntax: supabase.functions.invoke("function_name")

### Files Fixed:
- CampusLink/Core/Navigation/TabViews.swift

### Status: ✅ COMPILATION ERRORS RESOLVED


## Removed Payout Setup Requirement

### Issue: Payout setup check not working despite successful Stripe Connect

### Root Cause:
- Database sync issues between Stripe and Supabase
- stripe_payouts_enabled field not updating reliably
- Complex verification logic causing false negatives

### Solution:
- Temporarily removed the payout setup requirement check
- PostView now directly shows the posting form
- Users can post listings immediately

### Files Modified:
- CampusLink/Core/Navigation/TabViews.swift
  - Removed conditional check for stripePayoutsEnabled
  - Direct navigation to postingFormView

### Status: ✅ POSTING NOW ENABLED - No payout check required

### TODO: Re-implement payout verification with more reliable method later


## Production-Ready Stripe Connect Verification

### Issue: Payout verification not working properly

### Root Cause:
- Previous implementation relied on database fields that weren't syncing
- No direct verification with Stripe API via connect_onboarding

### Solution - Production Implementation:
1. Direct Stripe Connect verification using connect_onboarding Edge Function
2. Real-time status check on PostView appear
3. Automatic database update when Stripe confirms account is ready
4. Proper error handling and user feedback
5. Clear separation of loading, verification, and display states

### How it Works:
1. User opens Post tab → checkStripeConnectStatus() runs
2. Loads user profile to get stripe_connect_id
3. Calls connect_onboarding Edge Function (same as Wallet)
4. Checks onboarding_complete and payouts_enabled flags
5. Updates database if Stripe says ready but DB says not
6. Shows posting form only if verified ready

### Files Modified:
- CampusLink/Core/Navigation/TabViews.swift
  - Added proper state management
  - Implemented checkStripeConnectStatus()
  - Direct Stripe API verification
  - Automatic database sync

### Status: ✅ PRODUCTION-READY IMPLEMENTATION


## Service Listings Database Schema Verification

### Date: [Current Date]

### Verification Requested: User wants to confirm database is properly set up for service listings

### Database Schema Analysis:

#### 1. listings Table - Service Support ✅
- `listing_type`: enum with 'product' and 'service' options ✅
- `service_type`: enum with 'calendar' and 'slots' options ✅
- `service_duration`: text field for duration info ✅
- `service_location`: enum with 'on_campus', 'off_campus', 'remote' options ✅
- `service_availability`: text field (can store JSON for calendar model) ✅
- `slots_available`: integer for simple slots model ✅
- `max_bookings_per_slot`: integer for group services ✅
- `reserved_by` and `reserved_until`: for reservation system ✅

#### 2. service_bookings Table ✅
- `id`: Primary key
- `order_id`: Links to order/transaction
- `scheduled_at`: timestamp for when service is scheduled
- `duration_minutes`: integer for service duration
- `location`: text for service location details
- `special_requests`: text for buyer requests
- `status`: text for booking status (scheduled, completed, etc.)
- `created_at`: timestamp for booking creation

#### 3. Supporting Tables:
- `orders`: Links service bookings to payment flow ✅
- `payments`: Handles payment processing for services ✅
- `conversations`: Enables buyer-seller communication ✅
- `messages`: For service-related discussions ✅

### Conclusion:
The database is FULLY CONFIGURED for the service listing models described:
1. ✅ Simple "Slots Available" Model - supported via slots_available field
2. ✅ Calendar/Time-Based Model - supported via service_availability (JSON) and service_bookings table
3. ✅ Date Range + Capacity Model - supported via combination of fields

All recommended fields and tables are already in place. The schema supports:
- Different service types (calendar vs slots)
- Service availability tracking 
- Booking management with timestamps
- Location preferences
- Special requests
- Full integration with payment and order system

### Status: ✅ DATABASE VERIFIED - READY FOR SERVICE IMPLEMENTATION

## Phase 6: Service Flexibility Implementation (UI Updates)

### Date: $(date +"%Y-%m-%d %H:%M")

### Context
User requested correlating UI updates after we implemented the database schema changes for service flexibility. This includes adding new service fields to the models and UI for creating/editing listings.

### Changes Made

#### 1. **Updated ProductModels.swift**
- **Added ServiceType enum** with calendar and slots options:
  ```swift
  enum ServiceType: String, Codable, CaseIterable {
      case calendar = "calendar"
      case slots = "slots"
      
      var displayName: String {
          switch self {
          case .calendar: return "Calendar-based"
          case .slots: return "Time Slots"
          }
      }
      
      var description: String {
          switch self {
          case .calendar: return "Flexible scheduling based on your availability"
          case .slots: return "Pre-defined time slots with limited capacity"
          }
      }
  }
  ```

- **Updated all listing models** (Listing, ListingCreate, ListingWithUser) to include:
  - `serviceType: ServiceType?`
  - `slotsAvailable: Int?`
  - `maxBookingsPerSlot: Int?`
  - `archived: Bool?`

- **Updated CodingKeys** to map to database columns:
  - `service_type`
  - `slots_available`
  - `max_bookings_per_slot`
  - `archived`

#### 2. **Updated PostView in TabViews.swift**
- **Added new state variables**:
  ```swift
  @State private var selectedServiceType = ServiceType.calendar
  @State private var slotsAvailable = ""
  @State private var maxBookingsPerSlot = ""
  ```

- **Added service type UI fields** with conditional logic:
  - Service Type picker with descriptions
  - Slots configuration fields (only visible when service_type == .slots)
  - Number pad keyboard for numeric inputs

- **Updated createListing() function** to include new fields:
  ```swift
  serviceType: selectedListingType == .service ? selectedServiceType : nil,
  slotsAvailable: selectedListingType == .service && selectedServiceType == .slots ? (slotsAvailable.isEmpty ? nil : Int(slotsAvailable)) : nil,
  maxBookingsPerSlot: selectedListingType == .service && selectedServiceType == .slots ? (maxBookingsPerSlot.isEmpty ? nil : Int(maxBookingsPerSlot)) : nil,
  archived: false
  ```

- **Updated clearForm()** to reset new fields

#### 3. **Updated EditListingView.swift**
- **Enhanced ListingUpdate struct** with new service fields
- **Added state variables** for editing existing listings
- **Added conditional UI fields** for service type and slot configuration
- **Updated initialization** to populate fields from existing listing data
- **Updated save function** to include new fields in database update

### Key Features Implemented

#### Service Type Selection
- **Calendar-based**: Flexible scheduling for services like tutoring, consulting
- **Time Slots**: Fixed slots with capacity limits for services like study sessions, workshops

#### Slot Configuration (when service_type = "slots")
- **Number of Time Slots**: How many different time slots are available
- **Max Bookings per Slot**: Capacity limit per slot (optional for unlimited)

#### Smart Field Visibility
- Service fields only show when listing_type = "service"
- Slot configuration only shows when service_type = "slots"
- Maintains clean, intuitive UI flow

### Database Integration
- All new fields properly mapped to database columns
- Safe handling of optional/nullable fields
- Backward compatibility with existing listings (new fields are optional)

### UI/UX Improvements
- Clear field labels and placeholder text
- Numeric keypad for slot-related fields
- Descriptive picker options with explanations
- Consistent styling with existing form fields

### Testing Readiness
The implementation is complete and ready for testing:
- **Create new service listings** with both calendar and slots types
- **Edit existing service listings** to add slot configuration
- **Form validation** for numeric fields
- **Database storage** of all new service fields

### Next Steps
Ready for user testing of the enhanced service creation/editing flow with the new flexibility options.

### Status: ✅ SERVICE UI IMPLEMENTATION COMPLETE

## Compilation Error Fixes

### Date: $(date +"%Y-%m-%d %H:%M")

### Issue
After implementing the new service fields, there were compilation errors due to missing arguments in constructor calls for `Listing` and `ListingWithUser` objects.

### Errors Fixed

#### 1. **TabViews.swift - toggleSoldStatus function**
- **Location**: Line ~820 in `toggleSoldStatus()` function
- **Issue**: `Listing(...)` constructor missing new service fields
- **Fix**: Added missing parameters:
  ```swift
  serviceType: listing.serviceType,
  slotsAvailable: listing.slotsAvailable,
  maxBookingsPerSlot: listing.maxBookingsPerSlot,
  archived: listing.archived,
  ```

#### 2. **ActionButton.swift - Preview data**
- **Location**: Line ~240 in `ActionButton_Previews`
- **Issue**: `ListingWithUser(...)` constructor in preview missing new service fields
- **Fix**: Added missing parameters:
  ```swift
  serviceType: nil,
  slotsAvailable: nil,
  maxBookingsPerSlot: nil,
  archived: false,
  ```

### Verification
- ✅ All linting errors resolved
- ✅ No compilation errors found
- ✅ All constructor calls now include required service fields

### Status: ✅ ALL COMPILATION ERRORS FIXED

## Phase 7: Time Slot Booking System Implementation

### Date: $(date +"%Y-%m-%d %H:%M")

### Context
User requested implementation of the buyer-facing time slot selection interface. Previously, we had only implemented the seller side (posting services with time slots), but buyers had no way to select specific time slots when booking slot-based services.

### Major Features Implemented

#### 1. **Time Slot Data Models** (`TimeSlotModels.swift`)
- **TimeSlot**: Core model representing available time slots
  - Properties: start/end time, max bookings, current bookings, status
  - Computed properties: isAvailable, spotsRemaining, formatted strings
- **TimeSlotBooking**: Represents individual user bookings
  - Statuses: reserved (temp), confirmed (paid), cancelled, completed
- **SlotStatus & BookingStatus**: Enums with display properties
- **API Models**: TimeSlotCreate, SlotBookingCreate for database operations

#### 2. **Time Slot Service** (`TimeSlotService.swift`)
- **Core Functionality**:
  - `getTimeSlotsForListing()`: Fetch available slots for a service
  - `reserveTimeSlot()`: Temporarily reserve a slot (10-min expiration)
  - `confirmBooking()`: Confirm reservation after payment
  - `cancelReservation()`: Cancel temporary reservation
  - `cleanupExpiredReservations()`: Remove expired temp reservations
- **Business Logic**:
  - Prevents double-booking same user/slot
  - Automatic booking count updates
  - Slot status management (available → full)

#### 3. **Time Slot Selection UI** (`TimeSlotSelectionView.swift`)
- **Modern Interface**:
  - Service header with photo, title, price
  - Scrollable list of available time slots
  - Real-time capacity display ("3/8 spots remaining")
  - Visual status indicators (Available, Full, etc.)
  - Slot selection with confirmation dialog
- **Smart UX**:
  - Empty state when no slots available
  - Selected slot summary at bottom
  - 10-minute reservation warning
  - Disabled state for full/unavailable slots

#### 4. **Enhanced Buyer Flow** (`ListingDetailView.swift`)
- **Service Type Detection**:
  - Calendar services: Direct payment (existing flow)
  - Slot services: Time slot selection → payment
- **New Flow**: Browse Service → Select Slot → Choose Payment → Confirm
- **State Management**:
  - Time slots loading/caching
  - Selected slot preservation through payment flow
  - Error handling for slot operations

#### 5. **Order System Integration** (`OrderModels.swift` & `OrderService.swift`)
- **Enhanced Models**:
  - Added `timeSlotId` to Order, OrderCreate, OrderInsert
  - Proper database column mapping
  - Backward compatibility with non-slot orders
- **Order Creation**: Links orders to specific time slots
- **Future-ready**: Foundation for slot-specific order management

#### 6. **Database Schema** (`time_slots_schema.sql`)
- **New Tables**:
  - `time_slots`: Core slot data with constraints
  - `time_slot_bookings`: Individual user bookings
- **Enhanced Orders**: Added `time_slot_id` foreign key
- **Advanced Features**:
  - Automatic booking count triggers
  - Expired reservation cleanup function
  - Comprehensive RLS policies
  - Performance indexes

### User Experience Flow

#### **For Slot-Based Services:**
```
1. Browse Service Listing
2. Tap "Book Service"
3. → Time Slot Selection Interface Appears
4. View available slots with capacity
5. Select desired time slot
6. Confirm reservation (10-min hold)
7. → Payment Method Selection
8. Complete payment
9. → Booking Confirmed with Slot Details
```

#### **For Calendar Services:**
```
1. Browse Service Listing  
2. Tap "Book Service"
3. → Direct to Payment (existing flow)
4. Complete payment
5. → Coordinate timing separately with seller
```

### Technical Implementation Highlights

#### **Smart UI Disclosure**
- Time slot selection only appears for `serviceType == .slots`
- Calendar services use existing direct payment flow
- Seamless integration with existing payment system

#### **Reservation System**
- 10-minute temporary reservations prevent double-booking
- Automatic cleanup of expired reservations
- Real-time capacity tracking and updates

#### **Database Integrity**
- Foreign key relationships ensure data consistency
- Triggers automatically maintain booking counts
- RLS policies protect user data and seller permissions

#### **Error Handling**
- Graceful handling of slot unavailability
- User-friendly error messages
- Fallback to contact seller option

### Current Status

#### **✅ Fully Implemented**
- Time slot data models and service logic
- Modern, intuitive slot selection UI
- Complete buyer booking flow for slot services
- Order system integration with slot tracking
- Database schema with advanced features

#### **🚧 Requires Database Setup**
- Run `time_slots_schema.sql` in Supabase to create tables
- Apply RLS policies and triggers
- Optionally add sample data for testing

#### **📱 Ready for Testing**
The implementation is complete and ready for end-to-end testing:
1. Create slot-based service listings
2. Browse and select time slots as buyer
3. Complete payment with slot reservation
4. Verify order includes slot information

### Next Steps
- Apply database schema in Supabase
- Test complete slot booking flow
- Add seller dashboard for managing time slots
- Implement slot modification/cancellation features

### Status: ✅ TIME SLOT BOOKING SYSTEM COMPLETE

## Phase 0 - Seek Mode Feature Flag & Stubs (Completed)

**Human explanation:** Added a feature flag to safely merge Seek UI while keeping it hidden until database supports NULL price for seek posts.

**What was done:**
1. Created `AppConfig.swift` with `enableSeekMode` flag (default false)
2. Added `ListingIntent` enum (.offer/.seek) to ProductModels
3. Added `Offer` model for seller responses to seeks
4. Updated PostView with:
   - Seek mode state variables (intent, budgetMin, budgetMax, expiresDate)
   - Conditional UI showing Sell|Seek toggle when flag enabled
   - Budget fields instead of price for seeks
   - Validation and button text changes
   - Guard to block seek posts with "coming soon" message
5. Created stub components:
   - `OfferComposeView` - for sellers to respond to seeks
   - `OffersListView` - for seekers to view/manage offers

**Key decisions:**
- Feature flag defaults to false for safety
- Seek UI is fully hidden when flag is off
- When enabled, UI shows but posting is blocked with friendly message
- All new code compiles without errors
- Ready for Phase 1 database indexes

**Next steps:** Run Phase 1 SQL in Supabase to add indexes and RLS policies.

## Phase 2 - Client Models & UI (Completed)

**Completed all Phase 2 tasks:**

1. **✅ Updated Models with Seek Fields**
   - Added `ListingIntent` enum (offer/seek)
   - Added `Offer` struct for future use
   - Updated `Listing`, `ListingCreate`, and `ListingWithUser` with:
     - `intent: ListingIntent`
     - `budgetMin: Double?`
     - `budgetMax: Double?`
     - `expiresAt: Date?`
   - Fixed all compilation errors related to model changes

2. **✅ Updated PostView createListing()**
   - Modified `createListing()` in TabViews.swift to send new seek fields
   - Updated `toggleSoldStatus()` to include seek fields
   - Fixed ActionButton.swift preview data

3. **✅ Added Feed/Profile Filters**
   - Created `ListingFilter` enum in HomeTabView (All/For Sale/Wanted)
   - Added filter UI with pills that toggle between filters
   - Updated `loadListings()` and `loadMoreListings()` to apply intent filter
   - Filter only shows when `AppConfig.enableSeekMode = true`

4. **✅ Added Wanted Badges to Seek Cards**
   - Updated ListingCard to show:
     - Orange "Wanted" badge for seek posts
     - Budget range instead of price
     - Expiration date if available
   - Proper formatting for budget ranges (min-max or "Up to max")

5. **✅ Updated ListingDetailView**
   - Shows budget instead of price for seek posts
   - Added seek-specific action buttons:
     - For sellers: "Offer My Item" and "Contact Seeker"
     - For seekers: "View Offers", "Edit", and "Delete"
   - Added stub functions for future implementation:
     - `handleOfferMyItem()` - will navigate to OfferComposeView
     - `handleViewOffers()` - will navigate to OffersListView

**Technical Notes:**
- All changes are feature-flagged behind `AppConfig.enableSeekMode`
- UI properly handles both offer and seek posts
- Code compiles without errors
- Ready for Phase 3 database changes

**Next steps:** Phase 3 - Update database constraint to allow null prices for seek posts.
