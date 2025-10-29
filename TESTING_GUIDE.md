# Backend Testing Guide (Without WhatsApp)

This guide will help you test all the backend functionality we've built so far, without needing WhatsApp integration or Edge Functions.

## Prerequisites

- ✅ Executed `schema.sql`
- ✅ Executed `triggers.sql`
- ✅ Created `ads-media` storage bucket
- ✅ Executed `storage.sql`
- ✅ Created storage policies via Dashboard

---

## Table of Contents

1. [Test Setup](#test-setup)
2. [Test Database Tables](#test-database-tables)
3. [Test Constraints](#test-constraints)
4. [Test RLS Policies](#test-rls-policies)
5. [Test Triggers](#test-triggers)
6. [Test Helper Functions](#test-helper-functions)
7. [Test Storage](#test-storage)
8. [Complete Workflow Tests](#complete-workflow-tests)

---

## Test Setup

### 1. Create Test Users (Dashboard)

1. Go to **Authentication** → **Users** → **Add user**
2. Create 3 test users:

| Email | Password | Role |
|-------|----------|------|
| `clinic1@test.com` | `Test123!` | Clinic Owner |
| `clinic2@test.com` | `Test123!` | Clinic Owner |
| `admin@test.com` | `Admin123!` | Super Admin |

3. Note down the UUIDs for each user (you'll need them)

### 2. Create Super Admin Record

Since super_admins table has INSERT policy = FALSE, we need to create it manually:

```sql
-- Replace 'admin-user-uuid' with the actual UUID from step 1
INSERT INTO super_admins (user_id, role)
VALUES ('admin-user-uuid', 'superadmin');
```

**Verify:**
```sql
SELECT * FROM super_admins;
-- Should show 1 record
```

---

## Test Database Tables

### Test 1: Create Clinics

```sql
-- As clinic1 user (replace with actual UUID)
INSERT INTO clinics (user_id, name, phone, address, token_daily_limit)
VALUES
  ('clinic1-user-uuid', 'City Hospital', '9876543210', '123 Main St', 50),
  ('clinic2-user-uuid', 'Care Clinic', '9876543211', '456 Park Ave', 100);

-- Verify
SELECT id, name, phone, is_active FROM clinics;
```

**Expected:** 2 clinics created

### Test 2: Create Doctors

```sql
-- Get clinic IDs first
SELECT id, name FROM clinics;

-- Insert doctors (replace clinic-uuid with actual IDs)
INSERT INTO doctors (clinic_id, name, specialization, token_initial)
VALUES
  ('clinic1-uuid', 'Dr. Smith', 'Cardiology', 'A'),
  ('clinic1-uuid', 'Dr. Jones', 'Pediatrics', 'B'),
  ('clinic2-uuid', 'Dr. Kumar', 'General Medicine', 'C');

-- Verify
SELECT d.name, d.specialization, d.token_initial, c.name as clinic_name
FROM doctors d
JOIN clinics c ON d.clinic_id = c.id;
```

**Expected:** 3 doctors created

### Test 3: Create Patients and Family Members

```sql
-- Get clinic IDs
SELECT id, name FROM clinics;

-- Create patients (replace clinic-uuid)
INSERT INTO patients (clinic_id, phone_number)
VALUES
  ('clinic1-uuid', '9123456780'),
  ('clinic1-uuid', '9123456781'),
  ('clinic2-uuid', '9123456782');

-- Get patient IDs
SELECT id, phone_number FROM patients;

-- Create family members (replace patient-uuid)
INSERT INTO patient_family_members (patient_id, name, age, gender)
VALUES
  ('patient1-uuid', 'Rahul Kumar', 35, 'Male'),
  ('patient1-uuid', 'Priya Kumar', 32, 'Female'),
  ('patient2-uuid', 'Amit Shah', 45, 'Male');

-- Verify
SELECT
  pfm.name,
  pfm.age,
  pfm.gender,
  p.phone_number
FROM patient_family_members pfm
JOIN patients p ON pfm.patient_id = p.id;
```

**Expected:** 3 patients, 3 family members

### Test 4: Create Tokens

```sql
-- Get necessary IDs
SELECT
  c.id as clinic_id,
  d.id as doctor_id,
  pfm.id as patient_family_member_id,
  c.name as clinic,
  d.name as doctor,
  pfm.name as patient
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
LIMIT 5;

-- Create tokens (replace with actual IDs)
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES
  ('clinic-uuid', 'doctor-uuid', 'patient-family-uuid', 'A1', CURRENT_DATE),
  ('clinic-uuid', 'doctor-uuid', 'patient-family-uuid', 'A2', CURRENT_DATE),
  ('clinic-uuid', 'doctor-uuid', 'patient-family-uuid', 'A3', CURRENT_DATE);

-- Verify
SELECT
  t.token_number,
  t.date,
  t.status,
  d.name as doctor,
  pfm.name as patient
FROM tokens t
JOIN doctors d ON t.doctor_id = d.id
JOIN patient_family_members pfm ON t.patient_family_member_id = pfm.id;
```

**Expected:** 3 tokens with status 'waiting'

---

## Test Constraints

### Test 1: Phone Number Validation (Should FAIL)

```sql
-- Try invalid phone number (should fail)
INSERT INTO patients (clinic_id, phone_number)
VALUES ('clinic-uuid', '1234567890');  -- Starts with 1, should start with 6-9

-- Expected: ERROR - violates check constraint "chk_phone_number_format"
```

### Test 2: Token Daily Limit Validation (Should FAIL)

```sql
-- Try to set limit outside range (should fail)
UPDATE clinics
SET token_daily_limit = 15000  -- Exceeds max of 10000
WHERE id = 'clinic-uuid';

-- Expected: ERROR - violates check constraint "chk_token_daily_limit"
```

### Test 3: Token Initial Uppercase (Should FAIL)

```sql
-- Try lowercase token initial (should fail)
INSERT INTO doctors (clinic_id, name, token_initial)
VALUES ('clinic-uuid', 'Dr. Test', 'abc');  -- Should be uppercase

-- Expected: ERROR - violates check constraint "chk_token_initial_upper"
```

### Test 4: Age Validation (Should FAIL)

```sql
-- Try invalid age (should fail)
INSERT INTO patient_family_members (patient_id, name, age, gender)
VALUES ('patient-uuid', 'Test', 200, 'Male');  -- Age > 150

-- Expected: ERROR - violates check constraint "chk_age"
```

**✅ All constraint tests should fail with appropriate error messages**

---

## Test RLS Policies

### Test 1: Clinic Owner Can Only See Their Data

```sql
-- First, get your test user IDs and clinic IDs
SELECT u.email, c.id as clinic_id, c.name
FROM auth.users u
JOIN clinics c ON c.user_id = u.id;

-- Now test: Authenticate as clinic1@test.com in your app/frontend
-- Or use SQL with set_config to simulate:
SELECT set_config('request.jwt.claim.sub', 'clinic1-user-uuid', false);

-- Query clinics (should only see clinic1's data)
SELECT * FROM clinics;
-- Expected: Only 1 row (clinic1)

-- Try to query all clinics as different user
SELECT set_config('request.jwt.claim.sub', 'clinic2-user-uuid', false);
SELECT * FROM clinics;
-- Expected: Only 1 row (clinic2)
```

### Test 2: Users Cannot See Other Clinic's Doctors

```sql
-- As clinic1 user
SELECT set_config('request.jwt.claim.sub', 'clinic1-user-uuid', false);

-- Query doctors
SELECT * FROM doctors;
-- Expected: Only doctors from clinic1
```

### Test 3: Super Admin Can See Everything

```sql
-- As super admin
SELECT set_config('request.jwt.claim.sub', 'admin-user-uuid', false);

-- Query all clinics
SELECT * FROM clinics;
-- Expected: All clinics (both clinic1 and clinic2)

-- Query all doctors
SELECT * FROM doctors;
-- Expected: All doctors from all clinics
```

### Test 4: Public Can View Tokens (For QR Tracking)

```sql
-- Without authentication (public)
SELECT set_config('request.jwt.claim.sub', '', false);

-- Query tokens (should work due to public SELECT policy)
SELECT token_number, date, status FROM tokens;
-- Expected: All tokens visible (for QR code tracking feature)
```

### Test 5: Cannot Insert to Other Clinic

```sql
-- As clinic1 user, try to add doctor to clinic2 (should fail)
SELECT set_config('request.jwt.claim.sub', 'clinic1-user-uuid', false);

INSERT INTO doctors (clinic_id, name, token_initial)
VALUES ('clinic2-uuid', 'Unauthorized Doctor', 'Z');

-- Expected: ERROR - new row violates row-level security policy
```

**✅ All RLS tests should enforce proper isolation**

---

## Test Triggers

### Test 1: Token Limit Enforcement

```sql
-- Set a clinic's daily limit to 3
UPDATE clinics
SET token_daily_limit = 3
WHERE id = 'clinic-uuid';

-- Insert 3 tokens for today (should work)
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES
  ('clinic-uuid', 'doctor-uuid', 'patient-uuid', 'TEST1', CURRENT_DATE),
  ('clinic-uuid', 'doctor-uuid', 'patient-uuid', 'TEST2', CURRENT_DATE),
  ('clinic-uuid', 'doctor-uuid', 'patient-uuid', 'TEST3', CURRENT_DATE);

-- Verify count
SELECT COUNT(*) FROM tokens WHERE clinic_id = 'clinic-uuid' AND date = CURRENT_DATE;
-- Expected: 3

-- Try to insert 4th token (should FAIL)
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES ('clinic-uuid', 'doctor-uuid', 'patient-uuid', 'TEST4', CURRENT_DATE);

-- Expected: ERROR - Daily token limit reached for this clinic
```

### Test 2: Auto-Completion Timestamp

```sql
-- Create a token
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES ('clinic-uuid', 'doctor-uuid', 'patient-uuid', 'AUTO1', CURRENT_DATE)
RETURNING id, completed_at;

-- Expected: completed_at is NULL

-- Update status to completed
UPDATE tokens
SET status = 'completed'
WHERE token_number = 'AUTO1' AND date = CURRENT_DATE
RETURNING id, completed_at;

-- Expected: completed_at is NOW() (automatically set by trigger)

-- Verify
SELECT token_number, status, created_at, completed_at
FROM tokens
WHERE token_number = 'AUTO1';
-- Expected: completed_at should be filled
```

### Test 3: Inactive Clinic Cannot Create Tokens

```sql
-- Set clinic to inactive
UPDATE clinics
SET is_active = false
WHERE id = 'clinic-uuid';

-- Try to create token (should FAIL)
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES ('clinic-uuid', 'doctor-uuid', 'patient-uuid', 'INACTIVE1', CURRENT_DATE);

-- Expected: ERROR - Clinic is not active

-- Reactivate
UPDATE clinics SET is_active = true WHERE id = 'clinic-uuid';
```

**✅ All triggers should enforce business logic correctly**

---

## Test Helper Functions

### Test 1: Get Next Token Number

```sql
-- Get next token number for a doctor on today
SELECT get_next_token_number(
  'clinic-uuid'::uuid,
  'doctor-uuid'::uuid,
  CURRENT_DATE
);

-- Expected: Something like 'A4' (depends on existing tokens)

-- Create token with this number
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES (
  'clinic-uuid',
  'doctor-uuid',
  'patient-uuid',
  get_next_token_number('clinic-uuid'::uuid, 'doctor-uuid'::uuid, CURRENT_DATE),
  CURRENT_DATE
);

-- Verify it auto-incremented
SELECT token_number FROM tokens
WHERE doctor_id = 'doctor-uuid' AND date = CURRENT_DATE
ORDER BY token_number;
```

### Test 2: Get Queue Position

```sql
-- Get a token ID
SELECT id, token_number FROM tokens
WHERE date = CURRENT_DATE AND status = 'waiting'
LIMIT 1;

-- Get its queue position
SELECT get_queue_position('token-uuid'::uuid);

-- Expected: A number indicating position in queue (e.g., 1, 2, 3)
```

### Test 3: Get Waiting Tokens Count

```sql
-- Count waiting tokens for a doctor today
SELECT get_waiting_tokens_count(
  'clinic-uuid'::uuid,
  'doctor-uuid'::uuid,
  CURRENT_DATE
);

-- Verify manually
SELECT COUNT(*) FROM tokens
WHERE clinic_id = 'clinic-uuid'
  AND doctor_id = 'doctor-uuid'
  AND date = CURRENT_DATE
  AND status = 'waiting';

-- Expected: Both queries should return same count
```

### Test 4: Get Current Token

```sql
-- Mark a token as "in consultation"
UPDATE tokens
SET status = 'in consultation'
WHERE token_number = 'A1' AND date = CURRENT_DATE;

-- Get current token for the doctor
SELECT * FROM get_current_token(
  'clinic-uuid'::uuid,
  'doctor-uuid'::uuid,
  CURRENT_DATE
);

-- Expected: Returns the token marked as "in consultation"
```

### Test 5: Get Clinic Statistics

```sql
-- Get statistics for last 7 days
SELECT * FROM get_clinic_statistics(
  'clinic-uuid'::uuid,
  CURRENT_DATE - INTERVAL '7 days',
  CURRENT_DATE
);

-- Expected: Returns total_tokens, completed_tokens, skipped_tokens, completion_rate, skip_rate
```

### Test 6: Get Doctor Statistics

```sql
-- Get doctor stats for last 30 days
SELECT * FROM get_doctor_statistics(
  'doctor-uuid'::uuid,
  CURRENT_DATE - INTERVAL '30 days',
  CURRENT_DATE
);

-- Expected: Returns total_tokens, completed_tokens, skipped_tokens, avg_consultation_time
```

### Test 7: Get Busiest Hours

```sql
-- Get busiest hours for a clinic
SELECT * FROM get_busiest_hours(
  'clinic-uuid'::uuid,
  CURRENT_DATE - INTERVAL '7 days',
  CURRENT_DATE
)
ORDER BY token_count DESC
LIMIT 5;

-- Expected: Returns hours with most token activity
```

**✅ All helper functions should return expected results**

---

## Test Storage

### Test 1: Upload File (Via Dashboard)

1. Go to **Storage** → **ads-media**
2. Create folder: `clinic_{your-clinic-id}`
3. Upload a test image (JPG/PNG, under 10MB)
4. Verify it appears in the bucket

### Test 2: Upload with Wrong Folder (Should FAIL)

1. Try to upload to `clinic_{different-clinic-id}` folder
2. Expected: Upload fails due to RLS policy

### Test 3: Get Public URL (Via SQL)

```sql
-- Get bucket info
SELECT * FROM storage.buckets WHERE name = 'ads-media';

-- Check files (if any uploaded)
SELECT * FROM storage.objects WHERE bucket_id = 'ads-media';
```

### Test 4: Create Ad Record

```sql
-- After uploading file to storage, create ad record
INSERT INTO ads (clinic_id, title, image_url, duration, is_active)
VALUES (
  'clinic-uuid',
  'Special Offer',
  'https://your-project.supabase.co/storage/v1/object/public/ads-media/clinic_xxx/ad_yyy.jpg',
  15,
  true
);

-- Verify
SELECT * FROM ads WHERE clinic_id = 'clinic-uuid';
```

**✅ Storage should enforce folder isolation**

---

## Complete Workflow Tests

### Workflow 1: New Patient Visit

```sql
-- Step 1: Check if patient exists
SELECT * FROM patients WHERE phone_number = '9123456789' AND clinic_id = 'clinic-uuid';

-- Step 2: If not exists, create patient
INSERT INTO patients (clinic_id, phone_number)
VALUES ('clinic-uuid', '9123456789')
RETURNING id;

-- Step 3: Add family member
INSERT INTO patient_family_members (patient_id, name, age, gender)
VALUES ('patient-uuid', 'John Doe', 30, 'Male')
RETURNING id;

-- Step 4: Generate token number
SELECT get_next_token_number('clinic-uuid'::uuid, 'doctor-uuid'::uuid, CURRENT_DATE);

-- Step 5: Create token
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date)
VALUES (
  'clinic-uuid',
  'doctor-uuid',
  'patient-family-uuid',
  'A5',  -- Use number from step 4
  CURRENT_DATE
)
RETURNING id, token_number, status;

-- Step 6: Verify token created
SELECT
  t.token_number,
  t.status,
  d.name as doctor,
  pfm.name as patient,
  t.created_at
FROM tokens t
JOIN doctors d ON t.doctor_id = d.id
JOIN patient_family_members pfm ON t.patient_family_member_id = pfm.id
WHERE t.token_number = 'A5';
```

### Workflow 2: Token Status Updates (Queue Management)

```sql
-- Scenario: Managing queue for Dr. Smith

-- Step 1: View waiting queue
SELECT
  token_number,
  pfm.name as patient,
  t.created_at,
  get_queue_position(t.id) as position
FROM tokens t
JOIN patient_family_members pfm ON t.patient_family_member_id = pfm.id
WHERE t.doctor_id = 'doctor-uuid'
  AND t.date = CURRENT_DATE
  AND t.status = 'waiting'
ORDER BY t.created_at;

-- Step 2: Call first patient (A1 → in consultation)
UPDATE tokens
SET status = 'in consultation'
WHERE token_number = 'A1'
  AND date = CURRENT_DATE
  AND doctor_id = 'doctor-uuid';

-- Step 3: Verify current token
SELECT * FROM get_current_token(
  'clinic-uuid'::uuid,
  'doctor-uuid'::uuid,
  CURRENT_DATE
);

-- Step 4: Complete consultation (in consultation → completed)
UPDATE tokens
SET status = 'completed'
WHERE token_number = 'A1'
  AND date = CURRENT_DATE
  AND doctor_id = 'doctor-uuid';

-- Step 5: Verify completed_at was auto-set
SELECT token_number, status, completed_at
FROM tokens
WHERE token_number = 'A1' AND date = CURRENT_DATE;

-- Step 6: Call next patient (A2 → in consultation)
UPDATE tokens
SET status = 'in consultation'
WHERE token_number = 'A2'
  AND date = CURRENT_DATE
  AND doctor_id = 'doctor-uuid';

-- Step 7: Mark patient as skipped (missed their turn)
UPDATE tokens
SET status = 'skipped'
WHERE token_number = 'A3'
  AND date = CURRENT_DATE
  AND doctor_id = 'doctor-uuid';
```

### Workflow 3: Daily Statistics Report

```sql
-- Get today's summary for a clinic
SELECT
  c.name as clinic,
  COUNT(t.id) as total_tokens,
  COUNT(t.id) FILTER (WHERE t.status = 'completed') as completed,
  COUNT(t.id) FILTER (WHERE t.status = 'waiting') as waiting,
  COUNT(t.id) FILTER (WHERE t.status = 'in consultation') as in_consultation,
  COUNT(t.id) FILTER (WHERE t.status = 'skipped') as skipped
FROM clinics c
LEFT JOIN tokens t ON c.id = t.clinic_id AND t.date = CURRENT_DATE
WHERE c.id = 'clinic-uuid'
GROUP BY c.id, c.name;

-- Get doctor-wise breakdown
SELECT
  d.name as doctor,
  d.token_initial,
  COUNT(t.id) as total_tokens,
  COUNT(t.id) FILTER (WHERE t.status = 'completed') as completed,
  COUNT(t.id) FILTER (WHERE t.status = 'waiting') as waiting
FROM doctors d
LEFT JOIN tokens t ON d.id = t.doctor_id AND t.date = CURRENT_DATE
WHERE d.clinic_id = 'clinic-uuid'
GROUP BY d.id, d.name, d.token_initial
ORDER BY total_tokens DESC;

-- Get hourly distribution
SELECT
  EXTRACT(HOUR FROM created_at) as hour,
  COUNT(*) as tokens_created
FROM tokens
WHERE clinic_id = 'clinic-uuid'
  AND date = CURRENT_DATE
GROUP BY EXTRACT(HOUR FROM created_at)
ORDER BY hour;
```

### Workflow 4: Multi-Clinic Comparison (Super Admin)

```sql
-- Set as super admin
SELECT set_config('request.jwt.claim.sub', 'admin-user-uuid', false);

-- Compare all clinics
SELECT
  c.name as clinic,
  c.token_daily_limit as daily_limit,
  COUNT(t.id) as tokens_today,
  c.is_active,
  c.whatsapp_confirmation,
  c.whatsapp_queue_alert
FROM clinics c
LEFT JOIN tokens t ON c.id = t.clinic_id AND t.date = CURRENT_DATE
GROUP BY c.id, c.name, c.token_daily_limit, c.is_active,
         c.whatsapp_confirmation, c.whatsapp_queue_alert
ORDER BY tokens_today DESC;

-- Top performing doctors across all clinics
SELECT
  d.name as doctor,
  c.name as clinic,
  COUNT(t.id) as total_tokens,
  ROUND(
    COUNT(*) FILTER (WHERE t.status = 'completed')::NUMERIC /
    NULLIF(COUNT(*), 0) * 100,
    2
  ) as completion_rate
FROM doctors d
JOIN clinics c ON d.clinic_id = c.id
LEFT JOIN tokens t ON d.id = t.doctor_id
  AND t.date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY d.id, d.name, c.name
HAVING COUNT(t.id) > 0
ORDER BY total_tokens DESC
LIMIT 10;
```

---

## Verification Checklist

After running all tests, verify:

- [ ] All tables created successfully
- [ ] Foreign key relationships working
- [ ] Check constraints enforcing rules
- [ ] RLS policies isolating data by clinic
- [ ] Super admin can access all data
- [ ] Public can view tokens (for QR tracking)
- [ ] Token limit trigger prevents excess tokens
- [ ] Auto-timestamp trigger sets completed_at
- [ ] Inactive clinics cannot create tokens
- [ ] Helper functions return correct results
- [ ] Storage bucket accepts valid files
- [ ] Storage policies enforce folder isolation
- [ ] Complete workflows execute successfully

---

## Testing with Frontend/API Client

If you want to test via JavaScript (recommended for realistic testing):

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://your-project.supabase.co',
  'your-anon-key'
)

// Test 1: Sign up and create clinic
async function testClinicSignup() {
  // Sign up
  const { data: authData, error: authError } = await supabase.auth.signUp({
    email: 'newclinic@test.com',
    password: 'Test123!'
  })

  if (authError) {
    console.error('Signup failed:', authError)
    return
  }

  // Create clinic (RLS will ensure user_id matches auth.uid())
  const { data: clinic, error: clinicError } = await supabase
    .from('clinics')
    .insert({
      user_id: authData.user.id,
      name: 'New Test Clinic',
      phone: '9876543299',
      address: '789 Test St'
    })
    .select()
    .single()

  console.log('Clinic created:', clinic)
}

// Test 2: Create token for patient
async function testTokenCreation(clinicId, doctorId, patientFamilyMemberId) {
  // Get next token number
  const { data: nextToken } = await supabase.rpc('get_next_token_number', {
    p_clinic_id: clinicId,
    p_doctor_id: doctorId,
    p_date: new Date().toISOString().split('T')[0]
  })

  // Create token
  const { data, error } = await supabase
    .from('tokens')
    .insert({
      clinic_id: clinicId,
      doctor_id: doctorId,
      patient_family_member_id: patientFamilyMemberId,
      token_number: nextToken,
      date: new Date().toISOString().split('T')[0]
    })
    .select()
    .single()

  console.log('Token created:', data)
}

// Test 3: Real-time subscription (queue updates)
function testRealtime(clinicId) {
  const channel = supabase
    .channel(`clinic:${clinicId}:tokens`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'tokens',
        filter: `clinic_id=eq.${clinicId}`
      },
      (payload) => {
        console.log('Token update:', payload)
      }
    )
    .subscribe()
}
```

---

## Common Issues & Solutions

### Issue 1: "relation does not exist"
**Solution:** Make sure you executed schema.sql first

### Issue 2: "must be owner of relation"
**Solution:** For storage policies, use Dashboard UI not SQL

### Issue 3: "violates row-level security"
**Solution:** You're trying to access/modify data from another clinic

### Issue 4: "Daily token limit reached"
**Solution:** Working as intended! Increase token_daily_limit or test with tomorrow's date

### Issue 5: "is_super_admin() does not exist"
**Solution:** Make sure you executed schema.sql after creating super_admins table

---

## Next Steps After Testing

Once all tests pass:

1. ✅ Backend is working correctly
2. ⏭️ Build Edge Functions for WhatsApp integration
3. ⏭️ Build frontend UI
4. ⏭️ Deploy to production

Happy testing! 🧪
