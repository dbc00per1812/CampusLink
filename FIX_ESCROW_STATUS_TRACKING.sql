-- =====================================================
-- FIX ESCROW STATUS TRACKING
-- =====================================================
-- This ensures escrow_release_status in payments table
-- is properly updated at all times
-- =====================================================

-- Step 1: Backfill existing payment records
-- Set escrow_release_status based on current order status
UPDATE payments p
SET escrow_release_status = CASE
    WHEN EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.stripe_payment_intent_id = p.payment_intent_id 
        AND o.order_status = 'completed'
    ) THEN 'released'
    WHEN EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.stripe_payment_intent_id = p.payment_intent_id 
        AND o.order_status IN ('placed', 'seller_confirmed', 'in_progress')
    ) THEN 'held'
    ELSE p.escrow_release_status
END
WHERE p.payment_intent_id IS NOT NULL;

-- Step 2: Create function to update escrow status when order is completed
CREATE OR REPLACE FUNCTION update_escrow_status_on_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- When order is marked as completed, update payments table
    IF NEW.order_status = 'completed' AND OLD.order_status != 'completed' THEN
        UPDATE payments
        SET escrow_release_status = 'released',
            escrow_release_at = NOW()
        WHERE payment_intent_id = NEW.stripe_payment_intent_id
        AND escrow_release_status != 'released';
        
        RAISE LOG 'Escrow status updated to released for payment intent %', NEW.stripe_payment_intent_id;
    END IF;
    
    -- When order is refunded, update escrow status
    IF NEW.order_status = 'refunded' AND OLD.order_status != 'refunded' THEN
        UPDATE payments
        SET escrow_release_status = 'held'  -- Funds reverted
        WHERE payment_intent_id = NEW.stripe_payment_intent_id;
        
        RAISE LOG 'Escrow status updated to held (refunded) for payment intent %', NEW.stripe_payment_intent_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create trigger on orders table
DROP TRIGGER IF EXISTS trigger_update_escrow_status ON orders;
CREATE TRIGGER trigger_update_escrow_status
    AFTER UPDATE OF order_status
    ON orders
    FOR EACH ROW
    WHEN (NEW.stripe_payment_intent_id IS NOT NULL)
    EXECUTE FUNCTION update_escrow_status_on_completion();

-- Step 4: Create function to update escrow status when payment succeeds
CREATE OR REPLACE FUNCTION update_escrow_status_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    -- When payment succeeds, set escrow status to held
    IF NEW.status = 'succeeded' AND (OLD.status IS NULL OR OLD.status != 'succeeded') THEN
        NEW.escrow_release_status = 'held';
        RAISE LOG 'Escrow status set to held for payment intent %', NEW.payment_intent_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create trigger on payments table
DROP TRIGGER IF EXISTS trigger_update_escrow_on_payment ON payments;
CREATE TRIGGER trigger_update_escrow_on_payment
    BEFORE UPDATE OF status
    ON payments
    FOR EACH ROW
    WHEN (NEW.payment_intent_id IS NOT NULL)
    EXECUTE FUNCTION update_escrow_status_on_payment();

-- Step 6: Create view to easily check escrow status
CREATE OR REPLACE VIEW escrow_status_view AS
SELECT 
    o.id as order_id,
    o.stripe_payment_intent_id,
    o.stripe_escrow_account_id,
    o.order_status,
    o.payment_status,
    p.escrow_release_status,
    p.escrow_release_at,
    o.completed_at,
    CASE 
        WHEN o.order_status = 'completed' THEN 'Released'
        WHEN o.order_status IN ('placed', 'seller_confirmed', 'in_progress') 
            AND o.payment_status = 'succeeded' THEN 'Held in Escrow'
        ELSE 'Inactive'
    END as computed_status
FROM orders o
LEFT JOIN payments p ON p.payment_intent_id = o.stripe_payment_intent_id
WHERE o.stripe_payment_intent_id IS NOT NULL;

-- Step 7: Grant necessary permissions
GRANT SELECT ON escrow_status_view TO authenticated;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check escrow statuses
SELECT 
    order_status,
    payment_status,
    escrow_release_status,
    COUNT(*) as count
FROM escrow_status_view
GROUP BY order_status, payment_status, escrow_release_status
ORDER BY order_status, payment_status;

-- Check for any mismatches
SELECT *
FROM escrow_status_view
WHERE (
    (order_status = 'completed' AND escrow_release_status != 'released')
    OR (order_status IN ('placed', 'seller_confirmed', 'in_progress') 
        AND payment_status = 'succeeded' 
        AND escrow_release_status = 'released')
)
LIMIT 10;

RAISE NOTICE 'Escrow status tracking has been fixed and backfilled!';
RAISE NOTICE 'Triggers are now active to keep escrow_release_status in sync.';

