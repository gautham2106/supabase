-- =============================================
-- Hospital Token & Queue Management System
-- Storage Bucket Configuration
-- =============================================

-- IMPORTANT: Execute schema.sql BEFORE running this file
-- This file depends on the is_super_admin() function and clinics table from schema.sql

-- Note: The actual bucket 'ads-media' must be created manually in Supabase Dashboard
-- This file contains the policies to be applied after bucket creation

-- =============================================
-- STORAGE POLICIES FOR 'ads-media' BUCKET
-- =============================================

-- Policy 1: Public Read Access
-- Allows anyone to view/download ads for TV display
CREATE POLICY "Public: View ads media"
ON storage.objects FOR SELECT
USING (bucket_id = 'ads-media');

-- Policy 2: Clinic Owner Upload
-- Allows clinic owners to upload files to their own clinic folder
CREATE POLICY "Clinic Owner: Upload ads media"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'ads-media'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = 'clinic_' || (
        SELECT id::text FROM clinics WHERE user_id = auth.uid()
    )
);

-- Policy 3: Clinic Owner Update
-- Allows clinic owners to update files in their own clinic folder
CREATE POLICY "Clinic Owner: Update ads media"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'ads-media'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = 'clinic_' || (
        SELECT id::text FROM clinics WHERE user_id = auth.uid()
    )
);

-- Policy 4: Clinic Owner Delete
-- Allows clinic owners to delete files from their own clinic folder
CREATE POLICY "Clinic Owner: Delete ads media"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'ads-media'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = 'clinic_' || (
        SELECT id::text FROM clinics WHERE user_id = auth.uid()
    )
);

-- Policy 5: Super Admin Full Access
-- Allows super admins to manage all files
CREATE POLICY "Super Admin: Full access to ads media"
ON storage.objects FOR ALL
USING (
    bucket_id = 'ads-media'
    AND is_super_admin()
)
WITH CHECK (
    bucket_id = 'ads-media'
    AND is_super_admin()
);

-- =============================================
-- HELPER FUNCTION: Validate File Type
-- =============================================

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

-- =============================================
-- TRIGGER: Validate uploads
-- =============================================

DROP TRIGGER IF EXISTS trg_validate_ad_file ON storage.objects;
CREATE TRIGGER trg_validate_ad_file
    BEFORE INSERT ON storage.objects
    FOR EACH ROW
    WHEN (NEW.bucket_id = 'ads-media')
    EXECUTE FUNCTION validate_ad_file_type();

-- =============================================
-- COMMENTS
-- =============================================

COMMENT ON POLICY "Public: View ads media" ON storage.objects IS
    'Allows public read access to ads for TV display';

COMMENT ON POLICY "Clinic Owner: Upload ads media" ON storage.objects IS
    'Allows clinic owners to upload ads to their clinic folder';

COMMENT ON POLICY "Clinic Owner: Update ads media" ON storage.objects IS
    'Allows clinic owners to update ads in their clinic folder';

COMMENT ON POLICY "Clinic Owner: Delete ads media" ON storage.objects IS
    'Allows clinic owners to delete ads from their clinic folder';

COMMENT ON POLICY "Super Admin: Full access to ads media" ON storage.objects IS
    'Allows super admins full access to all ads';

COMMENT ON FUNCTION validate_ad_file_type() IS
    'Validates file type and size for ads-media bucket uploads';
