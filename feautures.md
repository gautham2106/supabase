# Hospital Token & Queue Management - Supabase Architecture Specification

## 1. DATABASE TABLES

### clinics
- `id` UUID PRIMARY KEY
- `user_id` UUID FOREIGN KEY → auth.users(id) UNIQUE NOT NULL
- `name` TEXT NOT NULL
- `address` TEXT
- `phone` TEXT NOT NULL
- `review_link` TEXT
- `token_daily_limit` INTEGER NOT NULL DEFAULT 100
- `whatsapp_confirmation` BOOLEAN NOT NULL DEFAULT TRUE
- `whatsapp_queue_alert` BOOLEAN NOT NULL DEFAULT FALSE
- `whatsapp_review` BOOLEAN NOT NULL DEFAULT FALSE
- `is_active` BOOLEAN NOT NULL DEFAULT TRUE
- `created_at` TIMESTAMP NOT NULL DEFAULT NOW()

### doctors
- `id` UUID PRIMARY KEY
- `clinic_id` UUID FOREIGN KEY → clinics(id) NOT NULL
- `name` TEXT NOT NULL
- `specialization` TEXT
- `token_initial` TEXT NOT NULL
- `is_available` BOOLEAN NOT NULL DEFAULT TRUE

### patients
- `id` UUID PRIMARY KEY
- `clinic_id` UUID FOREIGN KEY → clinics(id) NOT NULL
- `phone_number` TEXT NOT NULL
- `created_at` TIMESTAMP NOT NULL DEFAULT NOW()

### patient_family_members
- `id` UUID PRIMARY KEY
- `patient_id` UUID FOREIGN KEY → patients(id) NOT NULL
- `name` TEXT NOT NULL
- `age` INTEGER NOT NULL
- `gender` TEXT NOT NULL

### tokens
- `id` UUID PRIMARY KEY
- `clinic_id` UUID FOREIGN KEY → clinics(id) NOT NULL
- `doctor_id` UUID FOREIGN KEY → doctors(id)
- `patient_family_member_id` UUID FOREIGN KEY → patient_family_members(id)
- `token_number` TEXT NOT NULL
- `date` DATE NOT NULL
- `status` TEXT NOT NULL DEFAULT 'waiting'
- `reminder_sent` BOOLEAN NOT NULL DEFAULT FALSE
- `created_at` TIMESTAMP NOT NULL DEFAULT NOW()
- `completed_at` TIMESTAMP

### ads
- `id` UUID PRIMARY KEY
- `clinic_id` UUID FOREIGN KEY → clinics(id) NOT NULL
- `title` TEXT NOT NULL
- `image_url` TEXT NOT NULL
- `duration` INTEGER NOT NULL DEFAULT 10
- `is_active` BOOLEAN NOT NULL DEFAULT TRUE

### super_admins
- `id` UUID PRIMARY KEY
- `user_id` UUID FOREIGN KEY → auth.users(id) UNIQUE NOT NULL
- `role` TEXT NOT NULL DEFAULT 'admin'
- `created_at` TIMESTAMP NOT NULL DEFAULT NOW()

### usage_logs
- `id` UUID PRIMARY KEY
- `clinic_id` UUID FOREIGN KEY → clinics(id) NOT NULL
- `date` DATE NOT NULL
- `tokens_generated` INTEGER NOT NULL DEFAULT 0
- `whatsapp_sent` INTEGER NOT NULL DEFAULT 0
- `created_at` TIMESTAMP NOT NULL DEFAULT NOW()

---

## 2. RELATIONSHIPS

```
auth.users (1) → (1) clinics [ON DELETE CASCADE]
clinics (1) → (many) doctors [ON DELETE CASCADE]
clinics (1) → (many) patients [ON DELETE CASCADE]
clinics (1) → (many) tokens [ON DELETE CASCADE]
clinics (1) → (many) ads [ON DELETE CASCADE]
clinics (1) → (many) usage_logs [ON DELETE CASCADE]

patients (1) → (many) patient_family_members [ON DELETE CASCADE]
patient_family_members (1) → (many) tokens [ON DELETE SET NULL]

doctors (1) → (many) tokens [ON DELETE SET NULL]

auth.users (1) → (1) super_admins [ON DELETE CASCADE]
```

---

## 3. INDEXES

### clinics
- `idx_clinics_user_id` ON (user_id)
- `idx_clinics_is_active` ON (is_active)

### doctors
- `idx_doctors_clinic_id` ON (clinic_id)
- `idx_doctors_clinic_available` ON (clinic_id, is_available)

### patients
- `idx_patients_clinic_phone` UNIQUE ON (clinic_id, phone_number)
- `idx_patients_clinic_id` ON (clinic_id)

### patient_family_members
- `idx_family_patient_id` ON (patient_id)

### tokens
- `idx_tokens_clinic_date_doctor` ON (clinic_id, date, doctor_id)
- `idx_tokens_clinic_date_status` ON (clinic_id, date, status)
- `idx_tokens_date_status` ON (date, status)
- `idx_tokens_family_member` ON (patient_family_member_id)
- `idx_tokens_created_at` ON (created_at)

### ads
- `idx_ads_clinic_active` ON (clinic_id, is_active)

### super_admins
- `idx_super_admins_user_id` UNIQUE ON (user_id)

### usage_logs
- `idx_usage_clinic_date` UNIQUE ON (clinic_id, date)
- `idx_usage_date` ON (date)

---

## 4. CONSTRAINTS

### clinics
- UNIQUE: user_id
- CHECK: token_daily_limit > 0 AND token_daily_limit <= 10000

### doctors
- UNIQUE: (clinic_id, token_initial)
- CHECK: LENGTH(token_initial) BETWEEN 1 AND 5
- CHECK: token_initial = UPPER(token_initial)

### patients
- UNIQUE: (clinic_id, phone_number)
- CHECK: LENGTH(phone_number) = 10
- CHECK: phone_number ~ '^[6-9][0-9]{9}$'

### patient_family_members
- CHECK: age > 0 AND age <= 150
- CHECK: gender IN ('Male', 'Female', 'Other')

### tokens
- UNIQUE: (clinic_id, doctor_id, token_number, date)
- CHECK: status IN ('waiting', 'in consultation', 'skipped', 'completed')
- CHECK: completed_at >= created_at (when not null)
- CHECK: date >= '2024-01-01'

### ads
- CHECK: duration > 0 AND duration <= 60

### super_admins
- UNIQUE: user_id
- CHECK: role IN ('admin', 'superadmin', 'support')

### usage_logs
- UNIQUE: (clinic_id, date)
- CHECK: tokens_generated >= 0
- CHECK: whatsapp_sent >= 0

---

## 5. RLS POLICIES

### Helper Function
```sql
CREATE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM super_admins WHERE user_id = auth.uid()
  )
$$ LANGUAGE SQL SECURITY DEFINER;
```

### clinics
- **SELECT**: `user_id = auth.uid() OR is_super_admin()`
- **INSERT**: `auth.uid() IS NOT NULL AND user_id = auth.uid()`
- **UPDATE**: `user_id = auth.uid() OR is_super_admin()`
- **DELETE**: `is_super_admin()`

### doctors
- **SELECT**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **INSERT**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **UPDATE**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **DELETE**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`

### patients
- **SELECT**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **INSERT**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **UPDATE**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **DELETE**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`

### patient_family_members
- **SELECT**: `patient_id IN (SELECT id FROM patients WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())) OR is_super_admin()`
- **INSERT**: `patient_id IN (SELECT id FROM patients WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())) OR is_super_admin()`
- **UPDATE**: `patient_id IN (SELECT id FROM patients WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())) OR is_super_admin()`
- **DELETE**: `patient_id IN (SELECT id FROM patients WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())) OR is_super_admin()`

### tokens
- **SELECT (Clinic)**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **SELECT (Public)**: `TRUE` (for QR tracking)
- **INSERT**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid() AND is_active = true) OR is_super_admin()`
- **UPDATE**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **DELETE**: `is_super_admin()`

### ads
- **SELECT**: `TRUE` (public for TV display)
- **INSERT**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **UPDATE**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **DELETE**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`

### super_admins
- **SELECT**: `user_id = auth.uid()`
- **INSERT**: `FALSE` (manual only)
- **UPDATE**: `FALSE` (manual only)
- **DELETE**: `FALSE` (manual only)

### usage_logs
- **SELECT**: `clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid()) OR is_super_admin()`
- **INSERT**: `FALSE` (Edge Functions only)
- **UPDATE**: `FALSE`
- **DELETE**: `is_super_admin()`

---

## 6. EDGE FUNCTIONS

### 1. check-token-limit
- **Trigger**: BEFORE INSERT on tokens
- **Condition**: Always
- **Logic**:
  1. Check clinic.is_active = TRUE, else ABORT
  2. Count today's tokens for clinic
  3. If count >= clinic.token_daily_limit, ABORT
  4. Allow INSERT

### 2. send-whatsapp-token
- **Trigger**: AFTER INSERT on tokens
- **Condition**: clinic.whatsapp_confirmation = TRUE
- **Logic**:
  1. Check if whatsapp_confirmation enabled
  2. Fetch token, doctor, patient details
  3. Generate QR URL: `https://app.com/track/{token.id}`
  4. Send WhatsApp: "Your token: {number} for Dr. {name}. Track: {url}"

### 3. send-queue-alerts
- **Trigger**: AFTER UPDATE on tokens
- **Condition**: status changes TO 'in consultation' AND clinic.whatsapp_queue_alert = TRUE
- **Logic**:
  1. Check if whatsapp_queue_alert enabled
  2. Find 4th waiting token: `SELECT * FROM tokens WHERE status='waiting' ORDER BY token_number LIMIT 1 OFFSET 3`
  3. If no 4th token, exit
  4. Fetch patient phone for 4th token
  5. Send WhatsApp: "You are 5th in line for Dr. {name}. Current: {current_token}"
  6. UPDATE tokens SET reminder_sent = TRUE for 4th token

### 4. send-review-request
- **Trigger**: AFTER UPDATE on tokens + 2 minute delay
- **Condition**: status changes TO 'completed' AND clinic.whatsapp_review = TRUE AND clinic.review_link IS NOT NULL
- **Logic**:
  1. Check conditions
  2. Wait 2 minutes
  3. Verify token still completed
  4. Send WhatsApp: "Thank you for visiting! Review us: {review_link}"

### 5. log-daily-usage
- **Trigger**: Cron (daily at 23:59)
- **Condition**: clinic.is_active = TRUE
- **Logic**:
  1. For each active clinic:
  2. Count today's tokens
  3. Calculate WhatsApp sent based on enabled features
  4. INSERT into usage_logs

---

## 7. REAL-TIME CHANNELS

### Channel: `clinic:{clinic_id}:tokens:{date}`
- **Table**: tokens
- **Events**: INSERT, UPDATE, DELETE
- **Filter**: `clinic_id = X AND date = Y`
- **Subscribers**:
  - Reception dashboard (queue management)
  - TV display (current token updates)
  - Patient mobile view (QR tracking)

### Setup
```javascript
supabase
  .channel(`clinic:${clinicId}:tokens:${date}`)
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'tokens',
    filter: `clinic_id=eq.${clinicId},date=eq.${date}`
  }, (payload) => {
    // Handle real-time updates
  })
  .subscribe()
```

---

## 8. STORAGE BUCKETS

### Bucket: ads-media
- **Type**: Public
- **Purpose**: Store ad images/videos for TV display
- **Structure**: `/clinic_{clinic_id}/ad_{ad_id}.{ext}`

### Policies
- **SELECT (Public)**: `TRUE` (anyone can view)
- **INSERT**: `bucket_id = 'ads-media' AND (storage.foldername(name))[1] = 'clinic_' || (SELECT id::text FROM clinics WHERE user_id = auth.uid())`
- **UPDATE**: `bucket_id = 'ads-media' AND (storage.foldername(name))[1] = 'clinic_' || (SELECT id::text FROM clinics WHERE user_id = auth.uid())`
- **DELETE**: `bucket_id = 'ads-media' AND (storage.foldername(name))[1] = 'clinic_' || (SELECT id::text FROM clinics WHERE user_id = auth.uid())`

### Allowed File Types
- Images: .jpg, .jpeg, .png, .gif, .webp
- Videos: .mp4, .mov, .avi

### Size Limits
- Max file size: 10MB

---

## 9. ANALYTICS QUERIES

### Tokens per Doctor
```sql
-- Daily
SELECT COUNT(*) FROM tokens 
WHERE doctor_id = ? AND date = CURRENT_DATE;

-- Monthly
SELECT COUNT(*) FROM tokens 
WHERE doctor_id = ? AND date >= DATE_TRUNC('month', CURRENT_DATE);

-- Custom Range
SELECT COUNT(*) FROM tokens 
WHERE doctor_id = ? AND date BETWEEN ? AND ?;

-- All Doctors
SELECT doctor_id, COUNT(*) FROM tokens 
WHERE clinic_id = ? AND date BETWEEN ? AND ?
GROUP BY doctor_id;
```

### Completion Rate
```sql
SELECT 
  (COUNT(*) FILTER (WHERE status = 'completed')::FLOAT / COUNT(*)) * 100 AS completion_rate
FROM tokens
WHERE clinic_id = ? AND date BETWEEN ? AND ?;
```

### Skip Rate
```sql
SELECT 
  (COUNT(*) FILTER (WHERE status = 'skipped')::FLOAT / COUNT(*)) * 100 AS skip_rate
FROM tokens
WHERE clinic_id = ? AND date BETWEEN ? AND ?;
```

### Busiest Time Slots
```sql
SELECT 
  EXTRACT(HOUR FROM created_at) AS hour,
  COUNT(*) AS token_count
FROM tokens
WHERE clinic_id = ? AND date BETWEEN ? AND ?
GROUP BY hour
ORDER BY token_count DESC;
```

---

## 10. AUTHENTICATION

### Clinic Signup
- Method: Email + Password (Supabase Auth)
- On signup: CREATE clinic record with user_id

### Super Admin
- Separate login: Check super_admins table
- Full platform access

### Password Reset
- Method: Supabase Magic Link

---

## 11. SECURITY

### API Keys
- **Anon Key**: Frontend (public access, RLS enforced)
- **Service Key**: Edge Functions only (bypasses RLS)

### Rate Limiting
- Token generation: Max token_daily_limit per clinic
- Enforced by check-token-limit Edge Function

---

## 12. COST OPTIMIZATION

### WhatsApp Messages per Token
- Confirmation: 1 message (₹0.13)
- Queue Alert: 1 message to 4th person only (₹0.13)
- Review: 1 message (₹0.13)
- **Total**: ₹0.13 - ₹0.39 per token (based on enabled features)

### Usage Tracking
- Daily automatic logging via Edge Function
- Monthly export for billing
- Manual payment collection

---

**END OF SPECIFICATION**
