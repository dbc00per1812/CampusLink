# Deploy: Archive Listing on Offer Accept

## What This Does

Automatically archives a listing when an offer is accepted, preventing:
- Duplicate sales
- Listing showing up in search after it's sold
- Other buyers making offers on already-sold items

## How It Works

```
Offer Status: pending → accepted
    ↓
Trigger fires
    ↓
Identifies which listing to archive:
    • SEEK listings → archives the seek_listing_id
    • REGULAR listings → archives the offer_listing_id (or seek_listing_id)
    ↓
Sets listing:
    • archived = true
    • is_sold = true  
    • quantity_available = 0
```

## Deployment Steps

### Step 1: Go to Supabase SQL Editor
1. Open your Supabase dashboard
2. Go to **SQL Editor**
3. Click **New Query**

### Step 2: Run the Migration
1. Copy the contents of `archive_listing_on_offer_accept.sql`
2. Paste into SQL Editor
3. Click **Run**

### Step 3: Verify Installation
Run this query to verify the trigger was created:

```sql
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'archive_listing_after_offer_accept';
```

You should see 1 row returned with the trigger details.

## Testing

### Test Case 1: Accept an Offer on Regular Listing
```sql
-- 1. Find a test listing
SELECT id, title, archived, is_sold FROM listings WHERE archived = false LIMIT 1;

-- 2. Find or create an offer for it
SELECT id, status, seek_listing_id FROM offers WHERE status = 'pending' LIMIT 1;

-- 3. Accept the offer
UPDATE offers 
SET status = 'accepted', updated_at = NOW()
WHERE id = 'YOUR_OFFER_ID';

-- 4. Verify listing is archived
SELECT id, title, archived, is_sold, quantity_available 
FROM listings 
WHERE id = 'YOUR_LISTING_ID';
-- Should show: archived = true, is_sold = true, quantity_available = 0
```

### Test Case 2: Accept an Offer on Seek Listing
```sql
-- Similar test but with a seek listing
SELECT id, title, archived, intent FROM listings WHERE intent = 'seek' AND archived = false LIMIT 1;
```

## What Gets Archived?

| Offer Type | Listing Archived |
|------------|------------------|
| **Seek** | seek_listing_id (the request) |
| **Regular** | offer_listing_id (the product/service) |

## Works With Existing System

This trigger complements the existing auto-archive triggers:
- ✅ **This trigger**: Archives when offer accepted
- ✅ **Existing trigger**: Archives when purchase completed (quantity = 0)
- ✅ **Existing trigger**: Restores when order cancelled

## Rollback

If you need to remove this trigger:

```sql
DROP TRIGGER IF EXISTS archive_listing_after_offer_accept ON offers;
DROP FUNCTION IF EXISTS archive_listing_on_offer_accept();
```

## Expected Behavior After Deployment

### Before (Current)
1. Seller accepts offer
2. Order created with payment_status = "pending"
3. **Listing still visible** ❌
4. Other users can still see/try to buy it ❌
5. Buyer pays
6. Listing archived (existing trigger)

### After (With This Fix)
1. Seller accepts offer
2. **Listing immediately archived** ✅
3. Order created with payment_status = "pending"
4. **Listing hidden from marketplace** ✅
5. No one else can buy it ✅
6. Buyer pays
7. Order processes normally ✅

## Monitoring

Check the Supabase logs after deploying to see the trigger in action:

```
🎯 Offer accepted! Offer ID: xxx
   Listing type: regular, Status change: pending -> accepted
   Archiving REGULAR listing: xxx
📦 Current listing state:
   Title: iPhone 13
   Archived: false, Sold: false, Quantity: 1
✅ Listing xxx archived (offer accepted)
```

## Questions?

- Listings automatically restore if order is cancelled (existing trigger handles this)
- Works for both seek and regular offer flows
- Complements (doesn't replace) existing purchase archiving

