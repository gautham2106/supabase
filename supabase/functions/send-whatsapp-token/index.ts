// =============================================
// Edge Function: send-whatsapp-token
// =============================================
// Triggered: AFTER INSERT on tokens table
// Purpose: Send WhatsApp confirmation when token is created
// =============================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient } from '../_shared/supabase.ts';
import {
  sendWhatsAppMessage,
  formatMessage,
  MESSAGE_TEMPLATES,
  isValidIndianPhone,
} from '../_shared/whatsapp.ts';
import type { TokenDetails } from '../_shared/types.ts';

const APP_URL = Deno.env.get('APP_URL') || 'https://your-app.com';

serve(async (req) => {
  try {
    // Parse request body
    const { record } = await req.json();

    if (!record || !record.id) {
      return new Response(
        JSON.stringify({ error: 'Invalid request: missing token record' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('Processing token:', record.id);

    const supabase = createSupabaseClient();

    // Fetch complete token details with related data
    const { data: tokenData, error: fetchError } = await supabase
      .from('tokens')
      .select(`
        *,
        clinic:clinics!inner(*),
        doctor:doctors!inner(*),
        patient_family_member:patient_family_members!inner(
          *,
          patient:patients!inner(*)
        )
      `)
      .eq('id', record.id)
      .single();

    if (fetchError || !tokenData) {
      console.error('Error fetching token data:', fetchError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch token details' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if clinic has WhatsApp confirmation enabled
    if (!tokenData.clinic.whatsapp_confirmation) {
      console.log('WhatsApp confirmation disabled for clinic:', tokenData.clinic.id);
      return new Response(
        JSON.stringify({ message: 'WhatsApp confirmation disabled' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if clinic is active
    if (!tokenData.clinic.is_active) {
      console.log('Clinic is not active:', tokenData.clinic.id);
      return new Response(
        JSON.stringify({ message: 'Clinic is not active' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Get patient phone number
    const patientPhone = tokenData.patient_family_member.patient.phone_number;

    // Validate phone number
    if (!isValidIndianPhone(patientPhone)) {
      console.error('Invalid phone number:', patientPhone);
      return new Response(
        JSON.stringify({ error: 'Invalid phone number' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Calculate queue position
    const { count: queuePosition } = await supabase
      .from('tokens')
      .select('*', { count: 'exact', head: true })
      .eq('clinic_id', tokenData.clinic_id)
      .eq('doctor_id', tokenData.doctor_id)
      .eq('date', tokenData.date)
      .eq('status', 'waiting')
      .lt('created_at', tokenData.created_at);

    const position = (queuePosition || 0) + 1;

    // Format tracking URL
    const trackingUrl = `${APP_URL}/track/${tokenData.id}`;

    // Format date nicely
    const appointmentDate = new Date(tokenData.date).toLocaleDateString('en-IN', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });

    // Prepare message variables
    const variables = {
      clinic_name: tokenData.clinic.name,
      patient_name: tokenData.patient_family_member.name,
      token_number: tokenData.token_number,
      doctor_name: tokenData.doctor.name,
      specialization: tokenData.doctor.specialization || 'General Medicine',
      appointment_date: appointmentDate,
      queue_position: position.toString(),
      tracking_url: trackingUrl,
    };

    // Format message
    const message = formatMessage(MESSAGE_TEMPLATES.TOKEN_CONFIRMATION, variables);

    // Send WhatsApp message
    const result = await sendWhatsAppMessage({
      to: patientPhone,
      message: message,
    });

    if (result.success) {
      console.log('WhatsApp confirmation sent successfully:', {
        tokenId: tokenData.id,
        messageId: result.messageId,
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: 'WhatsApp confirmation sent',
          messageId: result.messageId,
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    } else {
      console.error('Failed to send WhatsApp message:', result.error);
      return new Response(
        JSON.stringify({
          success: false,
          error: result.error,
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  } catch (error) {
    console.error('Error in send-whatsapp-token:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
