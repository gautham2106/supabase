-- =============================================
-- Quick Test Script (No User UUIDs Needed)
-- =============================================
-- This script tests the database schema without requiring
-- actual authentication. Execute in SQL Editor to verify
-- everything is set up correctly.
-- =============================================

-- Test 1: Check all tables exist
SELECT 'Test 1: Tables' as test_name;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('clinics', 'doctors', 'patients', 'patient_family_members',
                     'tokens', 'ads', 'super_admins', 'usage_logs')
ORDER BY table_name;

-- Test 2: Check RLS is enabled
SELECT 'Test 2: RLS Enabled' as test_name;
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Test 3: Check indexes exist
SELECT 'Test 3: Indexes' as test_name;
SELECT COUNT(*) as index_count,
       'Expected: 18+' as expected
FROM pg_indexes
WHERE schemaname = 'public';

-- Test 4: Check helper functions exist
SELECT 'Test 4: Helper Functions' as test_name;
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'is_super_admin',
    'get_next_token_number',
    'get_queue_position',
    'get_waiting_tokens_count',
    'get_current_token',
    'get_clinic_statistics',
    'get_doctor_statistics',
    'get_busiest_hours'
  )
ORDER BY routine_name;

-- Test 5: Check triggers exist
SELECT 'Test 5: Triggers' as test_name;
SELECT tgname as trigger_name, tgrelid::regclass as table_name
FROM pg_trigger
WHERE tgname IN ('trg_check_token_limit', 'trg_update_token_completed_at', 'trg_validate_ad_file')
ORDER BY tgname;

-- Test 6: Check storage bucket exists
SELECT 'Test 6: Storage Bucket' as test_name;
SELECT name, public
FROM storage.buckets
WHERE name = 'ads-media';

-- Test 7: Test constraint validations
SELECT 'Test 7: Constraints Working' as test_name;

-- Try invalid phone (should fail)
DO $$
BEGIN
    -- This will fail, which is what we want
    INSERT INTO patients (clinic_id, phone_number)
    VALUES (gen_random_uuid(), '1234567890');  -- Invalid: starts with 1
    RAISE NOTICE 'ERROR: Phone constraint not working!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS: Phone number constraint working';
END $$;

-- Try invalid age (should fail)
DO $$
BEGIN
    INSERT INTO patient_family_members (patient_id, name, age, gender)
    VALUES (gen_random_uuid(), 'Test', 200, 'Male');  -- Invalid: age > 150
    RAISE NOTICE 'ERROR: Age constraint not working!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS: Age constraint working';
END $$;

-- Try invalid token limit (should fail)
DO $$
BEGIN
    INSERT INTO clinics (user_id, name, phone, token_daily_limit)
    VALUES (gen_random_uuid(), 'Test', '9876543210', 15000);  -- Invalid: > 10000
    RAISE NOTICE 'ERROR: Token limit constraint not working!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS: Token limit constraint working';
END $$;

-- Test 8: Test helper function execution
SELECT 'Test 8: Helper Function Test' as test_name;

-- Test is_super_admin (should return false for anonymous)
SELECT is_super_admin() as is_super_admin_result,
       'Expected: false (no auth)' as expected;

-- Test 9: Summary
SELECT 'Test 9: Summary' as test_name;
SELECT
    (SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE') as tables_created,
    (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public') as indexes_created,
    (SELECT COUNT(*) FROM information_schema.routines
     WHERE routine_schema = 'public') as functions_created,
    (SELECT COUNT(*) FROM pg_trigger
     WHERE tgname LIKE 'trg_%') as triggers_created,
    (SELECT COUNT(*) FROM storage.buckets) as storage_buckets;

-- =============================================
-- All Tests Complete
-- =============================================
SELECT '✅ Quick tests completed!' as result;
SELECT 'If all tests passed, your schema is set up correctly.' as message;
SELECT 'Next: Create test users and run test-data.sql or follow TESTING_GUIDE.md' as next_step;
