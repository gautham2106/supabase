-- =============================================
-- Hospital Token & Queue Management System
-- Storage Bucket Configuration
-- =============================================

-- IMPORTANT: Execute schema.sql BEFORE running this file
-- This file depends on the is_super_admin() function and clinics table from schema.sql

-- NOTE: Storage policies CANNOT be created directly via SQL Editor due to permission restrictions.
-- You must create these policies through the Supabase Dashboard UI.
-- This file serves as a reference for what policies to create.
-- See STORAGE_SETUP.md for detailed dashboard instructions.

-- =============================================
-- FILE VALIDATION FUNCTION (Can be executed via SQL)
-- =============================================

-- Helper function to validate file type and size
CREATE OR REPLACE FUNCTION validate_ad_file_type()
RETURNS TRIGGER AS $$
DECLARE
    file_extension TEXT;
    allowed_extensions TEXT[] := ARRAY[
        'jpg', 'jpeg', 'png', 'gif', 'webp',  -- Images
        'mp4', 'mov', 'avi', 'webm'            -- Videos
    ];
BEGIN
    -- Extract file extension
    file_extension := LOWER(SPLIT_PART(NEW.name, '.', -1));

    -- Check if extension is allowed
    IF NOT (file_extension = ANY(allowed_extensions)) THEN
        RAISE EXCEPTION 'File type not allowed. Allowed types: jpg, jpeg, png, gif, webp, mp4, mov, avi, webm';
    END IF;

    -- Check file size (10MB = 10485760 bytes)
    IF NEW.metadata->>'size' IS NOT NULL AND
       (NEW.metadata->>'size')::BIGINT > 10485760 THEN
        RAISE EXCEPTION 'File size exceeds 10MB limit';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for file validation
DROP TRIGGER IF EXISTS trg_validate_ad_file ON storage.objects;
CREATE TRIGGER trg_validate_ad_file
    BEFORE INSERT ON storage.objects
    FOR EACH ROW
    WHEN (NEW.bucket_id = 'ads-media')
    EXECUTE FUNCTION validate_ad_file_type();

COMMENT ON FUNCTION validate_ad_file_type() IS
    'Validates file type and size for ads-media bucket uploads';

-- =============================================
-- STORAGE POLICIES REFERENCE
-- =============================================
-- These policies MUST be created through the Supabase Dashboard.
-- Go to: Storage → ads-media bucket → Policies tab → New Policy
-- =============================================

/*
===========================================
POLICY 1: Public Read Access
===========================================
Name: Public: View ads media
Operation: SELECT
Policy Definition (SQL):
-------------------------------------------
bucket_id = 'ads-media'
-------------------------------------------


===========================================
POLICY 2: Clinic Owner Upload
===========================================
Name: Clinic Owner: Upload ads media
Operation: INSERT
Policy Definition (SQL):
-------------------------------------------
bucket_id = 'ads-media'
AND auth.uid() IS NOT NULL
AND (storage.foldername(name))[1] = 'clinic_' || (
    SELECT id::text FROM clinics WHERE user_id = auth.uid()
)
-------------------------------------------


===========================================
POLICY 3: Clinic Owner Update
===========================================
Name: Clinic Owner: Update ads media
Operation: UPDATE
Policy Definition (SQL):
-------------------------------------------
bucket_id = 'ads-media'
AND auth.uid() IS NOT NULL
AND (storage.foldername(name))[1] = 'clinic_' || (
    SELECT id::text FROM clinics WHERE user_id = auth.uid()
)
-------------------------------------------


===========================================
POLICY 4: Clinic Owner Delete
===========================================
Name: Clinic Owner: Delete ads media
Operation: DELETE
Policy Definition (SQL):
-------------------------------------------
bucket_id = 'ads-media'
AND auth.uid() IS NOT NULL
AND (storage.foldername(name))[1] = 'clinic_' || (
    SELECT id::text FROM clinics WHERE user_id = auth.uid()
)
-------------------------------------------


===========================================
POLICY 5: Super Admin Full Access
===========================================
Name: Super Admin: Full access to ads media
Operation: ALL
Policy Definition (SQL):
-------------------------------------------
bucket_id = 'ads-media'
AND is_super_admin()
-------------------------------------------

*/

-- =============================================
-- INSTRUCTIONS
-- =============================================
-- 1. Execute this file in SQL Editor to create the validation function and trigger
-- 2. Go to Supabase Dashboard → Storage → ads-media → Policies
-- 3. Create each policy above using the "New Policy" button
-- 4. Copy the Policy Definition SQL into the policy editor
-- 5. See STORAGE_SETUP.md for detailed step-by-step instructions with screenshots
-- =============================================

