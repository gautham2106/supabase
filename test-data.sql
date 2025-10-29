-- =============================================
-- Sample Test Data for Hospital Management System
-- =============================================
-- Execute this file AFTER:
-- 1. Creating test users in Authentication dashboard
-- 2. Executing schema.sql and triggers.sql
-- =============================================

-- STEP 1: Replace these UUIDs with your actual test user IDs
-- Get these from: Authentication → Users in Supabase Dashboard
-- =============================================
\set clinic1_user_id 'REPLACE-WITH-CLINIC1-USER-UUID'
\set clinic2_user_id 'REPLACE-WITH-CLINIC2-USER-UUID'
\set admin_user_id 'REPLACE-WITH-ADMIN-USER-UUID'

-- =============================================
-- IMPORTANT: Before running this file
-- =============================================
-- 1. Create 3 test users in Dashboard:
--    - clinic1@test.com (password: Test123!)
--    - clinic2@test.com (password: Test123!)
--    - admin@test.com (password: Admin123!)
-- 2. Copy their UUIDs and replace the variables above
-- 3. Then execute this entire file
-- =============================================

-- =============================================
-- Create Super Admin
-- =============================================
INSERT INTO super_admins (user_id, role)
VALUES (:'admin_user_id', 'superadmin');

-- =============================================
-- Create Clinics
-- =============================================
INSERT INTO clinics (user_id, name, phone, address, token_daily_limit, whatsapp_confirmation, whatsapp_queue_alert, whatsapp_review)
VALUES
  (:'clinic1_user_id', 'City Hospital', '9876543210', '123 Main Street, Mumbai', 100, true, true, true),
  (:'clinic2_user_id', 'Care Medical Center', '9876543211', '456 Park Avenue, Delhi', 150, true, false, true);

-- =============================================
-- Create Doctors
-- =============================================
INSERT INTO doctors (clinic_id, name, specialization, token_initial, is_available)
SELECT c.id, 'Dr. Rajesh Kumar', 'Cardiology', 'A', true
FROM clinics c WHERE c.user_id = :'clinic1_user_id';

INSERT INTO doctors (clinic_id, name, specialization, token_initial, is_available)
SELECT c.id, 'Dr. Priya Sharma', 'Pediatrics', 'B', true
FROM clinics c WHERE c.user_id = :'clinic1_user_id';

INSERT INTO doctors (clinic_id, name, specialization, token_initial, is_available)
SELECT c.id, 'Dr. Amit Patel', 'General Medicine', 'C', true
FROM clinics c WHERE c.user_id = :'clinic2_user_id';

INSERT INTO doctors (clinic_id, name, specialization, token_initial, is_available)
SELECT c.id, 'Dr. Sneha Reddy', 'Dermatology', 'D', true
FROM clinics c WHERE c.user_id = :'clinic2_user_id';

-- =============================================
-- Create Patients
-- =============================================
INSERT INTO patients (clinic_id, phone_number)
SELECT c.id, '9123456780' FROM clinics c WHERE c.user_id = :'clinic1_user_id';

INSERT INTO patients (clinic_id, phone_number)
SELECT c.id, '9123456781' FROM clinics c WHERE c.user_id = :'clinic1_user_id';

INSERT INTO patients (clinic_id, phone_number)
SELECT c.id, '9123456782' FROM clinics c WHERE c.user_id = :'clinic1_user_id';

INSERT INTO patients (clinic_id, phone_number)
SELECT c.id, '9234567890' FROM clinics c WHERE c.user_id = :'clinic2_user_id';

INSERT INTO patients (clinic_id, phone_number)
SELECT c.id, '9234567891' FROM clinics c WHERE c.user_id = :'clinic2_user_id';

-- =============================================
-- Create Family Members
-- =============================================
-- For Clinic 1
INSERT INTO patient_family_members (patient_id, name, age, gender)
SELECT p.id, 'Rahul Kumar', 35, 'Male'
FROM patients p
JOIN clinics c ON p.clinic_id = c.id
WHERE c.user_id = :'clinic1_user_id' AND p.phone_number = '9123456780';

INSERT INTO patient_family_members (patient_id, name, age, gender)
SELECT p.id, 'Priya Kumar', 32, 'Female'
FROM patients p
JOIN clinics c ON p.clinic_id = c.id
WHERE c.user_id = :'clinic1_user_id' AND p.phone_number = '9123456780';

INSERT INTO patient_family_members (patient_id, name, age, gender)
SELECT p.id, 'Amit Shah', 45, 'Male'
FROM patients p
JOIN clinics c ON p.clinic_id = c.id
WHERE c.user_id = :'clinic1_user_id' AND p.phone_number = '9123456781';

INSERT INTO patient_family_members (patient_id, name, age, gender)
SELECT p.id, 'Sonia Shah', 42, 'Female'
FROM patients p
JOIN clinics c ON p.clinic_id = c.id
WHERE c.user_id = :'clinic1_user_id' AND p.phone_number = '9123456781';

INSERT INTO patient_family_members (patient_id, name, age, gender)
SELECT p.id, 'Vijay Desai', 28, 'Male'
FROM patients p
JOIN clinics c ON p.clinic_id = c.id
WHERE c.user_id = :'clinic1_user_id' AND p.phone_number = '9123456782';

-- For Clinic 2
INSERT INTO patient_family_members (patient_id, name, age, gender)
SELECT p.id, 'Ravi Verma', 50, 'Male'
FROM patients p
JOIN clinics c ON p.clinic_id = c.id
WHERE c.user_id = :'clinic2_user_id' AND p.phone_number = '9234567890';

INSERT INTO patient_family_members (patient_id, name, age, gender)
SELECT p.id, 'Neha Verma', 25, 'Female'
FROM patients p
JOIN clinics c ON p.clinic_id = c.id
WHERE c.user_id = :'clinic2_user_id' AND p.phone_number = '9234567891';

-- =============================================
-- Create Tokens for Today
-- =============================================
-- Clinic 1, Dr. Rajesh Kumar (Cardiology)
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date, status)
SELECT
  c.id,
  d.id,
  pfm.id,
  'A1',
  CURRENT_DATE,
  'completed'
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
WHERE c.user_id = :'clinic1_user_id'
  AND d.token_initial = 'A'
  AND pfm.name = 'Rahul Kumar';

INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date, status)
SELECT
  c.id,
  d.id,
  pfm.id,
  'A2',
  CURRENT_DATE,
  'in consultation'
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
WHERE c.user_id = :'clinic1_user_id'
  AND d.token_initial = 'A'
  AND pfm.name = 'Amit Shah';

INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date, status)
SELECT
  c.id,
  d.id,
  pfm.id,
  'A3',
  CURRENT_DATE,
  'waiting'
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
WHERE c.user_id = :'clinic1_user_id'
  AND d.token_initial = 'A'
  AND pfm.name = 'Vijay Desai';

-- Clinic 1, Dr. Priya Sharma (Pediatrics)
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date, status)
SELECT
  c.id,
  d.id,
  pfm.id,
  'B1',
  CURRENT_DATE,
  'completed'
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
WHERE c.user_id = :'clinic1_user_id'
  AND d.token_initial = 'B'
  AND pfm.name = 'Priya Kumar';

INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date, status)
SELECT
  c.id,
  d.id,
  pfm.id,
  'B2',
  CURRENT_DATE,
  'waiting'
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
WHERE c.user_id = :'clinic1_user_id'
  AND d.token_initial = 'B'
  AND pfm.name = 'Sonia Shah';

-- Clinic 2, Dr. Amit Patel (General Medicine)
INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date, status)
SELECT
  c.id,
  d.id,
  pfm.id,
  'C1',
  CURRENT_DATE,
  'completed'
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
WHERE c.user_id = :'clinic2_user_id'
  AND d.token_initial = 'C'
  AND pfm.name = 'Ravi Verma';

INSERT INTO tokens (clinic_id, doctor_id, patient_family_member_id, token_number, date, status)
SELECT
  c.id,
  d.id,
  pfm.id,
  'C2',
  CURRENT_DATE,
  'in consultation'
FROM clinics c
JOIN doctors d ON c.id = d.clinic_id
JOIN patients p ON c.id = p.clinic_id
JOIN patient_family_members pfm ON p.id = pfm.patient_id
WHERE c.user_id = :'clinic2_user_id'
  AND d.token_initial = 'C'
  AND pfm.name = 'Neha Verma';

-- =============================================
-- Create Sample Ads
-- =============================================
-- Note: You'll need to upload actual images to storage first
-- These are placeholder URLs
INSERT INTO ads (clinic_id, title, image_url, duration, is_active)
SELECT c.id, 'Health Checkup Special', 'https://placeholder.com/ad1.jpg', 10, true
FROM clinics c WHERE c.user_id = :'clinic1_user_id';

INSERT INTO ads (clinic_id, title, image_url, duration, is_active)
SELECT c.id, 'Vaccination Drive', 'https://placeholder.com/ad2.jpg', 15, true
FROM clinics c WHERE c.user_id = :'clinic2_user_id';

-- =============================================
-- Verification Queries
-- =============================================

-- Check created data
SELECT 'Clinics Created' as entity, COUNT(*) as count FROM clinics
UNION ALL
SELECT 'Doctors Created', COUNT(*) FROM doctors
UNION ALL
SELECT 'Patients Created', COUNT(*) FROM patients
UNION ALL
SELECT 'Family Members Created', COUNT(*) FROM patient_family_members
UNION ALL
SELECT 'Tokens Created', COUNT(*) FROM tokens
UNION ALL
SELECT 'Ads Created', COUNT(*) FROM ads
UNION ALL
SELECT 'Super Admins Created', COUNT(*) FROM super_admins;

-- Show today's tokens by clinic
SELECT
  c.name as clinic,
  d.name as doctor,
  t.token_number,
  pfm.name as patient,
  t.status,
  t.created_at
FROM tokens t
JOIN clinics c ON t.clinic_id = c.id
JOIN doctors d ON t.doctor_id = d.id
JOIN patient_family_members pfm ON t.patient_family_member_id = pfm.id
WHERE t.date = CURRENT_DATE
ORDER BY c.name, d.name, t.token_number;

-- =============================================
-- Success Message
-- =============================================
SELECT '✅ Test data created successfully!' as message;
SELECT 'Use TESTING_GUIDE.md to test all functionality' as next_step;
