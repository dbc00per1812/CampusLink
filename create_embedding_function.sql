-- Create Embedding Generation Functions
-- This creates functions to automatically generate embeddings for listings
-- using Supabase's built-in AI inference API
-- Run this in Supabase SQL Editor AFTER running enable_vector_search.sql

-- Function to generate embeddings for a single listing
CREATE OR REPLACE FUNCTION generate_listing_embedding(
    listing_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    listing_text TEXT;
    embedding_result vector(384);
BEGIN
    -- Combine title, description, and category for embedding
    -- This creates a rich text representation of the listing
    SELECT 
        COALESCE(title, '') || ' ' || 
        COALESCE(description, '') || ' ' || 
        COALESCE(category, '') || ' ' ||
        CASE 
            WHEN listing_type = 'product' THEN 'product'
            WHEN listing_type = 'service' THEN 'service'
            ELSE ''
        END
    INTO listing_text
    FROM listings
    WHERE id = listing_id;
    
    -- Check if we got any text
    IF listing_text IS NULL OR TRIM(listing_text) = '' THEN
        RAISE NOTICE 'No text found for listing %', listing_id;
        RETURN;
    END IF;
    
    -- Generate embedding using Supabase's built-in AI function
    -- Note: This requires Supabase AI to be enabled in your project
    -- Model: text-embedding-3-small (384 dimensions)
    BEGIN
        SELECT ai.openai_embed(
            'text-embedding-3-small',
            listing_text,
            api_key => current_setting('app.settings.openai_api_key', true)
        ) INTO embedding_result;
        
        -- Update listing with embedding
        UPDATE listings
        SET embedding = embedding_result
        WHERE id = listing_id;
        
        RAISE NOTICE 'Generated embedding for listing %', listing_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error generating embedding for listing %: %', listing_id, SQLERRM;
            -- Don't fail the transaction, just log the error
    END;
END;
$$;

-- Trigger function to auto-generate embeddings on insert/update
CREATE OR REPLACE FUNCTION auto_generate_embedding()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Schedule embedding generation asynchronously to avoid blocking the insert/update
    -- We use pg_notify to signal that an embedding needs to be generated
    -- This allows the trigger to complete quickly without waiting for AI API
    
    -- For now, we'll generate synchronously but this could be optimized
    -- to use background jobs in production
    PERFORM generate_listing_embedding(NEW.id);
    
    RETURN NEW;
END;
$$;

-- Create trigger for auto-generating embeddings
-- This trigger fires AFTER insert or update of relevant columns
DROP TRIGGER IF EXISTS trigger_generate_embedding ON listings;
CREATE TRIGGER trigger_generate_embedding
AFTER INSERT OR UPDATE OF title, description, category, listing_type ON listings
FOR EACH ROW
WHEN (NEW.status = 'active' AND NEW.archived = false)
EXECUTE FUNCTION auto_generate_embedding();

-- Helper function to regenerate all embeddings (use with caution)
CREATE OR REPLACE FUNCTION regenerate_all_embeddings(
    batch_size INTEGER DEFAULT 10
)
RETURNS TABLE (
    processed INTEGER,
    failed INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    listing_record RECORD;
    processed_count INTEGER := 0;
    failed_count INTEGER := 0;
BEGIN
    FOR listing_record IN 
        SELECT id 
        FROM listings 
        WHERE status = 'active' 
        AND archived = false 
        ORDER BY created_at DESC
        LIMIT batch_size
    LOOP
        BEGIN
            PERFORM generate_listing_embedding(listing_record.id);
            processed_count := processed_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                failed_count := failed_count + 1;
                RAISE NOTICE 'Failed to generate embedding for %: %', listing_record.id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT processed_count, failed_count;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION generate_listing_embedding(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION auto_generate_embedding() TO authenticated;
GRANT EXECUTE ON FUNCTION regenerate_all_embeddings(INTEGER) TO authenticated;

-- Verify the functions were created
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%embedding%'
ORDER BY routine_name;

-- Check if trigger was created
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trigger_generate_embedding';

-- Test the function with a single listing (if you have any)
-- Uncomment to test:
-- SELECT generate_listing_embedding(
--     (SELECT id FROM listings WHERE status = 'active' LIMIT 1)
-- );

