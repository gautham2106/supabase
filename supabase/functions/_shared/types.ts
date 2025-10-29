// =============================================
// Shared TypeScript Types
// =============================================

export interface Clinic {
  id: string;
  name: string;
  phone: string;
  address?: string;
  review_link?: string;
  whatsapp_confirmation: boolean;
  whatsapp_queue_alert: boolean;
  whatsapp_review: boolean;
  is_active: boolean;
}

export interface Doctor {
  id: string;
  clinic_id: string;
  name: string;
  specialization?: string;
  token_initial: string;
  is_available: boolean;
}

export interface Patient {
  id: string;
  clinic_id: string;
  phone_number: string;
}

export interface PatientFamilyMember {
  id: string;
  patient_id: string;
  name: string;
  age: number;
  gender: string;
}

export interface Token {
  id: string;
  clinic_id: string;
  doctor_id: string;
  patient_family_member_id: string;
  token_number: string;
  date: string;
  status: 'waiting' | 'in consultation' | 'skipped' | 'completed';
  reminder_sent: boolean;
  created_at: string;
  completed_at?: string;
}

export interface WhatsAppMessage {
  to: string;
  message: string;
}

export interface TokenDetails {
  token: Token;
  clinic: Clinic;
  doctor: Doctor;
  patient: Patient;
  patientFamilyMember: PatientFamilyMember;
}

export interface QueueAlert {
  tokenId: string;
  clinicName: string;
  patientName: string;
  tokenNumber: string;
  doctorName: string;
  currentToken: string;
  patientPhone: string;
}
