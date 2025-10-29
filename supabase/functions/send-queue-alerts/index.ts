// =============================================
// Edge Function: send-queue-alerts
// =============================================
// Triggered: AFTER UPDATE on tokens table
// Condition: When status changes TO 'in consultation'
// Purpose: Alert the 5th waiting patient (4th in queue)
// =============================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient } from '../_shared/supabase.ts';
import {
  sendWhatsAppMessage,
  formatMessage,
  MESSAGE_TEMPLATES,
  isValidIndianPhone,
} from '../_shared/whatsapp.ts';

const APP_URL = Deno.env.get('APP_URL') || 'https://your-app.com';

serve(async (req) => {
  try {
    // Parse request body
    const { record, old_record } = await req.json();

    if (!record || !old_record) {
      return new Response(
        JSON.stringify({ error: 'Invalid request: missing records' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if status changed TO 'in consultation'
    if (old_record.status === 'in consultation' || record.status !== 'in consultation') {
      console.log('Status did not change to in consultation, skipping');
      return new Response(
        JSON.stringify({ message: 'Not a status change to in consultation' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('Token status changed to in consultation:', record.id);

    const supabase = createSupabaseClient();

    // Fetch clinic details
    const { data: clinic, error: clinicError } = await supabase
      .from('clinics')
      .select('*')
      .eq('id', record.clinic_id)
      .single();

    if (clinicError || !clinic) {
      console.error('Error fetching clinic:', clinicError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch clinic' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Check if queue alerts are enabled
    if (!clinic.whatsapp_queue_alert) {
      console.log('Queue alerts disabled for clinic:', clinic.id);
      return new Response(
        JSON.stringify({ message: 'Queue alerts disabled' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Find the 4th waiting token (will be 5th in line)
    const { data: fourthToken, error: tokenError } = await supabase
      .from('tokens')
      .select(`
        *,
        doctor:doctors!inner(*),
        patient_family_member:patient_family_members!inner(
          *,
          patient:patients!inner(*)
        )
      `)
      .eq('clinic_id', record.clinic_id)
      .eq('doctor_id', record.doctor_id)
      .eq('date', record.date)
      .eq('status', 'waiting')
      .eq('reminder_sent', false)
      .order('created_at', { ascending: true })
      .limit(1)
      .range(3, 3); // Get the 4th record (0-indexed)

    if (tokenError) {
      console.error('Error fetching 4th token:', tokenError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch 4th token' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // If no 4th token, exit (less than 5 people waiting)
    if (!fourthToken || fourthToken.length === 0) {
      console.log('No 4th waiting token found, queue too short');
      return new Response(
        JSON.stringify({ message: 'Queue too short for alerts' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const tokenToAlert = fourthToken[0];

    // Get patient phone
    const patientPhone = tokenToAlert.patient_family_member.patient.phone_number;

    // Validate phone number
    if (!isValidIndianPhone(patientPhone)) {
      console.error('Invalid phone number:', patientPhone);
      return new Response(
        JSON.stringify({ error: 'Invalid phone number' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Format tracking URL
    const trackingUrl = `${APP_URL}/track/${tokenToAlert.id}`;

    // Prepare message variables
    const variables = {
      clinic_name: clinic.name,
      patient_name: tokenToAlert.patient_family_member.name,
      token_number: tokenToAlert.token_number,
      doctor_name: tokenToAlert.doctor.name,
      current_token: record.token_number,
      tracking_url: trackingUrl,
    };

    // Format message
    const message = formatMessage(MESSAGE_TEMPLATES.QUEUE_ALERT, variables);

    // Send WhatsApp message
    const result = await sendWhatsAppMessage({
      to: patientPhone,
      message: message,
    });

    if (result.success) {
      // Mark reminder as sent
      await supabase
        .from('tokens')
        .update({ reminder_sent: true })
        .eq('id', tokenToAlert.id);

      console.log('Queue alert sent successfully:', {
        tokenId: tokenToAlert.id,
        messageId: result.messageId,
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Queue alert sent',
          messageId: result.messageId,
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    } else {
      console.error('Failed to send queue alert:', result.error);
      return new Response(
        JSON.stringify({
          success: false,
          error: result.error,
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  } catch (error) {
    console.error('Error in send-queue-alerts:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
