# Deploy Auto-Archive System

This guide explains how to deploy the automatic post archiving system that manages listing quantities and archives posts when they sell out.

## What This Does

- **Automatically decrements quantity** when an order is placed
- **Automatically archives listings** when quantity reaches 0
- **Restores quantity** and unarchives if an order is cancelled
- **Filters archived listings** from public views in the app

## Deployment Steps

### 1. Deploy Database Triggers (Required)

1. Navigate to your Supabase project dashboard
2. Go to the **SQL Editor** section
3. Open the file `/Users/eileenmurphy/CampusLink/auto_archive_listings.sql`
4. Copy the entire contents
5. Paste into the Supabase SQL Editor
6. Click **Run** to execute the script

### 2. Verify Triggers Were Created

The script includes a verification query at the end. After running, you should see output showing two triggers:
- `update_listing_quantity_after_order` - on INSERT
- `restore_listing_quantity_on_order_cancel` - on UPDATE

### 3. App Changes (Already Complete)

The Swift app has already been updated to filter out archived listings from public views. No additional app deployment needed.

## How It Works

### When a Purchase Happens
1. Order is created with `payment_status = 'succeeded'`
2. Trigger `update_listing_quantity_on_order` fires
3. Listing's `quantity_available` decreases by order quantity
4. Listing's `quantity_sold` increases by order quantity
5. If `quantity_available` reaches 0, `archived = true`

### When an Order is Cancelled
1. Order status changes to 'cancelled'
2. Trigger `restore_listing_quantity_on_cancel` fires
3. Listing's `quantity_available` increases by order quantity
4. Listing's `quantity_sold` decreases by order quantity
5. If quantity > 0, `archived = false`

## Testing

After deployment, test the system:

1. **Create a test listing** with `quantity_available = 3`
2. **Make a purchase** for 1 unit
   - ✅ Verify quantity decreases to 2
   - ✅ Verify listing is still visible
3. **Make another purchase** for 2 units
   - ✅ Verify quantity decreases to 0
   - ✅ Verify `archived = true`
   - ✅ Verify listing no longer appears in homepage/search
4. **Cancel one order**
   - ✅ Verify quantity increases
   - ✅ Verify `archived = false`
   - ✅ Verify listing reappears

## Views Affected

### Public Views (Archived Listings Hidden)
- ✅ Homepage feed
- ✅ Search results
- ✅ Category browser
- ✅ User profiles
- ✅ Seller dashboard counts

### Management Views (Archived Listings Visible)
- ✅ Seller's "My Listings" dashboard
  - Sellers can see what sold out

## Database Fields Used

### Listings Table
- `quantity_available` - Current stock remaining (integer, default 1)
- `quantity_sold` - Total units sold (integer, default 0)
- `archived` - Whether listing is archived (boolean, default false)

### Orders Table
- `quantity` - Number of units purchased (integer, default 1)
- `payment_status` - Must be 'succeeded' for trigger to fire
- `order_status` - Must be 'placed' or 'confirmed' for decrement

## Rollback

If you need to remove the triggers:

```sql
-- Remove triggers
DROP TRIGGER IF EXISTS update_listing_quantity_after_order ON orders;
DROP TRIGGER IF EXISTS restore_listing_quantity_on_order_cancel ON orders;

-- Remove functions
DROP FUNCTION IF EXISTS update_listing_quantity_on_order();
DROP FUNCTION IF EXISTS restore_listing_quantity_on_cancel();
```

## Support

If listings aren't archiving properly:

1. Check that orders have `payment_status = 'succeeded'`
2. Check that orders have `order_status` IN ('placed', 'confirmed')
3. Verify triggers exist in database
4. Check Supabase logs for trigger errors

## Notes

- Triggers only fire on new orders after deployment
- Existing listings with quantity = 0 won't be automatically archived (manual update needed if desired)
- App filters are already in place, no app rebuild required for filtering to work
- Sellers can always see their archived listings in their dashboard

