-- =============================================
-- Hospital Token & Queue Management System
-- Database Triggers and Functions
-- =============================================

-- IMPORTANT: Execute schema.sql BEFORE running this file
-- This file depends on tables created in schema.sql

-- =============================================
-- TRIGGER FUNCTION: check_token_limit
-- Validates token limit before insert
-- =============================================

CREATE OR REPLACE FUNCTION check_token_limit()
RETURNS TRIGGER AS $$
DECLARE
    clinic_active BOOLEAN;
    daily_limit INTEGER;
    today_count INTEGER;
BEGIN
    -- Check if clinic is active
    SELECT is_active, token_daily_limit
    INTO clinic_active, daily_limit
    FROM clinics
    WHERE id = NEW.clinic_id;

    IF NOT clinic_active THEN
        RAISE EXCEPTION 'Clinic is not active';
    END IF;

    -- Count today's tokens for this clinic
    SELECT COUNT(*)
    INTO today_count
    FROM tokens
    WHERE clinic_id = NEW.clinic_id
    AND date = NEW.date;

    -- Check if limit is reached
    IF today_count >= daily_limit THEN
        RAISE EXCEPTION 'Daily token limit reached for this clinic';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trg_check_token_limit ON tokens;
CREATE TRIGGER trg_check_token_limit
    BEFORE INSERT ON tokens
    FOR EACH ROW
    EXECUTE FUNCTION check_token_limit();

-- =============================================
-- TRIGGER FUNCTION: update_token_updated_at
-- Automatically update completed_at when status changes to completed
-- =============================================

CREATE OR REPLACE FUNCTION update_token_completed_at()
RETURNS TRIGGER AS $$
BEGIN
    -- If status changes to 'completed' and completed_at is null, set it
    IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.completed_at IS NULL THEN
        NEW.completed_at = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_update_token_completed_at ON tokens;
CREATE TRIGGER trg_update_token_completed_at
    BEFORE UPDATE ON tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_token_completed_at();

-- =============================================
-- FUNCTION: get_next_token_number
-- Generates the next token number for a doctor on a specific date
-- =============================================

CREATE OR REPLACE FUNCTION get_next_token_number(
    p_clinic_id UUID,
    p_doctor_id UUID,
    p_date DATE
)
RETURNS TEXT AS $$
DECLARE
    doctor_initial TEXT;
    last_number INTEGER;
    next_number INTEGER;
BEGIN
    -- Get doctor's token initial
    SELECT token_initial INTO doctor_initial
    FROM doctors
    WHERE id = p_doctor_id;

    IF doctor_initial IS NULL THEN
        RAISE EXCEPTION 'Doctor not found';
    END IF;

    -- Get the last token number for this doctor on this date
    SELECT COALESCE(
        MAX(CAST(REGEXP_REPLACE(token_number, '[^0-9]', '', 'g') AS INTEGER)),
        0
    ) INTO last_number
    FROM tokens
    WHERE clinic_id = p_clinic_id
    AND doctor_id = p_doctor_id
    AND date = p_date
    AND token_number ~ '^[A-Z]+[0-9]+$';

    -- Calculate next number
    next_number := last_number + 1;

    -- Return formatted token number
    RETURN doctor_initial || next_number::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FUNCTION: get_queue_position
-- Gets the position of a token in the waiting queue
-- =============================================

CREATE OR REPLACE FUNCTION get_queue_position(p_token_id UUID)
RETURNS INTEGER AS $$
DECLARE
    token_clinic UUID;
    token_doctor UUID;
    token_date DATE;
    token_created TIMESTAMP;
    position INTEGER;
BEGIN
    -- Get token details
    SELECT clinic_id, doctor_id, date, created_at
    INTO token_clinic, token_doctor, token_date, token_created
    FROM tokens
    WHERE id = p_token_id;

    IF token_clinic IS NULL THEN
        RAISE EXCEPTION 'Token not found';
    END IF;

    -- Calculate position in queue
    SELECT COUNT(*) + 1
    INTO position
    FROM tokens
    WHERE clinic_id = token_clinic
    AND doctor_id = token_doctor
    AND date = token_date
    AND status = 'waiting'
    AND created_at < token_created;

    RETURN position;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FUNCTION: get_waiting_tokens_count
-- Gets the count of waiting tokens for a doctor on a specific date
-- =============================================

CREATE OR REPLACE FUNCTION get_waiting_tokens_count(
    p_clinic_id UUID,
    p_doctor_id UUID,
    p_date DATE
)
RETURNS INTEGER AS $$
DECLARE
    waiting_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO waiting_count
    FROM tokens
    WHERE clinic_id = p_clinic_id
    AND doctor_id = p_doctor_id
    AND date = p_date
    AND status = 'waiting';

    RETURN COALESCE(waiting_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FUNCTION: get_current_token
-- Gets the current token (in consultation) for a doctor
-- =============================================

CREATE OR REPLACE FUNCTION get_current_token(
    p_clinic_id UUID,
    p_doctor_id UUID,
    p_date DATE
)
RETURNS TABLE (
    token_id UUID,
    token_number TEXT,
    patient_name TEXT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id,
        t.token_number,
        pfm.name,
        t.created_at
    FROM tokens t
    LEFT JOIN patient_family_members pfm ON t.patient_family_member_id = pfm.id
    WHERE t.clinic_id = p_clinic_id
    AND t.doctor_id = p_doctor_id
    AND t.date = p_date
    AND t.status = 'in consultation'
    ORDER BY t.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FUNCTION: get_clinic_statistics
-- Gets statistics for a clinic for a date range
-- =============================================

CREATE OR REPLACE FUNCTION get_clinic_statistics(
    p_clinic_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    total_tokens BIGINT,
    completed_tokens BIGINT,
    skipped_tokens BIGINT,
    waiting_tokens BIGINT,
    completion_rate NUMERIC,
    skip_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) AS total_tokens,
        COUNT(*) FILTER (WHERE status = 'completed') AS completed_tokens,
        COUNT(*) FILTER (WHERE status = 'skipped') AS skipped_tokens,
        COUNT(*) FILTER (WHERE status = 'waiting') AS waiting_tokens,
        ROUND(
            (COUNT(*) FILTER (WHERE status = 'completed')::NUMERIC /
            NULLIF(COUNT(*), 0)) * 100,
            2
        ) AS completion_rate,
        ROUND(
            (COUNT(*) FILTER (WHERE status = 'skipped')::NUMERIC /
            NULLIF(COUNT(*), 0)) * 100,
            2
        ) AS skip_rate
    FROM tokens
    WHERE clinic_id = p_clinic_id
    AND date BETWEEN p_start_date AND p_end_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FUNCTION: get_doctor_statistics
-- Gets statistics for a specific doctor for a date range
-- =============================================

CREATE OR REPLACE FUNCTION get_doctor_statistics(
    p_doctor_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    total_tokens BIGINT,
    completed_tokens BIGINT,
    skipped_tokens BIGINT,
    avg_consultation_time INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) AS total_tokens,
        COUNT(*) FILTER (WHERE status = 'completed') AS completed_tokens,
        COUNT(*) FILTER (WHERE status = 'skipped') AS skipped_tokens,
        AVG(completed_at - created_at) FILTER (WHERE status = 'completed') AS avg_consultation_time
    FROM tokens
    WHERE doctor_id = p_doctor_id
    AND date BETWEEN p_start_date AND p_end_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FUNCTION: get_busiest_hours
-- Gets the busiest hours for a clinic in a date range
-- =============================================

CREATE OR REPLACE FUNCTION get_busiest_hours(
    p_clinic_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    hour INTEGER,
    token_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(HOUR FROM created_at)::INTEGER AS hour,
        COUNT(*) AS token_count
    FROM tokens
    WHERE clinic_id = p_clinic_id
    AND date BETWEEN p_start_date AND p_end_date
    GROUP BY EXTRACT(HOUR FROM created_at)
    ORDER BY token_count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- COMMENTS
-- =============================================

COMMENT ON FUNCTION check_token_limit() IS 'Validates token limit before insert (trigger function)';
COMMENT ON FUNCTION update_token_completed_at() IS 'Automatically sets completed_at when status changes to completed';
COMMENT ON FUNCTION get_next_token_number(UUID, UUID, DATE) IS 'Generates the next token number for a doctor on a specific date';
COMMENT ON FUNCTION get_queue_position(UUID) IS 'Gets the position of a token in the waiting queue';
COMMENT ON FUNCTION get_waiting_tokens_count(UUID, UUID, DATE) IS 'Gets the count of waiting tokens for a doctor';
COMMENT ON FUNCTION get_current_token(UUID, UUID, DATE) IS 'Gets the current token (in consultation) for a doctor';
COMMENT ON FUNCTION get_clinic_statistics(UUID, DATE, DATE) IS 'Gets statistics for a clinic for a date range';
COMMENT ON FUNCTION get_doctor_statistics(UUID, DATE, DATE) IS 'Gets statistics for a doctor for a date range';
COMMENT ON FUNCTION get_busiest_hours(UUID, DATE, DATE) IS 'Gets the busiest hours for a clinic in a date range';
