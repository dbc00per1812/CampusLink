# UUID Type Fix Summary

## What Broke
When trying to fix the offer payment JSON errors, I mistakenly changed database insert structs to use `UUID` types instead of `String`. This broke EVERYTHING - normal checkout, offers, messaging.

## The Issue
Supabase/PostgreSQL expects UUID values as STRINGS in JSON, not as UUID types.

### What I Changed (Wrong):
```swift
struct OrderInsert: Codable {
    let listingId: UUID  // ❌ WRONG
    let buyerId: UUID    // ❌ WRONG
    let sellerId: UUID   // ❌ WRONG
    ...
}
```

### What It Should Be:
```swift
struct OrderInsert: Codable {
    let listingId: String  // ✅ CORRECT
    let buyerId: String    // ✅ CORRECT
    let sellerId: String   // ✅ CORRECT
    ...
}
```

## Why This Happened
1. Swift models use `UUID` type for type safety
2. When sending to database, we must convert to `String` using `.uuidString`
3. Database stores UUIDs as strings and expects string format in JSON

## Files Fixed
1. `OrderModels.swift` - Reverted `OrderInsert` to use String
2. `OrderService.swift` - Added `.uuidString` conversions
3. `OfferComposeView.swift` - Reverted `OfferInsert`, `ConversationInsert`, `MessageInsert` to use String

## The Rule
**For database operations:**
- Model structs (like `Order`, `Listing`) can use `UUID` type
- Insert/Update structs MUST use `String` for UUID fields
- Always convert with `.uuidString` before database operations

## Test Cases
1. Normal checkout (Buy Now) - FIXED ✅
2. Offer creation - FIXED ✅
3. Offer acceptance with payment - WORKING ✅
4. Message/conversation creation - FIXED ✅

## Lesson Learned
Don't change fundamental data types without understanding how they're used throughout the system. The database expects strings, period.
