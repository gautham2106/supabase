# Storage Bucket Setup Guide

This guide will walk you through setting up the `ads-media` storage bucket for advertisement images and videos in your Hospital Token & Queue Management System.

## Overview

The `ads-media` bucket stores:
- Advertisement images (JPG, PNG, GIF, WebP)
- Advertisement videos (MP4, MOV, AVI, WebM)
- Maximum file size: 10MB per file
- Organized by clinic: `clinic_{clinic_id}/ad_{ad_id}.{extension}`

---

## Step 1: Create the Storage Bucket (Supabase Dashboard)

### 1.1 Navigate to Storage
1. Open your [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Click on **Storage** in the left sidebar
4. Click **New bucket** button

### 1.2 Configure Bucket Settings
Fill in the following details:

| Setting | Value | Description |
|---------|-------|-------------|
| **Name** | `ads-media` | Bucket identifier (must be exact) |
| **Public bucket** | ✅ **Enabled** | Allows public read access for TV displays |
| **File size limit** | `10 MB` | Maximum upload size |
| **Allowed MIME types** | Leave empty (we'll validate via trigger) | Or add: `image/jpeg, image/png, image/gif, image/webp, video/mp4, video/quicktime, video/x-msvideo` |

### 1.3 Create the Bucket
Click **Create bucket** to finalize.

---

## Step 2: Apply Storage Policies (SQL Editor)

### 2.1 Open SQL Editor
1. In your Supabase Dashboard, go to **SQL Editor**
2. Click **New query**

### 2.2 Execute Storage Policies
Copy the entire contents of `storage.sql` and execute it.

This will create:
- ✅ Public read access for anyone
- ✅ Clinic owners can upload to their folder only
- ✅ Clinic owners can update/delete their own files
- ✅ Super admins have full access
- ✅ File type validation (jpg, png, gif, webp, mp4, mov, avi, webm)
- ✅ File size validation (max 10MB)

---

## Step 3: Verify Setup

### 3.1 Check Bucket Exists
Run this query in SQL Editor:

```sql
SELECT * FROM storage.buckets WHERE name = 'ads-media';
```

**Expected output:**
```
id          | name       | public
------------|------------|--------
<uuid>      | ads-media  | true
```

### 3.2 Check Policies
Run this query:

```sql
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'objects'
  AND policyname LIKE '%ads%'
ORDER BY policyname;
```

**Expected output:** 5 policies
- `Clinic Owner: Delete ads media` (DELETE)
- `Clinic Owner: Update ads media` (UPDATE)
- `Clinic Owner: Upload ads media` (INSERT)
- `Public: View ads media` (SELECT)
- `Super Admin: Full access to ads media` (ALL)

### 3.3 Check Trigger
```sql
SELECT tgname, tgtype, tgenabled
FROM pg_trigger
WHERE tgname = 'trg_validate_ad_file';
```

**Expected output:**
```
tgname                 | tgtype | tgenabled
-----------------------|--------|----------
trg_validate_ad_file   | 7      | O
```

---

## Step 4: Test Upload (Optional)

### 4.1 Using Supabase Dashboard
1. Go to **Storage** → **ads-media**
2. Click **Upload file**
3. Create a folder structure: `clinic_{your-clinic-id}/`
4. Upload a test image (JPG/PNG, under 10MB)

### 4.2 Using JavaScript (Frontend)
```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

async function uploadAd(clinicId, adId, file) {
  // File path must follow: clinic_{clinicId}/ad_{adId}.{ext}
  const fileExt = file.name.split('.').pop()
  const filePath = `clinic_${clinicId}/ad_${adId}.${fileExt}`

  const { data, error } = await supabase.storage
    .from('ads-media')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false
    })

  if (error) {
    console.error('Upload failed:', error.message)
    return null
  }

  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('ads-media')
    .getPublicUrl(filePath)

  console.log('File uploaded:', publicUrl)
  return publicUrl
}
```

### 4.3 Using cURL
```bash
# Get your access token first (after login)
ACCESS_TOKEN="your-jwt-token"
SUPABASE_URL="your-project-url"
CLINIC_ID="your-clinic-uuid"
AD_ID="your-ad-uuid"

curl -X POST \
  "${SUPABASE_URL}/storage/v1/object/ads-media/clinic_${CLINIC_ID}/ad_${AD_ID}.jpg" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: image/jpeg" \
  --data-binary "@/path/to/image.jpg"
```

---

## Folder Structure

Organize files by clinic to enforce isolation:

```
ads-media/
├── clinic_<uuid-1>/
│   ├── ad_<uuid-a>.jpg
│   ├── ad_<uuid-b>.png
│   └── ad_<uuid-c>.mp4
├── clinic_<uuid-2>/
│   ├── ad_<uuid-d>.jpg
│   └── ad_<uuid-e>.webp
└── clinic_<uuid-3>/
    └── ad_<uuid-f>.gif
```

### Naming Convention
- **Format:** `clinic_{clinic_id}/ad_{ad_id}.{extension}`
- **Example:** `clinic_a1b2c3d4-e5f6-7890-abcd-ef1234567890/ad_f9e8d7c6-b5a4-3210-9876-543210fedcba.jpg`

---

## Security Features

### 1. Row Level Security
- ✅ Users can only upload to their own clinic folder
- ✅ Users can only delete/update their own files
- ✅ Everyone can view (public read for TV displays)
- ✅ Super admins bypass all restrictions

### 2. File Validation
- ✅ Only allowed file types (images: jpg, png, gif, webp | videos: mp4, mov, avi, webm)
- ✅ Maximum file size: 10MB
- ✅ Validated at database level (cannot be bypassed)

### 3. Folder Isolation
- ✅ Enforced by policy: `(storage.foldername(name))[1] = 'clinic_' || clinic_id`
- ✅ Users cannot access other clinics' folders

---

## Common Issues & Troubleshooting

### Issue 1: "Policy violation" on upload
**Cause:** Trying to upload outside your clinic folder
**Solution:** Ensure path starts with `clinic_{your_clinic_id}/`

### Issue 2: "File type not allowed"
**Cause:** Uploading unsupported file type
**Solution:** Use only: jpg, jpeg, png, gif, webp, mp4, mov, avi, webm

### Issue 3: "File size exceeds 10MB limit"
**Cause:** File too large
**Solution:** Compress/resize the file before uploading

### Issue 4: Cannot view uploaded file
**Cause:** Bucket not set to public
**Solution:** In Dashboard → Storage → ads-media → Settings → Enable "Public bucket"

### Issue 5: Policies not working
**Cause:** Policies not applied or RLS not enabled
**Solution:** Re-run `storage.sql` and verify with queries in Step 3.2

---

## API Reference

### Get Public URL
```javascript
const { data } = supabase.storage
  .from('ads-media')
  .getPublicUrl('clinic_xxx/ad_yyy.jpg')

console.log(data.publicUrl)
// https://<project-ref>.supabase.co/storage/v1/object/public/ads-media/clinic_xxx/ad_yyy.jpg
```

### List Files in Clinic Folder
```javascript
const { data, error } = await supabase.storage
  .from('ads-media')
  .list(`clinic_${clinicId}`, {
    limit: 100,
    offset: 0,
    sortBy: { column: 'name', order: 'asc' }
  })
```

### Delete File
```javascript
const { error } = await supabase.storage
  .from('ads-media')
  .remove([`clinic_${clinicId}/ad_${adId}.jpg`])
```

### Download File
```javascript
const { data, error } = await supabase.storage
  .from('ads-media')
  .download(`clinic_${clinicId}/ad_${adId}.jpg`)
```

---

## Integration with Ads Table

When creating an ad record, store the public URL:

```javascript
async function createAdWithUpload(clinicId, title, duration, file) {
  // 1. Upload file to storage
  const adId = crypto.randomUUID()
  const fileExt = file.name.split('.').pop()
  const filePath = `clinic_${clinicId}/ad_${adId}.${fileExt}`

  const { error: uploadError } = await supabase.storage
    .from('ads-media')
    .upload(filePath, file)

  if (uploadError) throw uploadError

  // 2. Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('ads-media')
    .getPublicUrl(filePath)

  // 3. Create ad record in database
  const { data, error } = await supabase
    .from('ads')
    .insert({
      id: adId,
      clinic_id: clinicId,
      title: title,
      image_url: publicUrl,
      duration: duration,
      is_active: true
    })
    .select()
    .single()

  return data
}
```

---

## Cost Considerations

### Storage Pricing (Supabase Free Tier)
- **Free allowance:** 1GB storage
- **Bandwidth:** 2GB/month egress
- **Overage:** $0.021/GB storage, $0.09/GB bandwidth

### Estimation
- Average image: 500KB
- Average video: 5MB
- 100 clinics × 5 ads each:
  - Images only: 500KB × 500 = 250MB
  - Mixed (3 images + 2 videos): 1.5MB + 10MB = 11.5MB × 100 = 1.15GB

**Recommendation:** Monitor usage in Dashboard → Settings → Usage

---

## Next Steps

After completing storage setup:

1. ✅ Update your frontend to use the storage API
2. ✅ Add image upload UI to ad management
3. ✅ Test upload/delete flows
4. ✅ Configure CDN caching (optional, for better performance)
5. ⏭️ Proceed to Edge Functions setup

---

## Support

If you encounter issues:
1. Check [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
2. Review policies with SQL queries in Step 3
3. Check browser console for detailed error messages
4. Verify authentication token is valid
