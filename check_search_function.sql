-- Check if search function exists
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public' 
AND routine_name IN ('search_listings', 'get_search_suggestions');

-- Check if tsv column exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'listings'
AND column_name = 'tsv';

-- Check if GIN index exists on tsv
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' 
AND tablename = 'listings'
AND indexname LIKE '%tsv%';
