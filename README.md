# Hospital Token & Queue Management System - Database Schema

This repository contains the complete Supabase database schema for the Hospital Token & Queue Management System.

## Files

### Schema & Configuration
- `schema.sql` - Main database schema with tables, constraints, indexes, and RLS policies
- `triggers.sql` - Database triggers and helper functions
- `storage.sql` - Storage bucket policies and file validation
- `STORAGE_SETUP.md` - Complete storage setup guide with examples
- `feautures.md` - Complete architecture specification

### Testing
- `TESTING_GUIDE.md` - Comprehensive testing guide for all backend functionality
- `quick-test.sql` - Quick verification script (no authentication needed)
- `test-data.sql` - Sample data for testing (requires test users)

## Setup Instructions

### 1. Create a New Supabase Project

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Create a new project
3. Wait for the project to be fully initialized

### 2. Execute the Schema

**IMPORTANT:** Execute the SQL files in this exact order to avoid dependency errors:

#### Step 1: Execute Main Schema
1. Go to the SQL Editor in your Supabase dashboard
2. Copy the contents of `schema.sql`
3. Paste and run the entire script

This will create:
- All database tables with proper constraints
- Foreign key relationships
- Indexes for performance optimization
- RLS policies for security
- Helper functions

#### Step 2: Execute Triggers
1. In the SQL Editor, create a new query
2. Copy the contents of `triggers.sql`
3. Paste and run the entire script

This will create:
- Token limit validation trigger
- Automatic completed_at timestamp trigger
- Helper functions for token management and statistics

### 3. Configure Storage

To store advertisement images/videos for TV display:

1. Follow the complete guide in **[STORAGE_SETUP.md](STORAGE_SETUP.md)**
2. Create the `ads-media` bucket in Supabase Dashboard
3. Execute `storage.sql` to apply policies

**Quick summary:**
- Creates public bucket for ad media
- Enforces clinic-based folder isolation
- Validates file types (jpg, png, gif, webp, mp4, mov, avi, webm)
- Limits file size to 10MB
- Includes upload/delete examples

### 4. Verify the Setup

Run these queries to verify everything is set up correctly:

```sql
-- Check all tables are created
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Check RLS is enabled on all tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Check all indexes are created
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Check storage bucket exists
SELECT * FROM storage.buckets WHERE name = 'ads-media';
```

---

## Testing the Backend

### Quick Verification (2 minutes)

Execute `quick-test.sql` in SQL Editor to verify everything is set up:

```sql
-- Runs automated tests for:
-- ✅ All tables created
-- ✅ RLS enabled on all tables
-- ✅ Indexes created
-- ✅ Helper functions working
-- ✅ Triggers active
-- ✅ Constraints enforcing rules
-- ✅ Storage bucket configured
```

### Comprehensive Testing (30+ minutes)

See **[TESTING_GUIDE.md](TESTING_GUIDE.md)** for detailed testing including:

- Creating test users and clinics
- Testing RLS policies (data isolation)
- Testing all triggers and validations
- Testing helper functions
- Complete workflow testing (patient visit, queue management, statistics)
- Frontend/API testing examples

### Sample Test Data

1. Create 3 test users in Authentication dashboard:
   - `clinic1@test.com` / `Test123!`
   - `clinic2@test.com` / `Test123!`
   - `admin@test.com` / `Admin123!`

2. Edit `test-data.sql` and replace the UUIDs with your test user IDs

3. Execute `test-data.sql` to populate sample data:
   - 2 clinics
   - 4 doctors
   - 5 patients
   - 7 family members
   - 7 tokens (various statuses)
   - 2 ads

---

## Database Structure

### Core Tables

1. **clinics** - Clinic information and settings
2. **doctors** - Doctors associated with each clinic
3. **patients** - Patient records per clinic
4. **patient_family_members** - Family members of patients
5. **tokens** - Token/queue management
6. **ads** - Advertisement content for TV display
7. **super_admins** - Super admin users
8. **usage_logs** - Daily usage tracking for billing

### Key Features

#### Row Level Security (RLS)
- All tables have RLS enabled
- Clinic owners can only access their own data
- Super admins have full access
- Public access for specific features (token tracking, ads display)

#### Automatic Validations
- Token daily limit enforcement
- Phone number format validation (Indian format)
- Token status validation
- Date range validations

#### Performance Optimizations
- Strategic indexes on frequently queried columns
- Composite indexes for complex queries
- Optimized for real-time updates

## Helper Functions

### Token Management
- `get_next_token_number(clinic_id, doctor_id, date)` - Generate next token number
- `get_queue_position(token_id)` - Get position in waiting queue
- `get_waiting_tokens_count(clinic_id, doctor_id, date)` - Count waiting tokens
- `get_current_token(clinic_id, doctor_id, date)` - Get current token in consultation

### Statistics
- `get_clinic_statistics(clinic_id, start_date, end_date)` - Clinic performance metrics
- `get_doctor_statistics(doctor_id, start_date, end_date)` - Doctor performance metrics
- `get_busiest_hours(clinic_id, start_date, end_date)` - Peak hours analysis

### Authorization
- `is_super_admin()` - Check if current user is a super admin

## Usage Examples

### Creating a New Clinic
```sql
INSERT INTO clinics (user_id, name, phone, address)
VALUES (auth.uid(), 'City Hospital', '9876543210', '123 Main St');
```

### Adding a Doctor
```sql
INSERT INTO doctors (clinic_id, name, specialization, token_initial)
VALUES ('clinic-uuid', 'Dr. Smith', 'Cardiology', 'A');
```

### Generating a Token
```sql
INSERT INTO tokens (
  clinic_id,
  doctor_id,
  patient_family_member_id,
  token_number,
  date
) VALUES (
  'clinic-uuid',
  'doctor-uuid',
  'patient-family-member-uuid',
  get_next_token_number('clinic-uuid', 'doctor-uuid', CURRENT_DATE),
  CURRENT_DATE
);
```

### Getting Queue Statistics
```sql
SELECT * FROM get_clinic_statistics(
  'clinic-uuid',
  CURRENT_DATE - INTERVAL '7 days',
  CURRENT_DATE
);
```

## Security Notes

1. **Never use the service role key** in client-side code
2. **Always use the anon key** for frontend applications - RLS will protect the data
3. **Super admin records** can only be created manually through the SQL editor
4. **Usage logs** can only be created by backend/edge functions (INSERT policy is FALSE)

## Next Steps

After setting up the database:

1. **Set up Edge Functions** for:
   - WhatsApp notifications (token confirmation, queue alerts, review requests)
   - Daily usage logging (scheduled cron job)

2. **Configure Real-time Subscriptions** for:
   - Token queue updates
   - TV display updates

3. **Set up Authentication** using Supabase Auth with email/password

## Support

For issues or questions about the schema, refer to the `feautures.md` file for the complete architecture specification.
