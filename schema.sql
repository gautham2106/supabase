-- =============================================
-- Hospital Token & Queue Management System
-- Supabase SQL Schema
-- =============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Function to check if current user is a super admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM super_admins WHERE user_id = auth.uid()
  )
$$ LANGUAGE SQL SECURITY DEFINER;

-- =============================================
-- TABLES
-- =============================================

-- Table: clinics
-- Stores clinic information and settings
CREATE TABLE clinics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT NOT NULL,
    review_link TEXT,
    token_daily_limit INTEGER NOT NULL DEFAULT 100,
    whatsapp_confirmation BOOLEAN NOT NULL DEFAULT TRUE,
    whatsapp_queue_alert BOOLEAN NOT NULL DEFAULT FALSE,
    whatsapp_review BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_token_daily_limit CHECK (token_daily_limit > 0 AND token_daily_limit <= 10000)
);

-- Table: doctors
-- Stores doctor information per clinic
CREATE TABLE doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    specialization TEXT,
    token_initial TEXT NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,

    -- Constraints
    CONSTRAINT uq_doctors_clinic_token UNIQUE (clinic_id, token_initial),
    CONSTRAINT chk_token_initial_length CHECK (LENGTH(token_initial) BETWEEN 1 AND 5),
    CONSTRAINT chk_token_initial_upper CHECK (token_initial = UPPER(token_initial))
);

-- Table: patients
-- Stores patient information per clinic
CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    phone_number TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uq_patients_clinic_phone UNIQUE (clinic_id, phone_number),
    CONSTRAINT chk_phone_number_length CHECK (LENGTH(phone_number) = 10),
    CONSTRAINT chk_phone_number_format CHECK (phone_number ~ '^[6-9][0-9]{9}$')
);

-- Table: patient_family_members
-- Stores family members for each patient
CREATE TABLE patient_family_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    age INTEGER NOT NULL,
    gender TEXT NOT NULL,

    -- Constraints
    CONSTRAINT chk_age CHECK (age > 0 AND age <= 150),
    CONSTRAINT chk_gender CHECK (gender IN ('Male', 'Female', 'Other'))
);

-- Table: tokens
-- Stores token/queue information
CREATE TABLE tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES doctors(id) ON DELETE SET NULL,
    patient_family_member_id UUID REFERENCES patient_family_members(id) ON DELETE SET NULL,
    token_number TEXT NOT NULL,
    date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting',
    reminder_sent BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,

    -- Constraints
    CONSTRAINT uq_tokens_clinic_doctor_number_date UNIQUE (clinic_id, doctor_id, token_number, date),
    CONSTRAINT chk_status CHECK (status IN ('waiting', 'in consultation', 'skipped', 'completed')),
    CONSTRAINT chk_completed_at CHECK (completed_at IS NULL OR completed_at >= created_at),
    CONSTRAINT chk_date CHECK (date >= '2024-01-01')
);

-- Table: ads
-- Stores advertisement information for TV display
CREATE TABLE ads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    image_url TEXT NOT NULL,
    duration INTEGER NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Constraints
    CONSTRAINT chk_duration CHECK (duration > 0 AND duration <= 60)
);

-- Table: super_admins
-- Stores super admin users
CREATE TABLE super_admins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'admin',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_role CHECK (role IN ('admin', 'superadmin', 'support'))
);

-- Table: usage_logs
-- Stores daily usage statistics for billing
CREATE TABLE usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    tokens_generated INTEGER NOT NULL DEFAULT 0,
    whatsapp_sent INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uq_usage_clinic_date UNIQUE (clinic_id, date),
    CONSTRAINT chk_tokens_generated CHECK (tokens_generated >= 0),
    CONSTRAINT chk_whatsapp_sent CHECK (whatsapp_sent >= 0)
);

-- =============================================
-- INDEXES
-- =============================================

-- Indexes for clinics table
CREATE INDEX idx_clinics_user_id ON clinics(user_id);
CREATE INDEX idx_clinics_is_active ON clinics(is_active);

-- Indexes for doctors table
CREATE INDEX idx_doctors_clinic_id ON doctors(clinic_id);
CREATE INDEX idx_doctors_clinic_available ON doctors(clinic_id, is_available);

-- Indexes for patients table
CREATE INDEX idx_patients_clinic_id ON patients(clinic_id);

-- Indexes for patient_family_members table
CREATE INDEX idx_family_patient_id ON patient_family_members(patient_id);

-- Indexes for tokens table
CREATE INDEX idx_tokens_clinic_date_doctor ON tokens(clinic_id, date, doctor_id);
CREATE INDEX idx_tokens_clinic_date_status ON tokens(clinic_id, date, status);
CREATE INDEX idx_tokens_date_status ON tokens(date, status);
CREATE INDEX idx_tokens_family_member ON tokens(patient_family_member_id);
CREATE INDEX idx_tokens_created_at ON tokens(created_at);

-- Indexes for ads table
CREATE INDEX idx_ads_clinic_active ON ads(clinic_id, is_active);

-- Indexes for usage_logs table
CREATE INDEX idx_usage_date ON usage_logs(date);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Enable RLS on all tables
ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads ENABLE ROW LEVEL SECURITY;
ALTER TABLE super_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_logs ENABLE ROW LEVEL SECURITY;

-- =============================================
-- RLS POLICIES: clinics
-- =============================================

CREATE POLICY "Clinics: Select own or as super admin"
    ON clinics FOR SELECT
    USING (user_id = auth.uid() OR is_super_admin());

CREATE POLICY "Clinics: Insert own"
    ON clinics FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY "Clinics: Update own or as super admin"
    ON clinics FOR UPDATE
    USING (user_id = auth.uid() OR is_super_admin());

CREATE POLICY "Clinics: Delete as super admin only"
    ON clinics FOR DELETE
    USING (is_super_admin());

-- =============================================
-- RLS POLICIES: doctors
-- =============================================

CREATE POLICY "Doctors: Select own clinic or as super admin"
    ON doctors FOR SELECT
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Doctors: Insert own clinic or as super admin"
    ON doctors FOR INSERT
    WITH CHECK (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Doctors: Update own clinic or as super admin"
    ON doctors FOR UPDATE
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Doctors: Delete own clinic or as super admin"
    ON doctors FOR DELETE
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

-- =============================================
-- RLS POLICIES: patients
-- =============================================

CREATE POLICY "Patients: Select own clinic or as super admin"
    ON patients FOR SELECT
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Patients: Insert own clinic or as super admin"
    ON patients FOR INSERT
    WITH CHECK (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Patients: Update own clinic or as super admin"
    ON patients FOR UPDATE
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Patients: Delete own clinic or as super admin"
    ON patients FOR DELETE
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

-- =============================================
-- RLS POLICIES: patient_family_members
-- =============================================

CREATE POLICY "Family Members: Select own clinic or as super admin"
    ON patient_family_members FOR SELECT
    USING (
        patient_id IN (
            SELECT id FROM patients
            WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        )
        OR is_super_admin()
    );

CREATE POLICY "Family Members: Insert own clinic or as super admin"
    ON patient_family_members FOR INSERT
    WITH CHECK (
        patient_id IN (
            SELECT id FROM patients
            WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        )
        OR is_super_admin()
    );

CREATE POLICY "Family Members: Update own clinic or as super admin"
    ON patient_family_members FOR UPDATE
    USING (
        patient_id IN (
            SELECT id FROM patients
            WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        )
        OR is_super_admin()
    );

CREATE POLICY "Family Members: Delete own clinic or as super admin"
    ON patient_family_members FOR DELETE
    USING (
        patient_id IN (
            SELECT id FROM patients
            WHERE clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        )
        OR is_super_admin()
    );

-- =============================================
-- RLS POLICIES: tokens
-- =============================================

CREATE POLICY "Tokens: Select own clinic or as super admin"
    ON tokens FOR SELECT
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Tokens: Public select for tracking"
    ON tokens FOR SELECT
    USING (TRUE);

CREATE POLICY "Tokens: Insert active clinic only or as super admin"
    ON tokens FOR INSERT
    WITH CHECK (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid() AND is_active = true)
        OR is_super_admin()
    );

CREATE POLICY "Tokens: Update own clinic or as super admin"
    ON tokens FOR UPDATE
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Tokens: Delete as super admin only"
    ON tokens FOR DELETE
    USING (is_super_admin());

-- =============================================
-- RLS POLICIES: ads
-- =============================================

CREATE POLICY "Ads: Public select for TV display"
    ON ads FOR SELECT
    USING (TRUE);

CREATE POLICY "Ads: Insert own clinic or as super admin"
    ON ads FOR INSERT
    WITH CHECK (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Ads: Update own clinic or as super admin"
    ON ads FOR UPDATE
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Ads: Delete own clinic or as super admin"
    ON ads FOR DELETE
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

-- =============================================
-- RLS POLICIES: super_admins
-- =============================================

CREATE POLICY "Super Admins: Select own only"
    ON super_admins FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Super Admins: No insert via app"
    ON super_admins FOR INSERT
    WITH CHECK (FALSE);

CREATE POLICY "Super Admins: No update via app"
    ON super_admins FOR UPDATE
    USING (FALSE);

CREATE POLICY "Super Admins: No delete via app"
    ON super_admins FOR DELETE
    USING (FALSE);

-- =============================================
-- RLS POLICIES: usage_logs
-- =============================================

CREATE POLICY "Usage Logs: Select own clinic or as super admin"
    ON usage_logs FOR SELECT
    USING (
        clinic_id IN (SELECT id FROM clinics WHERE user_id = auth.uid())
        OR is_super_admin()
    );

CREATE POLICY "Usage Logs: No insert via app"
    ON usage_logs FOR INSERT
    WITH CHECK (FALSE);

CREATE POLICY "Usage Logs: No update via app"
    ON usage_logs FOR UPDATE
    USING (FALSE);

CREATE POLICY "Usage Logs: Delete as super admin only"
    ON usage_logs FOR DELETE
    USING (is_super_admin());

-- =============================================
-- COMMENTS
-- =============================================

COMMENT ON TABLE clinics IS 'Stores clinic information and settings';
COMMENT ON TABLE doctors IS 'Stores doctor information per clinic';
COMMENT ON TABLE patients IS 'Stores patient information per clinic';
COMMENT ON TABLE patient_family_members IS 'Stores family members for each patient';
COMMENT ON TABLE tokens IS 'Stores token/queue information';
COMMENT ON TABLE ads IS 'Stores advertisement information for TV display';
COMMENT ON TABLE super_admins IS 'Stores super admin users';
COMMENT ON TABLE usage_logs IS 'Stores daily usage statistics for billing';

COMMENT ON FUNCTION is_super_admin() IS 'Helper function to check if current user is a super admin';
